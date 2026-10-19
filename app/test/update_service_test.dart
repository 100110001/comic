import 'package:comic/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:comic/models/update_info.dart';
import 'dart:convert';
import 'package:comic/providers/update_provider.dart';
import 'package:comic/providers/progress_lifecycle_provider.dart';
import 'package:comic/widgets/app_update_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const mandatory = UpdateInfo(
    latestVersion: '1.3.0',
    windowsUrl: 'https://example.test/update.exe',
    androidUrl: 'https://example.test/update.apk',
    windowsMinimumVersion: '1.2.2',
    androidMinimumVersion: '1.2.3',
  );

  test('同主版本按平台最低版本强更，边界版本放行', () {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(requiresUpdate(mandatory, '1.2.1'), isTrue);
    expect(requiresUpdate(mandatory, '1.2.2'), isFalse);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(requiresUpdate(mandatory, '1.2.2'), isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    expect(requiresUpdate(mandatory, '1.0.0'), isFalse);
  });

  test('拒绝异常清单，兼容没有最低版本的旧清单', () {
    expect(
      () => UpdateInfo.fromJson({
        'latestVersion': '1.3.0-beta',
        'platforms': <String, dynamic>{},
      }),
      throwsFormatException,
    );
    final json = mandatory.toJson();
    (json['platforms'] as Map)['windows']['minimumSupportedVersion'] = '2.0.0';
    expect(() => UpdateInfo.fromJson(json), throwsFormatException);
    final badUrl = mandatory.toJson();
    (badUrl['platforms'] as Map)['android']['downloadUrl'] = 'file:///bad.apk';
    expect(() => UpdateInfo.fromJson(badUrl), throwsFormatException);
    final old = UpdateInfo.fromJson({
      'latestVersion': '2.0.0',
      'platforms': {
        'windows': {'downloadUrl': 'https://example.test/update.exe'},
      },
    });
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(requiresUpdate(old, '1.0.0'), isFalse);
  });

  test('缓存强更经断网重启仍有效，新的有效清单可以撤回门槛', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({});
    var online = true;
    var result = mandatory;
    AppUpdateNotifier notifier() => AppUpdateNotifier(
      fetch: () async {
        if (!online) throw Exception('离线');
        return result;
      },
      version: () async => '1.2.1',
    );
    final first = ProviderContainer(
      overrides: [appUpdateProvider.overrideWith(notifier)],
    );
    await first.read(appUpdateProvider.notifier).check();
    expect(first.read(appUpdateProvider).required, isTrue);
    first.dispose();
    online = false;
    final restarted = ProviderContainer(
      overrides: [appUpdateProvider.overrideWith(notifier)],
    );
    addTearDown(restarted.dispose);
    await restarted.read(appUpdateProvider.notifier).check();
    expect(restarted.read(appUpdateProvider).required, isTrue);
    restarted.read(appUpdateProvider.notifier).dismiss();
    expect(restarted.read(appUpdateProvider).dismissed, isFalse);
    online = true;
    result = UpdateInfo.fromJson({
      ...mandatory.toJson(),
      'platforms': {
        'android': {
          'downloadUrl': mandatory.androidUrl,
          'minimumSupportedVersion': '1.0.0',
        },
      },
    });
    await restarted.read(appUpdateProvider.notifier).check();
    expect(restarted.read(appUpdateProvider).required, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(
      jsonDecode(
        prefs.getString(updateCacheKey)!,
      )['platforms']['android']['minimumSupportedVersion'],
      '1.0.0',
    );
  });

  test('首次断网或缓存损坏不阻断进入', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({updateCacheKey: '{bad'});
    final container = ProviderContainer(
      overrides: [
        appUpdateProvider.overrideWith(
          () => AppUpdateNotifier(
            fetch: () async => throw Exception('离线'),
            version: () async => '1.2.1',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appUpdateProvider.notifier).check();
    expect(container.read(appUpdateProvider).required, isFalse);
    expect(container.read(appUpdateProvider).startupPending, isFalse);
  });

  testWidgets('根更新门移除已有详情路由，返回与重试失败不能解除强更', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({});
    var lifecycleDisposed = false;
    final container = ProviderContainer(
      overrides: [
        progressLifecycleProvider.overrideWith((ref) {
          ref.onDispose(() => lifecycleDisposed = true);
        }),
        appUpdateProvider.overrideWith(
          () => AppUpdateNotifier(
            fetch: () async => mandatory,
            version: () async => '1.2.1',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    // 使用独立子导航作为已存在的业务树；强更后整个树必须卸载。
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => AppUpdateGate(child: child!),
          navigatorKey: nav,
          home: const Text('业务首页'),
        ),
      ),
    );
    nav.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('详情页')),
    );
    await tester.pumpAndSettle();
    expect(find.text('详情页'), findsOneWidget);
    await container.read(appUpdateProvider.notifier).check();
    await tester.pumpAndSettle();
    expect(find.text('需要更新后继续使用'), findsOneWidget);
    expect(find.text('详情页'), findsNothing);
    expect(nav.currentState, isNull);
    expect(lifecycleDisposed, isTrue);
    expect(find.text('稍后更新'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('需要更新后继续使用'), findsOneWidget);
    // 平台安装器不可用时失败，仍保留最低版本要求。
    await tester.tap(find.text('下载并更新'));
    await tester.pumpAndSettle();
    expect(container.read(appUpdateProvider).required, isTrue);
    expect(find.text('下载安装失败，请重试'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  test('更新包严格匹配支持的平台', () {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const info = UpdateInfo(
      latestVersion: '1.0.1',
      windowsUrl: 'windows.exe',
      androidUrl: 'android.apk',
    );
    for (final platform in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = platform;
      expect(updateUrlFor(info), switch (platform) {
        TargetPlatform.windows => 'windows.exe',
        TargetPlatform.android => 'android.apk',
        _ => null,
      });
    }
  });

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
