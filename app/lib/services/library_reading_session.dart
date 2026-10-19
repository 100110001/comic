import '../models/comic.dart';
import 'api_client.dart';

/// 首页开读时的列表快照；后续首页刷新与布局变化不改变阅读顺序。
class LibraryReadingSession {
  LibraryReadingSession({
    required ApiClient client,
    required bool Function() isCurrent,
    required List<Comic> comics,
    required int total,
    required this.pageSize,
    required this.seed,
    required this.recent,
  }) : _client = client,
       _isCurrent = isCurrent,
       _comics = List.of(comics),
       _consumed = comics.length,
       _total = total {
    for (var index = 0; index < _comics.length; index++) {
      _comicIndices.putIfAbsent(_comics[index].id, () => index);
    }
  }

  final ApiClient _client;
  final bool Function() _isCurrent;
  final List<Comic> _comics;
  final _comicIndices = <int, int>{};
  final int pageSize;
  final int seed;
  final bool recent;
  int _consumed;
  int _total;

  bool get isCurrent => _isCurrent();

  bool canPrev(int id) => isCurrent && (_comicIndices[id] ?? -1) > 0;

  bool canNext(int id) {
    final index = _comicIndices[id] ?? -1;
    return isCurrent &&
        index >= 0 &&
        (index + 1 < _comics.length || _consumed < _total);
  }

  Future<Comic?> prev(int id) async {
    if (!canPrev(id)) return null;
    return _comics[_comicIndices[id]! - 1];
  }

  Future<Comic?> next(int id) async {
    if (!canNext(id)) return null;
    final index = _comicIndices[id]!;
    while (index + 1 >= _comics.length && _consumed < _total) {
      final skip = _consumed % pageSize;
      final result = await _client.getComics(
        pageOffset: _consumed ~/ pageSize + 1,
        pageSize: pageSize,
        random: !recent,
        seed: recent ? null : seed,
        recent: recent,
      );
      if (!isCurrent) return null;
      final added = result.list.skip(skip).toList();
      _total = result.total;
      if (added.isEmpty) {
        _total = _consumed;
        break;
      }
      _consumed += added.length;
      for (final comic in added) {
        if (_comicIndices.containsKey(comic.id)) continue;
        _comicIndices[comic.id] = _comics.length;
        _comics.add(comic);
      }
    }
    return index + 1 < _comics.length ? _comics[index + 1] : null;
  }
}
