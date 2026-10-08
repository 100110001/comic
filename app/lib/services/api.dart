import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/comic.dart';
import '../models/chapter.dart';
import '../models/favorite_author.dart';
import '../models/image_item.dart';
import '../models/reading_progress_entry.dart';

class ApiService {
  static Future<Map<String, dynamic>> _get(String path) async {
    final url = '$baseUrl$path';
    debugPrint('[API] GET $url');
    final res = await http.get(Uri.parse(url));
    return jsonDecode(res.body);
  }

  static Future<({List<Comic> list, int total})> getComics({
    int pageOffset = 1,
    int pageSize = 20,
    String keyword = '',
    bool random = false,
    int? seed,
  }) async {
    final q = keyword.isNotEmpty
        ? '&keyword=${Uri.encodeComponent(keyword)}'
        : '';
    final r = random ? '&random=1' : '';
    final sd = seed != null ? '&seed=$seed' : '';
    final data = await _get(
      '/api/comics?pageOffset=$pageOffset&pageSize=$pageSize$q$r$sd',
    );
    final list = (data['data'] as List).map((e) => Comic.fromJson(e)).toList();
    return (list: list, total: data['total'] as int);
  }

  /// 首页随机书库：一次取全库，随机顺序。
  static Future<List<Comic>> getRandomLibrary() async {
    final r = await getComics(random: true, pageSize: 500);
    return r.list;
  }

  /// 按随机种子取一页（种子保证同会话内顺序稳定、分页不重复）。
  static Future<({List<Comic> list, int total})> getRandomPage({
    required int seed,
    required int pageOffset,
    required int pageSize,
  }) {
    return getComics(
      random: true,
      seed: seed,
      pageOffset: pageOffset,
      pageSize: pageSize,
    );
  }

  static Future<
    ({
      Comic comic,
      List<Chapter> chapters,
      bool favorited,
      bool authorFavorited,
      ({int chapterId, int pageNumber})? progress,
    })
  >
  getComic(int id) async {
    final data = await _get('/api/comics/$id');
    final d = data['data'];
    final comic = Comic.fromJson(d);
    final chapters = (d['chapters'] as List)
        .map((e) => Chapter.fromJson(e))
        .toList();
    final p = d['progress'];
    return (
      comic: comic,
      chapters: chapters,
      favorited: d['favorited'] == true,
      authorFavorited: d['authorFavorited'] == true,
      progress: p != null && p['chapterId'] != null && p['pageNumber'] != null
          ? (
              chapterId: p['chapterId'] as int,
              pageNumber: p['pageNumber'] as int,
            )
          : null,
    );
  }

  static Future<List<Comic>> getRandomComics({int pageSize = 30}) async {
    final data = await _get('/api/comics/random?pageSize=$pageSize');
    return (data['data'] as List).map((e) => Comic.fromJson(e)).toList();
  }

  static Future<Comic> getRandomComic() async {
    final list = await getRandomComics(pageSize: 1);
    if (list.isEmpty) throw Exception('No comics found');
    return list[0];
  }

  static Future<List<ImageItem>> getChapterImages(int chapterId) async {
    final data = await _get('/api/chapters/$chapterId/images');
    return (data['data'] as List).map((e) => ImageItem.fromJson(e)).toList();
  }

  static Future<List<ReadingProgressEntry>> getRecent() async {
    final data = await _get('/api/mine/recent');
    return (data['data'] as List)
        .map((e) => ReadingProgressEntry.fromJson(e))
        .toList();
  }

  static Future<List<Comic>> getFavorites() async {
    final data = await _get('/api/mine/favorites');
    return (data['data'] as List).map((e) => Comic.fromJson(e)).toList();
  }

  static Future<void> updateProgress({
    required int comicId,
    required int chapterId,
    required int pageNumber,
  }) async {
    final url = '$baseUrl/api/comics/$comicId/progress';
    final res = await http.put(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'chapterId': chapterId, 'pageNumber': pageNumber}),
    );
    final data = jsonDecode(res.body);
    if (data['code'] != 0) throw Exception(data['message']);
  }

  static Future<void> setFavorite(int comicId, bool favorited) async {
    final url = '$baseUrl/api/comics/$comicId/favorite';
    final res = favorited
        ? await http.post(Uri.parse(url))
        : await http.delete(Uri.parse(url));
    final data = jsonDecode(res.body);
    if (data['code'] != 0) throw Exception(data['message']);
  }

  static Future<List<FavoriteAuthor>> getFavoriteAuthors() async {
    final data = await _get('/api/favorite-authors');
    return (data['data'] as List)
        .map((e) => FavoriteAuthor.fromJson(e))
        .toList();
  }

  static Future<void> setAuthorFavorite(String author, bool favorited) async {
    final url = '$baseUrl/api/favorite-authors';
    final body = jsonEncode({'author': author});
    final res = favorited
        ? await http.post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
        : await http.delete(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: body,
          );
    final data = jsonDecode(res.body);
    if (data['code'] != 0) throw Exception(data['message']);
  }
}
