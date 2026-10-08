import 'package:comic/providers/server_provider.dart';
import 'package:comic/utils/user_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('normalizeServerUrl', () {
    test('规范化空白和尾斜杠', () {
      expect(
        normalizeServerUrl('  http://192.168.1.8:8888/  '),
        'http://192.168.1.8:8888',
      );
      expect(normalizeServerUrl('https://[::1]:8888/'), 'https://[::1]:8888');
    });

    test('拒绝不是服务器 origin 的地址', () {
      for (final value in [
        '',
        '192.168.1.8:8888',
        'ftp://example.com',
        'http://user@example.com',
        'http://example.com/comic',
        'http://example.com?x=1',
        'http://example.com/#fragment',
      ]) {
        expect(
          () => normalizeServerUrl(value),
          throwsA(isA<UserVisibleException>()),
          reason: value,
        );
      }
    });
  });

  test('损坏的本地地址回退默认值', () async {
    SharedPreferences.setMockInitialValues({'serverUrl': 'not-a-url'});
    expect(await loadServerUrl(), 'http://192.168.124.4:8888');
  });
}
