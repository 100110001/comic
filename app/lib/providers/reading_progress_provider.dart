import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pending_reading_progress.dart';
import '../models/reading_progress_entry.dart';
import '../services/api_client.dart';
import '../services/progress_storage.dart';
import 'comics_providers.dart';
import 'server_provider.dart';

final progressStorageProvider = Provider<ProgressStorage>(
  (ref) => createProgressStorage(),
);

final readingProgressQueueProvider =
    AsyncNotifierProvider<ReadingProgressQueue, List<PendingReadingProgress>>(
      ReadingProgressQueue.new,
    );

/// 存活于应用会话中，异步任务不依赖阅读页面的 WidgetRef。
class ReadingProgressQueue extends AsyncNotifier<List<PendingReadingProgress>> {
  Future<void> _writes = Future.value();
  Future<void> _uploads = Future.value();
  final _inFlight = <(String, int), Future<void>>{};
  int _revision = 0;

  /// 活跃阅读器提供当前位置；原生关闭和应用后台事件先完成此写入。
  Future<void> Function()? checkpointActiveReader;

  @override
  Future<List<PendingReadingProgress>> build() async {
    final contents = await ref.read(progressStorageProvider).read();
    final entries = <String, PendingReadingProgress>{};
    if (contents != null) {
      try {
        final json = jsonDecode(contents) as Map<String, dynamic>;
        if (json['version'] != 1) throw const FormatException('未知断点格式');
        for (final value in json['entries'] as List) {
          try {
            final entry = PendingReadingProgress.fromJson(
              value as Map<String, dynamic>,
            );
            if (normalizeServerUrl(entry.serverUrl) != entry.serverUrl) {
              continue;
            }
            final previous = entries[entry.key];
            if (previous == null || entry.revision > previous.revision) {
              entries[entry.key] = entry;
            }
            _revision = max(_revision, entry.revision);
          } catch (_) {
            // 单条损坏不妨碍其他断点恢复。
          }
        }
      } catch (_) {
        // 格式损坏时仍允许阅读，下一次有效保存重建本机队列。
      }
    }
    return entries.values.toList();
  }

  Future<void> _write(List<PendingReadingProgress> entries) async {
    await ref
        .read(progressStorageProvider)
        .write(
          jsonEncode({
            'version': 1,
            'entries': entries.map((p) => p.toJson()).toList(),
          }),
        );
    if (ref.mounted) state = AsyncData(entries);
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final operation = _writes.then((_) => action());
    _writes = operation.catchError((_) {});
    return operation;
  }

  Future<void> record(ReadingProgressEntry entry) => _enqueue(() async {
    await future;
    if (!ref.mounted) return;
    final entries = state.requireValue;
    final key = '${entry.comic.serverUrl}\u0000${entry.comic.id}';
    for (final previous in entries) {
      if (previous.key == key &&
          previous.position ==
              (chapterId: entry.chapterId, pageNumber: entry.pageNumber)) {
        return;
      }
    }
    _revision = max(_revision + 1, DateTime.now().microsecondsSinceEpoch);
    final pending = PendingReadingProgress(entry: entry, revision: _revision);
    await _write([...entries.where((p) => p.key != key), pending]);
  });

  Future<void> checkpointAndFlush() async {
    await checkpointActiveReader?.call();
    await _writes;
  }

  bool _isCurrent(ApiClient client) =>
      ref.mounted &&
      ref.read(serverSessionProvider).generation == client.generation &&
      ref.read(serverSessionProvider).url == client.baseUrl;

  Future<void> sync(ApiClient client) {
    final key = (client.baseUrl, client.generation);
    final running = _inFlight[key];
    if (running != null) return running;
    final operation = _uploads.then((_) => _sync(client));
    _uploads = operation.catchError((_) {});
    _inFlight[key] = operation;
    // 用独立完成分支清理，不制造无人监听的异常 Future。
    operation.then(
      (_) => _inFlight.remove(key),
      onError: (Object error, StackTrace stack) {
        _inFlight.remove(key);
      },
    );
    return operation;
  }

  Future<void> _sync(ApiClient client) async {
    await future;
    await _writes;
    if (!_isCurrent(client)) return;
    final batch = state.requireValue
        .where((p) => p.serverUrl == client.baseUrl)
        .toList();
    for (final pending in batch) {
      if (!_isCurrent(client)) return;
      try {
        await client.updateProgress(
          comicId: pending.entry.comic.id,
          chapterId: pending.entry.chapterId,
          pageNumber: pending.entry.pageNumber,
        );
      } catch (_) {
        // 失败保留队列，下一次生命周期触发或手动重试再补传。
        return;
      }
      if (!_isCurrent(client)) return;
      await _enqueue(() async {
        if (!_isCurrent(client)) return;
        final entries = state.requireValue;
        final remaining = entries
            .where(
              (p) => p.key != pending.key || p.revision != pending.revision,
            )
            .toList();
        if (remaining.length != entries.length) await _write(remaining);
        if (!_isCurrent(client)) return;
        ref.invalidate(recentReadingProvider);
        ref.invalidate(comicDetailProvider(pending.entry.comic.id));
      });
    }
  }
}

final localReadingProgressProvider =
    Provider.family<PendingReadingProgress?, int>((ref, id) {
      final session = ref.watch(serverSessionProvider);
      final entries = ref.watch(readingProgressQueueProvider).value;
      for (final entry in entries ?? const <PendingReadingProgress>[]) {
        if (entry.serverUrl == session.url && entry.entry.comic.id == id) {
          return entry;
        }
      }
      return null;
    });

/// 远端查询仍独立缓存，本机位置变化只重新合并，不重新请求 API。
final recentReadingWithLocalProvider =
    FutureProvider<List<ReadingProgressEntry>>((ref) async {
      final url = ref.watch(serverSessionProvider).url;
      final local =
          (ref.watch(readingProgressQueueProvider).value ?? [])
              .where((p) => p.serverUrl == url)
              .toList()
            ..sort((a, b) => b.revision.compareTo(a.revision));
      final remote = ref.watch(recentReadingProvider.future);
      try {
        final entries = await remote;
        final ids = local.map((p) => p.entry.comic.id).toSet();
        return [
          ...local.map((p) => p.entry),
          ...entries.where((p) => !ids.contains(p.comic.id)),
        ];
      } catch (_) {
        if (local.isNotEmpty) return local.map((p) => p.entry).toList();
        rethrow;
      }
    });
