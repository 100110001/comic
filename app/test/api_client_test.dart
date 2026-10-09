import 'dart:convert';
import 'package:comic/models/image_item.dart';
import 'dart:async';

import 'package:comic/services/api_client.dart';
import 'package:comic/utils/user_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  ApiClient clientWith(
    Future<http.Response> Function(http.Request) handler, {
    Duration timeout = const Duration(seconds: 1),
  }) => ApiClient(
    baseUrl: 'http://example.test',
    generation: 1,
    client: MockClient(handler),
    timeout: timeout,
  );

  test('图片解析显式发送超分选择，原图先返回且失败不丢原图', () async {
    const image = ImageItem(
      id: 1,
      filename: '1.jpg',
      pageNumber: 0,
      url: 'http://example.test/static/1.jpg?v=20-30',
    );
    for (final upscale in [false, true]) {
      final client = clientWith((request) async {
        expect(request.url.path, '/api/images/resolve');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['upscale'], upscale);
        expect(body['images'], [
          {'id': 1, 'version': '20-30'},
        ]);
        return http.Response(
          jsonEncode({
            'code': 0,
            'data': [
              {
                'id': 1,
                'url': '/static/1.jpg?v=20-30',
                'superResolution': null,
                if (upscale) 'error': '引擎不可用',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final result = (await client.resolveImages([
        image,
      ], upscale: upscale)).single;
      expect(result.originalUrl, image.url);
      expect(result.superResolution, isNull);
      expect(result.error, upscale ? '引擎不可用' : null);
      client.close();
    }
  });

  test('健康检查严格匹配漫画服务响应', () async {
    final client = clientWith(
      (_) async => http.Response(
        '{"code":0,"message":"success","data":{"status":"ok"}}',
        200,
      ),
    );
    await expectLater(client.testConnection(), completes);
  });

  test('拒绝无法识别的健康响应', () async {
    final client = clientWith(
      (_) async => http.Response('{"code":0,"data":{"status":"other"}}', 200),
    );
    await expectLater(
      client.testConnection(),
      throwsA(
        isA<UserVisibleException>().having(
          (error) => error.message,
          'message',
          '该地址不是可识别的漫画服务器',
        ),
      ),
    );
  });

  test('HTTP、业务与格式错误映射为可展示错误', () async {
    final httpError = clientWith(
      (_) async => http.Response(
        '{"message":"没有权限"}',
        403,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    await expectLater(
      httpError.testConnection(),
      throwsA(
        isA<UserVisibleException>().having(
          (error) => error.message,
          'message',
          '没有权限',
        ),
      ),
    );

    final businessError = clientWith(
      (_) async => http.Response(
        '{"code":7,"message":"业务失败"}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    await expectLater(
      businessError.testConnection(),
      throwsA(
        isA<UserVisibleException>().having(
          (error) => error.message,
          'message',
          '业务失败',
        ),
      ),
    );

    final invalidJson = clientWith((_) async => http.Response('not-json', 200));
    await expectLater(
      invalidJson.testConnection(),
      throwsA(
        isA<UserVisibleException>().having(
          (error) => error.kind,
          'kind',
          UserErrorKind.invalidResponse,
        ),
      ),
    );
  });

  test('连接失败和超时使用稳定分类', () async {
    final connection = clientWith(
      (request) async => throw http.ClientException('refused', request.url),
    );
    await expectLater(
      connection.testConnection(),
      throwsA(
        isA<UserVisibleException>().having(
          (error) => error.kind,
          'kind',
          UserErrorKind.connection,
        ),
      ),
    );

    final timeout = clientWith(
      (_) => Completer<http.Response>().future,
      timeout: const Duration(milliseconds: 1),
    );
    await expectLater(
      timeout.testConnection(),
      throwsA(
        isA<UserVisibleException>().having(
          (error) => error.kind,
          'kind',
          UserErrorKind.timeout,
        ),
      ),
    );
  });
}
