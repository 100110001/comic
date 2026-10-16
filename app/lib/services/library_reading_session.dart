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
       _total = total;

  final ApiClient _client;
  final bool Function() _isCurrent;
  final List<Comic> _comics;
  final int pageSize;
  final int seed;
  final bool recent;
  int _consumed;
  int _total;

  bool get isCurrent => _isCurrent();

  bool canPrev(int id) =>
      isCurrent && _comics.indexWhere((c) => c.id == id) > 0;

  bool canNext(int id) {
    final index = _comics.indexWhere((c) => c.id == id);
    return isCurrent &&
        index >= 0 &&
        (index + 1 < _comics.length || _consumed < _total);
  }

  Future<Comic?> prev(int id) async {
    if (!canPrev(id)) return null;
    return _comics[_comics.indexWhere((c) => c.id == id) - 1];
  }

  Future<Comic?> next(int id) async {
    if (!canNext(id)) return null;
    final index = _comics.indexWhere((c) => c.id == id);
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
      final ids = _comics.map((c) => c.id).toSet();
      _comics.addAll(added.where((c) => ids.add(c.id)));
    }
    return index + 1 < _comics.length ? _comics[index + 1] : null;
  }
}
