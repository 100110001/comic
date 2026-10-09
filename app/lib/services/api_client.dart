import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/chapter.dart';
import '../models/comic.dart';
import '../models/favorite_author.dart';
import '../models/image_item.dart';
import '../models/super_resolution_job.dart';
import '../models/image_resolution.dart';
import '../models/reading_progress_entry.dart';
import '../utils/user_error.dart';

/// 绑定到一个不可变服务器会话的漫画 API 客户端。
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.generation,
    http.Client? client,
    this.timeout = requestTimeout,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final String baseUrl;
  final int generation;
  final Duration timeout;
  final http.Client _client;
  final bool _ownsClient;

  void close() {
    if (_ownsClient) _client.close();
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Object? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    debugPrint('[API] $method $uri');

    final headers = body == null
        ? null
        : const {'Content-Type': 'application/json'};
    final encodedBody = body == null ? null : jsonEncode(body);

    try {
      late final Future<http.Response> pending;
      switch (method) {
        case 'GET':
          pending = _client.get(uri);
          break;
        case 'POST':
          pending = _client.post(uri, headers: headers, body: encodedBody);
          break;
        case 'PUT':
          pending = _client.put(uri, headers: headers, body: encodedBody);
          break;
        case 'DELETE':
          pending = _client.delete(uri, headers: headers, body: encodedBody);
          break;
        default:
          throw StateError('Unsupported HTTP method: $method');
      }

      final response = await pending.timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _httpError(response);
      }
      return _decodeEnvelope(response.body);
    } on UserVisibleException {
      rethrow;
    } on TimeoutException catch (error) {
      throw UserVisibleException(
        UserErrorKind.timeout,
        '请求超时，请检查服务器地址和网络',
        cause: error,
      );
    } on http.ClientException catch (error) {
      final detail = error.message.toLowerCase();
      if (detail.contains('certificate') || detail.contains('handshake')) {
        throw UserVisibleException(
          UserErrorKind.secureConnection,
          '无法建立安全连接，请检查服务器证书',
          cause: error,
        );
      }
      throw UserVisibleException(
        UserErrorKind.connection,
        '无法连接服务器，请检查地址和网络',
        cause: error,
      );
    } on FormatException catch (error) {
      throw UserVisibleException(
        UserErrorKind.invalidResponse,
        '服务器响应异常，请确认地址是否正确',
        cause: error,
      );
    }
  }

  UserVisibleException _httpError(http.Response response) {
    final message = _responseMessage(response.body);
    if (response.statusCode >= 500) {
      return UserVisibleException(
        UserErrorKind.server,
        message ?? '服务器内部错误（HTTP ${response.statusCode}）',
      );
    }
    return UserVisibleException(
      UserErrorKind.rejected,
      message ?? '服务器拒绝请求（HTTP ${response.statusCode}）',
    );
  }

  String? _responseMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] is String) {
        final message = (decoded['message'] as String).trim();
        return message.isEmpty ? null : message;
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> _decodeEnvelope(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic> || decoded['code'] is! num) {
      throw const UserVisibleException(
        UserErrorKind.invalidResponse,
        '服务器响应异常，请确认地址是否正确',
      );
    }
    if ((decoded['code'] as num) != 0) {
      final message = decoded['message'];
      throw UserVisibleException(
        UserErrorKind.rejected,
        message is String && message.trim().isNotEmpty ? message : '服务器拒绝请求',
      );
    }
    return decoded;
  }

  T _parse<T>(T Function() parser) {
    try {
      return parser();
    } on UserVisibleException {
      rethrow;
    } catch (error) {
      throw UserVisibleException(
        UserErrorKind.invalidResponse,
        '服务器响应异常，请确认地址是否正确',
        cause: error,
      );
    }
  }

  Future<void> testConnection() async {
    final envelope = await _request('GET', '/api/health');
    final data = envelope['data'];
    if (data is! Map || data['status'] != 'ok') {
      throw const UserVisibleException(
        UserErrorKind.invalidResponse,
        '该地址不是可识别的漫画服务器',
      );
    }
  }

  Future<({List<Comic> list, int total})> getComics({
    int pageOffset = 1,
    int pageSize = 20,
    String keyword = '',
    bool random = false,
    int? seed,
  }) async {
    final query = <String, String>{
      'pageOffset': '$pageOffset',
      'pageSize': '$pageSize',
      if (keyword.isNotEmpty) 'keyword': keyword,
      if (random) 'random': '1',
      if (seed != null) 'seed': '$seed',
    };
    final path = Uri(path: '/api/comics', queryParameters: query).toString();
    final data = await _request('GET', path);
    return _parse(() {
      final list = (data['data'] as List)
          .map((item) => Comic.fromJson(item, serverUrl: baseUrl))
          .toList();
      return (list: list, total: data['total'] as int);
    });
  }

  Future<({List<Comic> list, int total})> getRandomPage({
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

  Future<
    ({
      Comic comic,
      List<Chapter> chapters,
      bool favorited,
      bool authorFavorited,
      ({int chapterId, int pageNumber})? progress,
    })
  >
  getComic(int id) async {
    final envelope = await _request('GET', '/api/comics/$id');
    return _parse(() {
      final data = envelope['data'];
      final comic = Comic.fromJson(data, serverUrl: baseUrl);
      final chapters = (data['chapters'] as List)
          .map((item) => Chapter.fromJson(item))
          .toList();
      final progress = data['progress'];
      return (
        comic: comic,
        chapters: chapters,
        favorited: data['favorited'] == true,
        authorFavorited: data['authorFavorited'] == true,
        progress:
            progress != null &&
                progress['chapterId'] != null &&
                progress['pageNumber'] != null
            ? (
                chapterId: progress['chapterId'] as int,
                pageNumber: progress['pageNumber'] as int,
              )
            : null,
      );
    });
  }

  Future<List<Comic>> getRandomComics({int pageSize = 30}) async {
    final data = await _request('GET', '/api/comics/random?pageSize=$pageSize');
    return _parse(
      () => (data['data'] as List)
          .map((item) => Comic.fromJson(item, serverUrl: baseUrl))
          .toList(),
    );
  }

  Future<Comic> getRandomComic() async {
    final list = await getRandomComics(pageSize: 1);
    if (list.isEmpty) {
      throw const UserVisibleException(UserErrorKind.invalidResponse, '书库为空');
    }
    return list.first;
  }

  Future<List<ImageItem>> getChapterImages(int chapterId) async {
    final data = await _request('GET', '/api/chapters/$chapterId/images');
    return _parse(
      () => (data['data'] as List)
          .map((item) => ImageItem.fromJson(item, serverUrl: baseUrl))
          .toList(),
    );
  }

  Future<List<ImageResolution>> resolveImages(
    List<ImageItem> images, {
    required bool upscale,
  }) async {
    final data = await _request(
      'POST',
      '/api/images/resolve',
      body: {
        'upscale': upscale,
        'images': images
            .map(
              (image) => {
                'id': image.id,
                'version': Uri.parse(image.url).queryParameters['v'],
              },
            )
            .toList(),
      },
    );
    return _parse(
      () => (data['data'] as List)
          .map(
            (item) =>
                ImageResolution.fromJson(item as Map<String, dynamic>, baseUrl),
          )
          .toList(),
    );
  }

  Future<List<SuperResolutionJob>> getSuperResolutionJobs(
    List<String> keys,
  ) async {
    final path = Uri(
      path: '/api/super-resolution/jobs',
      queryParameters: {'keys': keys.join(',')},
    ).toString();
    final data = await _request('GET', path);
    return _parse(
      () => (data['data'] as List)
          .map(
            (item) => SuperResolutionJob.fromJson(
              item as Map<String, dynamic>,
              baseUrl,
            ),
          )
          .toList(),
    );
  }

  Future<void> clearSuperResolutionCache() async {
    await _request('DELETE', '/api/super-resolution/cache');
  }

  Future<List<ReadingProgressEntry>> getRecent() async {
    final data = await _request('GET', '/api/mine/recent');
    return _parse(
      () => (data['data'] as List)
          .map(
            (item) => ReadingProgressEntry.fromJson(item, serverUrl: baseUrl),
          )
          .toList(),
    );
  }

  Future<List<Comic>> getFavorites() async {
    final data = await _request('GET', '/api/mine/favorites');
    return _parse(
      () => (data['data'] as List)
          .map((item) => Comic.fromJson(item, serverUrl: baseUrl))
          .toList(),
    );
  }

  Future<void> updateProgress({
    required int comicId,
    required int chapterId,
    required int pageNumber,
  }) async {
    await _request(
      'PUT',
      '/api/comics/$comicId/progress',
      body: {'chapterId': chapterId, 'pageNumber': pageNumber},
    );
  }

  Future<void> setFavorite(int comicId, bool favorited) async {
    await _request(
      favorited ? 'POST' : 'DELETE',
      '/api/comics/$comicId/favorite',
    );
  }

  Future<List<FavoriteAuthor>> getFavoriteAuthors() async {
    final data = await _request('GET', '/api/favorite-authors');
    return _parse(
      () => (data['data'] as List)
          .map((item) => FavoriteAuthor.fromJson(item))
          .toList(),
    );
  }

  Future<void> setAuthorFavorite(String author, bool favorited) async {
    await _request(
      favorited ? 'POST' : 'DELETE',
      '/api/favorite-authors',
      body: {'author': author},
    );
  }
}
