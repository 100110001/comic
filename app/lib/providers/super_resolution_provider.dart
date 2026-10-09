import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/image_item.dart';
import '../models/super_resolution_job.dart';
import '../services/api_client.dart';
import '../utils/user_error.dart';
import 'server_provider.dart';
import 'settings_provider.dart';

const superResolutionWindowSize = 11;

class SuperResolutionState {
  const SuperResolutionState({
    bool enabled = false,
    SuperResolutionMode? mode,
    this.results = const {},
    this.reasons = const {},
    this.lookahead = 4,
  }) : mode =
           mode ?? (enabled ? SuperResolutionMode.on : SuperResolutionMode.off);
  final SuperResolutionMode mode;
  bool get enabled => mode != SuperResolutionMode.off;
  final Map<String, SuperResolutionJob> results;
  final Map<String, String> reasons;
  final int lookahead;
  SuperResolutionState copyWith({
    SuperResolutionMode? mode,
    Map<String, SuperResolutionJob>? results,
    Map<String, String>? reasons,
    int? lookahead,
  }) => SuperResolutionState(
    mode: mode ?? this.mode,
    results: results ?? this.results,
    reasons: reasons ?? this.reasons,
    lookahead: lookahead ?? this.lookahead,
  );
}

final superResolutionProvider =
    NotifierProvider.autoDispose<
      SuperResolutionController,
      SuperResolutionState
    >(SuperResolutionController.new);

class SuperResolutionController extends Notifier<SuperResolutionState> {
  late ApiClient _client;
  Timer? _timer;
  Timer? _policyTimer;
  var _refreshingPolicy = false;
  var _lookahead = 4;
  var _preferredMode = SuperResolutionMode.on;
  List<ImageItem> _candidates = [];
  Map<String, int> _targetWidths = {};
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
    _candidates = [];
    _lookahead = 4;
    _policyTimer?.cancel();
    _policyTimer = null;
    final mode = ref.read(superResolutionDefaultProvider);
    _preferredMode = mode == SuperResolutionMode.off
        ? SuperResolutionMode.on
        : mode;
    ref.onDispose(() {
      _disposed = true;
      ++_generation;
      _timer?.cancel();
      _policyTimer?.cancel();
    });
    return SuperResolutionState(mode: mode);
  }

  void setEnabled(bool enabled) {
    ++_generation;
    _timer?.cancel();
    _signature = '';
    _policyTimer?.cancel();
    _policyTimer = null;
    state = state.copyWith(
      mode: enabled ? _preferredMode : SuperResolutionMode.off,
    );
  }

  void resetChapter() {
    ++_generation;
    _timer?.cancel();
    _signature = '';
    _window = [];
    _candidates = [];
    _policyTimer?.cancel();
    _policyTimer = null;
    state = SuperResolutionState(mode: state.mode, lookahead: _lookahead);
  }

  void setWindow(
    List<ImageItem> images, {
    bool retry = false,
    Map<String, int>? targetWidths,
  }) {
    if (targetWidths != null) _targetWidths = targetWidths;
    final signature =
        '${state.mode}:$_lookahead:${images.map((image) => '${image.url}:${_targetWidths[image.url]}').join('\n')}';
    if (!retry && signature == _signature) return;
    _signature = signature;
    _candidates = images.take(superResolutionWindowSize).toList();
    final generation = ++_generation;
    _timer?.cancel();
    if (!state.enabled) {
      _window = _candidates;
      unawaited(_submit(_client, _window, generation, upscale: false));
      return;
    }
    unawaited(_prepareWindow(_client, generation, retry));
  }

  Future<void> _prepareWindow(
    ApiClient client,
    int generation,
    bool retry,
  ) async {
    var lookahead = 4;
    try {
      lookahead = await client.getSuperResolutionLookahead().timeout(
        const Duration(seconds: 3),
      );
    } catch (_) {
      /* 旧后端或遥测不可用不阻断阅读。 */
    }
    if (!_current(generation)) return;
    _lookahead = lookahead;
    final images = _candidates.take(lookahead + 1).toList();
    _window = images;
    final results = Map<String, SuperResolutionJob>.of(state.results);
    if (retry) {
      for (final image in images) {
        results.remove(image.url);
      }
    }
    while (results.length > 32) {
      results.remove(results.keys.first);
    }
    final reasons = <String, String>{};
    final eligible = images.where((image) {
      if (state.mode != SuperResolutionMode.adaptive) return true;
      final width = image.width;
      final target = _targetWidths[image.url];
      if (width == null || width <= 0) {
        reasons[image.url] = '原图尺寸未知，保留原图';
        return false;
      }
      if (target == null || target <= 0) {
        reasons[image.url] = '等待显示尺寸，先看原图';
        return false;
      }
      if (target <= width * 1.15) {
        reasons[image.url] = '原图分辨率足够，已跳过';
        return false;
      }
      return true;
    }).toList();
    state = state.copyWith(
      results: results,
      reasons: reasons,
      lookahead: lookahead,
    );
    _policyTimer ??= Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_refreshPolicy());
    });
    if (eligible.isEmpty) {
      unawaited(_submit(client, images, generation, upscale: false));
      return;
    }
    if (eligible.every(
      (image) => results[image.url] != null && !results[image.url]!.pending,
    )) {
      return;
    }
    // 提交当前动态窗口中需要增强的页；后端去重及复用结果。
    unawaited(_submit(client, eligible, generation));
  }

  Future<void> _refreshPolicy() async {
    if (_refreshingPolicy || !state.enabled || _candidates.isEmpty) return;
    _refreshingPolicy = true;
    final generation = _generation;
    try {
      final lookahead = await _client.getSuperResolutionLookahead().timeout(
        const Duration(seconds: 3),
      );
      if (!_current(generation) || lookahead == _lookahead) return;
      _lookahead = lookahead;
      _signature = '';
      setWindow(_candidates);
    } catch (_) {
      if (_current(generation) && _lookahead != 4) {
        _lookahead = 4;
        _signature = '';
        setWindow(_candidates);
      }
    } finally {
      _refreshingPolicy = false;
    }
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
    state = state.copyWith(results: results);
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
    state = state.copyWith(results: results);
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
      final resolved = await client.resolveImages(
        images,
        upscale: upscale,
        priorities: {
          for (final image in images)
            image.id: _window.indexWhere((item) => item.url == image.url),
        },
      );
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
        if (DateTime.now().difference(start) > const Duration(minutes: 12)) {
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
    _policyTimer?.cancel();
    _policyTimer = null;
    state = const SuperResolutionState();
    _signature = '';
    await client.clearSuperResolutionCache();
    if (_disposed || generation != _generation) return;
    state = const SuperResolutionState();
  }
}
