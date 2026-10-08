import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/user_error.dart';
import 'server_provider.dart';

const searchHistoryKey = 'searchHistory.v1';
const searchHistoryLimit = 20;

final searchHistoryPreferencesProvider = Provider<Future<SharedPreferences>>(
  (ref) => SharedPreferences.getInstance(),
);
final searchHistoryStoreProvider =
    AsyncNotifierProvider<SearchHistoryStore, Map<String, List<String>>>(
      SearchHistoryStore.new,
    );

class SearchHistoryStore extends AsyncNotifier<Map<String, List<String>>> {
  Future<void> _writes = Future.value();

  @override
  Future<Map<String, List<String>>> build() async {
    final prefs = await ref.read(searchHistoryPreferencesProvider);
    final raw = prefs.getString(searchHistoryKey);
    final histories = <String, List<String>>{};
    if (raw == null) return histories;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['version'] != 1) return histories;
      final sources = data['sources'] as Map<String, dynamic>;
      for (final source in sources.entries) {
        try {
          if (normalizeServerUrl(source.key) != source.key) continue;
          final words = (source.value as List)
              .whereType<String>()
              .map((word) => word.trim())
              .where((word) => word.isNotEmpty)
              .toSet()
              .take(searchHistoryLimit)
              .toList();
          if (words.isNotEmpty) histories[source.key] = words;
        } catch (_) {
          // 单个来源损坏不影响其他服务器的历史。
        }
      }
    } catch (_) {
      // 旧格式或损坏数据由下次有效操作重新建立。
    }
    return histories;
  }

  Future<void> _change(
    String source,
    List<String> Function(List<String>) edit,
  ) {
    final operation = _writes.then((_) async {
      if (state.hasError) ref.invalidateSelf();
      await future;
      if (!ref.mounted) return;
      final url = normalizeServerUrl(source);
      final next = {...state.requireValue};
      final words = edit(next[url] ?? const []);
      if (words.isEmpty) {
        next.remove(url);
      } else {
        next[url] = words;
      }
      final prefs = await ref.read(searchHistoryPreferencesProvider);
      final saved = await prefs.setString(
        searchHistoryKey,
        jsonEncode({'version': 1, 'sources': next}),
      );
      if (!saved) {
        throw const UserVisibleException(
          UserErrorKind.persistence,
          '搜索历史保存失败，请重试',
        );
      }
      if (ref.mounted) state = AsyncData(next);
    });
    _writes = operation.catchError((_) {});
    return operation;
  }

  Future<void> remember(String source, String keyword) {
    final word = keyword.trim();
    if (word.isEmpty) return Future.value();
    return _change(
      source,
      (words) => [
        word,
        ...words.where((previous) => previous != word),
      ].take(searchHistoryLimit).toList(),
    );
  }

  Future<void> remove(String source, String keyword) => _change(
    source,
    (words) => words.where((word) => word != keyword).toList(),
  );

  Future<void> clear(String source) => _change(source, (_) => []);
}

final searchHistoryProvider = Provider<AsyncValue<List<String>>>((ref) {
  final source = ref.watch(serverSessionProvider).url;
  return ref
      .watch(searchHistoryStoreProvider)
      .whenData((histories) => histories[source] ?? const []);
});
