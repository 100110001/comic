import 'package:comic/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isNewerVersion', () {
    test('新版本更高时返回 true', () {
      expect(isNewerVersion('1.0.1', '1.0.0'), isTrue);
      expect(isNewerVersion('1.1.0', '1.0.9'), isTrue);
      expect(isNewerVersion('2.0.0', '1.9.9'), isTrue);
    });

    test('相同或更低时返回 false', () {
      expect(isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(isNewerVersion('1.0.0', '1.0.1'), isFalse);
      expect(isNewerVersion('1.0.0+1', '1.0.0+5'), isFalse);
    });

    test('忽略 build 号与 prerelease 后缀', () {
      expect(isNewerVersion('1.0.1+2', '1.0.0+9'), isTrue);
      expect(isNewerVersion('1.0.1-beta', '1.0.0'), isTrue);
      expect(isNewerVersion('1.0.0', '1.0.1-beta'), isFalse);
    });

    test('位数不一致时按缺失段视为 0', () {
      expect(isNewerVersion('1.0', '1.0.0'), isFalse);
      expect(isNewerVersion('1.0.1', '1.0'), isTrue);
    });
  });
}
