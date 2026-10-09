import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/image_item.dart';
import '../models/super_resolution_job.dart';
import '../services/api_client.dart';
import '../utils/user_error.dart';
import 'server_provider.dart';
import 'settings_provider.dart';

class SuperResolutionState {
  const SuperResolutionState({this.enabled = false, this.results = const {}});
  final bool enabled;
  // 完整原图 URL（服务器及 v）绑定增强结果。
  final Map<String, SuperResolutionJob> results;
}

final superResolutionProvider =
    NotifierProvider.autoDispose<
      SuperResolutionController,
      SuperResolutionState
    >(SuperResolutionController.new);

class SuperResolutionController extends Notifier<SuperResolutionState> {
  late ApiClient _client;
  Timer? _timer;
  var _generation = 0;
  var _disposed = false;
  var _signature = '';
  List<ImageItem> _window = [];

  @override
  SuperResolutionState build() {
    _client = ref.watch(apiClientProvider);
    _disposed = false;
    _signature = '';
    _window = [];
    ref.onDispose(() {
      _disposed = true;
      ++_generation;
      _timer?.cancel();
    });
    return SuperResolutionState(
      enabled: ref.read(superResolutionDefaultProvider),
    );
  }

  void setEnabled(bool enabled) {
    ++_generation;
    _timer?.cancel();
    _signature = '';
    state = SuperResolutionState(enabled: enabled, results: state.results);
  }

  void resetChapter() {
    ++_generation;
    _timer?.cancel();
    _signature = '';
    _window = [];
    state = SuperResolutionState(enabled: state.enabled);
  }

  void setWindow(List<ImageItem> images, {bool retry = false}) {
    final signature =
        '${state.enabled}:${images.map((image) => image.url).join('\n')}';
    if (!retry && signature == _signature) return;
    _signature = signature;
    _window = images;
    final generation = ++_generation;
    _timer?.cancel();
    if (!state.enabled) {
      unawaited(_submit(_client, images, generation, upscale: false));
      return;
    }
    final results = Map<String, SuperResolutionJob>.of(state.results);
    if (retry) {
      for (final image in images) {
        results.remove(image.url);
      }
    }
    // 会话内保留少量已读结果，避免无限累积；磁盘仍由后端管理。
    while (results.length > 32) {
      results.remove(results.keys.first);
    }
    state = SuperResolutionState(enabled: true, results: results);
    final pending = images
        .where(
          (image) => results[image.url] == null || results[image.url]!.pending,
        )
        .toList();
    if (pending.isEmpty) return;
    final client = _client;
    unawaited(_submit(client, pending, generation));
  }

  bool _current(int generation) =>
      !_disposed && generation == _generation && state.enabled;

  void _publish(List<ImageItem> images, List<SuperResolutionJob> jobs) {
    final results = Map<String, SuperResolutionJob>.of(state.results);
    for (final image in images) {
      final matches = jobs.where((job) => job.imageId == image.id);
      if (matches.isEmpty) throw const FormatException('超分响应缺少页面');
      results[image.url] = matches.single;
    }
    state = SuperResolutionState(enabled: true, results: results);
  }

  void _fail(List<ImageItem> images, Object error) {
    final results = Map<String, SuperResolutionJob>.of(state.results);
    for (final image in images) {
      results[image.url] = SuperResolutionJob(
        key: results[image.url]?.key ?? '',
        imageId: image.id,
        status: 'failed',
        error: userMessageFor(error, fallback: '超分失败，继续显示原图'),
      );
    }
    state = SuperResolutionState(enabled: true, results: results);
  }

  Future<void> _submit(
    ApiClient client,
    List<ImageItem> images,
    int generation, {
    bool upscale = true,
  }) async {
    try {
      if (images.any(
        (image) =>
            Uri.parse(image.url).origin != Uri.parse(client.baseUrl).origin,
      )) {
        throw const UserVisibleException(
          UserErrorKind.rejected,
          '漫画来源已切换，请重新打开章节',
        );
      }
      final resolved = await client.resolveImages(images, upscale: upscale);
      if (!upscale) return;
      final jobs = images.map((image) {
        final result = resolved.singleWhere((item) => item.imageId == image.id);
        if (result.originalUrl != image.url) {
          throw const FormatException('原图版本已变化，请重新打开章节');
        }
        return result.superResolution ??
            SuperResolutionJob(
              key: '',
              imageId: image.id,
              status: 'failed',
              error: result.error ?? '超分不可用，继续显示原图',
            );
      }).toList();
      if (!_current(generation)) return;
      _publish(images, jobs);
      _schedule(client, images, generation, DateTime.now());
    } catch (error) {
      if (_current(generation)) _fail(images, error);
    }
  }

  void _schedule(
    ApiClient client,
    List<ImageItem> images,
    int generation,
    DateTime start,
  ) {
    if (!_current(generation)) return;
    final pending = images
        .where((image) => state.results[image.url]?.pending == true)
        .toList();
    if (pending.isEmpty) return;
    _timer = Timer(const Duration(seconds: 1), () async {
      if (!_current(generation)) return;
      try {
        if (DateTime.now().difference(start) > const Duration(minutes: 2)) {
          throw const UserVisibleException(UserErrorKind.timeout, '超分等待超时，请重试');
        }
        final keys = pending
            .map((image) => state.results[image.url]!.key)
            .toList();
        final jobs = await client.getSuperResolutionJobs(keys);
        if (!_current(generation)) return;
        // 缓存清理/后端重启可能返回 imageId=0，以已绑定键恢复页面身份。
        final resolved = pending.map((image) {
          final key = state.results[image.url]!.key;
          final job = jobs.singleWhere((job) => job.key == key);
          return SuperResolutionJob(
            key: key,
            imageId: image.id,
            status: job.status,
            url: job.url,
            error: job.error,
          );
        }).toList();
        _publish(pending, resolved);
        _schedule(client, images, generation, start);
      } catch (error) {
        if (_current(generation)) _fail(pending, error);
      }
    });
  }

  int get generation => _generation;

  void imageFailed(
    String sourceUrl, {
    required int generation,
    required SuperResolutionJob? expected,
  }) {
    if (!_current(generation) ||
        !identical(state.results[sourceUrl], expected)) {
      return;
    }
    if (!state.enabled || state.results[sourceUrl]?.status != 'ready') return;
    final image = _window.where((image) => image.url == sourceUrl);
    if (image.isNotEmpty) {
      _fail(
        image.toList(),
        const UserVisibleException(UserErrorKind.connection, '超分图片加载失败，继续显示原图'),
      );
    }
  }

  Future<void> clearCache() async {
    final client = _client;
    final generation = ++_generation;
    _timer?.cancel();
    state = const SuperResolutionState();
    _signature = '';
    await client.clearSuperResolutionCache();
    if (_disposed || generation != _generation) return;
    state = const SuperResolutionState();
  }
}
