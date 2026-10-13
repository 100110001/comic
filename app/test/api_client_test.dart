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

  test('相同在途查询共享网络请求，完成后可再次查询', () async {
    final responses = <Completer<http.Response>>[];
    final client = clientWith((_) {
      final response = Completer<http.Response>();
      responses.add(response);
      return response.future;
    });
    final first = client.getComics(keyword: '漫画');
    final duplicate = client.getComics(keyword: '漫画');
    final other = client.getComics(keyword: '其他');
    await Future<void>.delayed(Duration.zero);
    expect(responses, hasLength(2));
    for (final response in responses) {
      response.complete(http.Response('{"code":0,"data":[],"total":0}', 200));
    }
    await Future.wait([first, duplicate, other]);
    final refresh = client.getComics(keyword: '漫画');
    await Future<void>.delayed(Duration.zero);
    expect(responses, hasLength(3));
    responses.last.complete(
      http.Response('{"code":0,"data":[],"total":0}', 200),
    );
    await refresh;
  });

  test('共享请求失败后解除合并，不缓存失败', () async {
    var calls = 0;
    final response = Completer<http.Response>();
    final client = clientWith((_) {
      calls++;
      return calls == 1
          ? response.future
          : Future.value(http.Response('{"code":0,"data":[],"total":0}', 200));
    });
    final first = expectLater(
      client.getComics(),
      throwsA(isA<UserVisibleException>()),
    );
    final second = expectLater(
      client.getComics(),
      throwsA(isA<UserVisibleException>()),
    );
    response.complete(http.Response('error', 500));
    await Future.wait([first, second]);
    await client.getComics();
    expect(calls, 2);
  });

  test('变更前后隔离查询，旧请求完成不删除新请求', () async {
    final reads = <Completer<http.Response>>[];
    final write = Completer<http.Response>();
    final client = clientWith((request) {
      if (request.method != 'GET') return write.future;
      final response = Completer<http.Response>();
      reads.add(response);
      return response.future;
    });
    final before = client.getComics();
    final mutation = client.setFavorite(1, true);
    final during = client.getComics();
    await Future<void>.delayed(Duration.zero);
    expect(reads, hasLength(2));
    reads.first.complete(http.Response('{"code":0,"data":[],"total":0}', 200));
    await before;
    final duplicate = client.getComics();
    await Future<void>.delayed(Duration.zero);
    expect(reads, hasLength(2));
    write.complete(http.Response('{"code":0}', 200));
    await mutation;
    final after = client.getComics();
    await Future<void>.delayed(Duration.zero);
    expect(reads, hasLength(3));
    reads[1].complete(http.Response('{"code":0,"data":[],"total":0}', 200));
    reads[2].complete(http.Response('{"code":0,"data":[],"total":0}', 200));
    await Future.wait([during, duplicate, after]);
  });

  test('不同服务器会话不会共享在途查询', () async {
    var calls = 0;
    final response = Completer<http.Response>();
    Future<http.Response> handler(http.Request _) {
      calls++;
      return response.future;
    }

    final first = clientWith(handler).getComics();
    final second = clientWith(handler).getComics();
    await Future<void>.delayed(Duration.zero);
    expect(calls, 2);
    response.complete(http.Response('{"code":0,"data":[],"total":0}', 200));
    await Future.wait([first, second]);
  });

  test('GPU 预处理策略必须是二到十页的整数', () async {
    for (final value in [4, 0, 11, '4']) {
      final client = clientWith((request) async {
        expect(request.url.path, '/api/super-resolution/policy');
        return http.Response(
          jsonEncode({
            'code': 0,
            'data': {'lookahead': value},
          }),
          200,
        );
      });
      addTearDown(client.close);
      if (value == 4) {
        expect(await client.getSuperResolutionLookahead(), 4);
      } else {
        await expectLater(
          client.getSuperResolutionLookahead(),
          throwsA(isA<UserVisibleException>()),
        );
      }
    }
  });

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
