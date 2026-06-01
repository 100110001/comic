import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/comic.dart';
import '../models/chapter.dart';
import '../models/image_item.dart';

class ApiService {
  static Future<Map<String, dynamic>> _get(String path) async {
    final res = await http.get(Uri.parse('$baseUrl$path'));
    return jsonDecode(res.body);
  }

  static Future<({List<Comic> list, int total})> getComics({
    int pageOffset = 1,
    int pageSize = 20,
  }) async {
    final data = await _get(
      '/api/comics?pageOffset=$pageOffset&pageSize=$pageSize',
    );
    final list = (data['data'] as List).map((e) => Comic.fromJson(e)).toList();
    return (list: list, total: data['total'] as int);
  }

  static Future<({Comic comic, List<Chapter> chapters})> getComic(
    int id,
  ) async {
    final data = await _get('/api/comics/$id');
    final d = data['data'];
    final comic = Comic.fromJson(d);
    final chapters = (d['chapters'] as List)
        .map((e) => Chapter.fromJson(e))
        .toList();
    return (comic: comic, chapters: chapters);
  }

  static Future<List<ImageItem>> getChapterImages(int chapterId) async {
    final data = await _get('/api/chapters/$chapterId/images');
    return (data['data'] as List).map((e) => ImageItem.fromJson(e)).toList();
  }
}
