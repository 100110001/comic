import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/comic.dart';
import '../models/chapter.dart';
import '../models/image_item.dart';

class ApiService {
  static Future<Map<String, dynamic>> _get(String path) async {
    final url = '$baseUrl$path';
    print('[API] GET $url');
    final res = await http.get(Uri.parse(url));
    return jsonDecode(res.body);
  }

  static Future<({List<Comic> list, int total})> getComics({
    int pageOffset = 1,
    int pageSize = 20,
    String keyword = '',
  }) async {
    final q = keyword.isNotEmpty ? '&keyword=${Uri.encodeComponent(keyword)}' : '';
    final data = await _get(
      '/api/comics?pageOffset=$pageOffset&pageSize=$pageSize$q',
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

  static Future<void> deleteComic(int id) async {
    final url = '$baseUrl/api/comics/$id';
    final res = await http.delete(Uri.parse(url));
    final data = jsonDecode(res.body);
    if (data['code'] != 0) throw Exception(data['message']);
  }

  static Future<List<ImageItem>> getChapterImages(int chapterId) async {
    final data = await _get('/api/chapters/$chapterId/images');
    return (data['data'] as List).map((e) => ImageItem.fromJson(e)).toList();
  }
}
