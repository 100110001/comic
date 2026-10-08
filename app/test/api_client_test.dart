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
