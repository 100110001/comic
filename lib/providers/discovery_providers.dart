import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comic.dart';
import '../services/api.dart';

/// 发现随机阅读的序列状态：一次全库洗牌，一批内不重复，
/// 向后翻过末尾自动重新洗牌接上，向前停在第一本。
class DiscoveryState {
  final int seed;
  final int pageOffset;
  final int total;
  final int pageSize;
  final List<Comic> comics;
  final int index;

  const DiscoveryState({
    required this.seed,
    required this.pageOffset,
    required this.total,
    required this.pageSize,
    required this.comics,
    required this.index,
  });

  Comic? get current => comics.isEmpty ? null : comics[index];
  Comic? get prev => index > 0 ? comics[index - 1] : null;
  Comic? get next =>
      index + 1 < comics.length ? comics[index + 1] : null;
  bool get canGoPrev => index > 0;

  DiscoveryState copyWith({
    int? pageOffset,
    int? total,
    int? pageSize,
    List<Comic>? comics,
    int? index,
  }) => DiscoveryState(
    seed: seed,
    pageOffset: pageOffset ?? this.pageOffset,
    total: total ?? this.total,
    pageSize: pageSize ?? this.pageSize,
    comics: comics ?? this.comics,
    index: index ?? this.index,
  );
}

class DiscoveryNotifier extends AsyncNotifier<DiscoveryState> {
  bool _busy = false;

  @override
  Future<DiscoveryState> build() async =>
      _fetch(seed: _newSeed(), pageOffset: 1, pageSize: 30);

  int _newSeed() => Random().nextInt(1 << 31);

  Future<DiscoveryState> _fetch({
    required int seed,
    required int pageOffset,
    required int pageSize,
  }) async {
    final r = await ApiService.getRandomPage(
      seed: seed,
      pageOffset: pageOffset,
      pageSize: pageSize,
    );
    return DiscoveryState(
      seed: seed,
      pageOffset: pageOffset,
      total: r.total,
      pageSize: pageSize,
      comics: r.list,
      index: 0,
    );
  }

  /// 上一本；已在第一本时返回 null。
  Future<Comic?> prev() async {
    if (_busy) return null;
    final s = state.value;
    if (s == null || !s.canGoPrev) return null;
    _busy = true;
    try {
      state = AsyncData(s.copyWith(index: s.index - 1));
      return state.value?.current;
    } finally {
      _busy = false;
    }
  }

  /// 下一本；已加载末尾先续页，序列末尾重新洗牌接上。
  Future<Comic?> next() async {
    if (_busy) return null;
    final s = state.value;
    if (s == null) return null;
    _busy = true;
    try {
      if (s.index + 1 < s.comics.length) {
        state = AsyncData(s.copyWith(index: s.index + 1));
        return state.value?.current;
      }
      if (s.comics.length < s.total) {
        final next = await _fetch(
          seed: s.seed,
          pageOffset: s.pageOffset + 1,
          pageSize: s.pageSize,
        );
        state = AsyncData(
          s.copyWith(
            pageOffset: next.pageOffset,
            total: next.total,
            comics: [...s.comics, ...next.comics],
            index: s.index + 1,
          ),
        );
        return state.value?.current;
      }
      final fresh = await _fetch(
        seed: _newSeed(),
        pageOffset: 1,
        pageSize: s.pageSize,
      );
      state = AsyncData(fresh);
      return state.value?.current;
    } finally {
      _busy = false;
    }
  }

  /// 「换一批」：换种子重新洗牌，重置到第一本。
  Future<void> refresh() async {
    if (_busy) return;
    final s = state.value;
    _busy = true;
    try {
      final fresh = await _fetch(
        seed: _newSeed(),
        pageOffset: 1,
        pageSize: s?.pageSize ?? 30,
      );
      state = AsyncData(fresh);
    } finally {
      _busy = false;
    }
  }
}

final discoveryProvider =
    AsyncNotifierProvider<DiscoveryNotifier, DiscoveryState>(
      DiscoveryNotifier.new,
    );
