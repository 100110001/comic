import 'package:comic/models/image_resolution.dart';
import 'package:comic/providers/settings_provider.dart';
import 'dart:async';

import 'package:comic/providers/server_provider.dart';
import 'package:comic/providers/server_data.dart';
import 'package:comic/providers/super_resolution_provider.dart';
import 'package:comic/models/image_item.dart';
import 'package:comic/models/super_resolution_job.dart';
import 'package:comic/services/api_client.dart';
import 'package:comic/utils/user_error.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:comic/config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _DelayedApiClient extends ApiClient {
  _DelayedApiClient(this.completer)
    : super(baseUrl: 'http://example.test', generation: -1);

  final Completer<void> completer;
  bool closed = false;

  @override
  Future<void> testConnection() => completer.future;

  @override
  void close() => closed = true;
}

class _FailingPreferencesStore extends InMemorySharedPreferencesStore {
  _FailingPreferencesStore() : super.empty();
  bool fail = true;
  Completer<void>? block;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    await block?.future;
    if (fail) return false;
    return super.setValue(valueType, key, value);
  }
}

class _ReloadingPreferencesStore extends InMemorySharedPreferencesStore {
  _ReloadingPreferencesStore() : super.empty();
  final reloadStarted = Completer<void>();
  final releaseReload = Completer<void>();
  final writes = <String>[];
  bool holdReload = false;

  @override
  Future<Map<String, Object>> getAll() async {
    final snapshot = await super.getAll();
    if (holdReload) {
      if (!reloadStarted.isCompleted) reloadStarted.complete();
      await releaseReload.future;
    }
    return snapshot;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    writes.add(key);
    if (key == 'flutter.themeMode') return false;
    return super.setValue(valueType, key, value);
  }
}

void main() {
  test('一种偏好失败恢复期间另一种偏好等待，成功值不被旧快照覆盖', () async {
    SharedPreferences.setMockInitialValues({});
    final previous = SharedPreferencesStorePlatform.instance;
    final store = _ReloadingPreferencesStore();
    SharedPreferencesStorePlatform.instance = store;
    addTearDown(() {
      SharedPreferencesStorePlatform.instance = previous;
      SharedPreferences.resetStatic();
    });
    await SharedPreferences.getInstance();
    store.holdReload = true;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final theme = container.read(themeModeProvider.notifier);
    final tray = container.read(closeToTrayProvider.notifier);
    final failure = expectLater(
      theme.setMode(ThemeMode.dark),
      throwsA(isA<UserVisibleException>()),
    );
    await store.reloadStarted.future;
    final success = tray.setEnabled(false);
    await Future<void>.delayed(Duration.zero);
    expect(store.writes, ['flutter.themeMode']);
    store.releaseReload.complete();
    await Future.wait([failure, success]);
    expect(container.read(themeModeProvider), ThemeMode.system);
    expect(container.read(closeToTrayProvider), isFalse);
    expect(await loadCloseToTray(), isFalse);
  });

  test('主题、托盘和服务器写入失败保留旧值与缓存，失败后仍能重试', () async {
    SharedPreferences.setMockInitialValues({});
    final previous = SharedPreferencesStorePlatform.instance;
    final store = _FailingPreferencesStore();
    SharedPreferencesStorePlatform.instance = store;
    addTearDown(() {
      SharedPreferencesStorePlatform.instance = previous;
      SharedPreferences.resetStatic();
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final theme = container.read(themeModeProvider.notifier);
    final tray = container.read(closeToTrayProvider.notifier);
    final server = container.read(serverSessionProvider.notifier);
    await expectLater(
      server.save('http://new.example.test'),
      throwsA(isA<UserVisibleException>()),
    );
    expect(container.read(serverSessionProvider).url, defaultServerUrl);
    expect(await loadServerUrl(), defaultServerUrl);
    await expectLater(
      theme.setMode(ThemeMode.dark),
      throwsA(isA<UserVisibleException>()),
    );
    await expectLater(
      tray.setEnabled(false),
      throwsA(isA<UserVisibleException>()),
    );
    expect(container.read(themeModeProvider), ThemeMode.system);
    expect(container.read(closeToTrayProvider), isTrue);
    expect(await loadThemeMode(), ThemeMode.system);
    expect(await loadCloseToTray(), isTrue);
    store.fail = false;
    await server.save('http://new.example.test');
    expect(
      container.read(serverSessionProvider).url,
      'http://new.example.test',
    );
    expect(await loadServerUrl(), 'http://new.example.test');
    await theme.setMode(ThemeMode.dark);
    await tray.setEnabled(false);
    expect(container.read(themeModeProvider), ThemeMode.dark);
    expect(container.read(closeToTrayProvider), isFalse);
    expect(await loadThemeMode(), ThemeMode.dark);
    expect(await loadCloseToTray(), isFalse);
  });

  testWidgets('服务器保存期间离开页面仍完成切源和状态清理', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final previous = SharedPreferencesStorePlatform.instance;
    final block = Completer<void>();
    final store = _FailingPreferencesStore()
      ..fail = false
      ..block = block;
    SharedPreferencesStorePlatform.instance = store;
    addTearDown(() {
      SharedPreferencesStorePlatform.instance = previous;
      SharedPreferences.resetStatic();
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    Future<bool>? pending;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, child) => TextButton(
              onPressed: () {
                pending = saveServerUrl(ref, 'http://new.example.test');
              },
              child: const Text('保存'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const SizedBox()),
    );
    block.complete();
    await tester.pump();
    expect(await pending, isTrue);
    expect(
      container.read(serverSessionProvider).url,
      'http://new.example.test',
    );
    expect(tester.takeException(), isNull);
  });

  test('损坏类型的启动偏好及非有限窗口尺寸安全回退', () async {
    SharedPreferences.setMockInitialValues({
      'serverUrl': true,
      'themeMode': 1,
      kCloseToTrayKey: 'false',
      kWindowBoundsKey: true,
    });
    expect(await loadServerUrl(), defaultServerUrl);
    expect(await loadThemeMode(), ThemeMode.system);
    expect(await loadCloseToTray(), isTrue);
    expect(await loadWindowBounds(), isNull);
    for (final bounds in ['NaN,0,800,600', '0,0,Infinity,600']) {
      SharedPreferences.setMockInitialValues({kWindowBoundsKey: bounds});
      expect(await loadWindowBounds(), isNull);
    }
  });

  test('快速修改外观和托盘偏好按顺序保存并发布', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final theme = container.read(themeModeProvider.notifier);
    final tray = container.read(closeToTrayProvider.notifier);
    await Future.wait([
      theme.setMode(ThemeMode.dark),
      theme.setMode(ThemeMode.light),
      tray.setEnabled(false),
      tray.setEnabled(true),
    ]);
    expect(container.read(themeModeProvider), ThemeMode.light);
    expect(await loadThemeMode(), ThemeMode.light);
    expect(container.read(closeToTrayProvider), isTrue);
    expect(await loadCloseToTray(), isTrue);
  });

  test('两入口的阅读偏好串行合并，重启恢复且损坏项独立回退', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(readerPreferencesProvider.notifier);
    await Future.wait([
      notifier.update((p) => p.copyWith(mode: ReaderMode.doublePage)),
      notifier.update((p) => p.copyWith(background: ReaderBackground.paper)),
      notifier.update((p) => p.copyWith(autoHide: false)),
    ]);
    final loaded = await loadReaderPreferences();
    expect(loaded.mode, ReaderMode.doublePage);
    expect(loaded.background, ReaderBackground.paper);
    expect(loaded.autoHide, isFalse);
    final restored = ProviderContainer(
      overrides: [
        readerPreferencesProvider.overrideWith(
          () => ReaderPreferencesNotifier(initial: loaded),
        ),
      ],
    );
    addTearDown(restored.dispose);
    expect(restored.read(readerPreferencesProvider).toJson(), loaded.toJson());
    SharedPreferences.setMockInitialValues({
      kReaderPreferencesKey:
          '{"mode":"invalid","background":"gray","autoHide":"invalid"}',
    });
    final partial = await loadReaderPreferences();
    expect(partial.mode, ReaderMode.automatic);
    expect(partial.background, ReaderBackground.gray);
    expect(partial.autoHide, isTrue);
    SharedPreferences.setMockInitialValues({
      kReaderPreferencesKey: 'invalid json',
    });
    expect(
      (await loadReaderPreferences()).toJson(),
      const ReaderPreferences().toJson(),
    );
  });

  test('超分三态保存及旧布尔偏好迁移', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await loadSuperResolutionMode(), SuperResolutionMode.adaptive);
    SharedPreferences.setMockInitialValues({kSuperResolutionDefaultKey: true});
    expect(await loadSuperResolutionMode(), SuperResolutionMode.on);
    SharedPreferences.setMockInitialValues({kSuperResolutionDefaultKey: false});
    expect(await loadSuperResolutionMode(), SuperResolutionMode.off);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container
        .read(superResolutionDefaultProvider.notifier)
        .setMode(SuperResolutionMode.adaptive);
    expect(await loadSuperResolutionMode(), SuperResolutionMode.adaptive);
    await container
        .read(superResolutionDefaultProvider.notifier)
        .setMode(SuperResolutionMode.off);
    expect(await loadSuperResolutionMode(), SuperResolutionMode.off);
  });

  test('自适应只增强缺少显示像素的图片，并限制动态窗口', () async {
    final client = _WindowUpscaleClient()..lookahead = 2;
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        superResolutionDefaultProvider.overrideWith(
          () => SuperResolutionDefaultNotifier(
            initialMode: SuperResolutionMode.adaptive,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(superResolutionProvider, (_, _) {});
    final images = List.generate(
      11,
      (index) => ImageItem(
        id: index + 1,
        filename: '$index.jpg',
        pageNumber: index,
        url: 'http://example.test/$index.jpg?v=20-30',
        width: index == 0
            ? 1600
            : index == 2
            ? null
            : 800,
        height: 1200,
      ),
    );
    final controller = container.read(superResolutionProvider.notifier);
    controller.setWindow(
      images,
      targetWidths: {for (final image in images) image.url: 1600},
    );
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    expect(client.windows.single, [2]);
    expect(client.submittedPriorities.single, {2: 1});
    expect(container.read(superResolutionProvider).lookahead, 2);
    expect(
      container.read(superResolutionProvider).reasons[images[0].url],
      '原图分辨率足够，已跳过',
    );
    expect(
      container.read(superResolutionProvider).reasons[images[2].url],
      '原图尺寸未知，保留原图',
    );
    controller.setEnabled(false);
    controller.setEnabled(true);
    expect(
      container.read(superResolutionProvider).mode,
      SuperResolutionMode.adaptive,
    );
    controller.setWindow(
      images,
      targetWidths: {for (final image in images) image.url: 600},
    );
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    expect(client.choices.last, isFalse);
    expect(
      container.read(superResolutionProvider).reasons[images[1].url],
      '原图分辨率足够，已跳过',
    );
  });

  test('关闭后晚到的 GPU 策略不提交增强任务', () async {
    final client = _DelayedPolicyClient();
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        superResolutionDefaultProvider.overrideWith(
          () => SuperResolutionDefaultNotifier(initial: true),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(superResolutionProvider, (_, _) {});
    final controller = container.read(superResolutionProvider.notifier);
    controller.setWindow([
      const ImageItem(
        id: 1,
        filename: '1.jpg',
        pageNumber: 0,
        url: 'http://example.test/1.jpg?v=20-30',
      ),
    ]);
    controller.setEnabled(false);
    client.policy.complete(10);
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    expect(client.windows, isEmpty);
    expect(container.read(superResolutionProvider).enabled, isFalse);
  });

  testWidgets('阅读位置不变时也根据新 GPU 策略推进窗口', (tester) async {
    final client = _WindowUpscaleClient()..lookahead = 2;
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        superResolutionDefaultProvider.overrideWith(
          () => SuperResolutionDefaultNotifier(initial: true),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(superResolutionProvider, (_, _) {});
    final images = List.generate(
      11,
      (index) => ImageItem(
        id: index + 1,
        filename: '$index.jpg',
        pageNumber: index,
        url: 'http://example.test/$index.jpg?v=20-30',
      ),
    );
    container.read(superResolutionProvider.notifier).setWindow(images);
    await tester.pump();
    await tester.pump();
    expect(client.windows.single, [1, 2, 3]);
    client.lookahead = 6;
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(client.windows.last, [1, 2, 3, 4, 5, 6, 7]);
    expect(container.read(superResolutionProvider).lookahead, 6);
    client.policyFails = true;
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(container.read(superResolutionProvider).lookahead, 4);
    container.read(superResolutionProvider.notifier).setEnabled(false);
    await tester.pump();
  });

  test('默认超分窗口随翻页推进，关闭后仍请求原图且不提交增强', () async {
    final client = _WindowUpscaleClient();
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        superResolutionDefaultProvider.overrideWith(
          () => SuperResolutionDefaultNotifier(initial: true),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(superResolutionProvider, (_, _) {});
    final images = List.generate(
      100,
      (index) => ImageItem(
        id: index + 1,
        filename: '${index + 1}.jpg',
        pageNumber: index,
        url: 'http://example.test/${index + 1}.jpg?v=20-30',
      ),
    );
    final reader = container.read(superResolutionProvider.notifier);
    reader.setWindow(images.take(superResolutionWindowSize).toList());
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    expect(client.windows, [List.generate(11, (index) => index + 1)]);
    reader.setWindow(images.skip(7).take(superResolutionWindowSize).toList());
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    expect(client.windows.last, List.generate(11, (index) => index + 8));
    expect(
      container.read(superResolutionProvider).results[images[17].url]?.status,
      'ready',
    );
    reader.setWindow(images.skip(94).take(superResolutionWindowSize).toList());
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    expect(client.windows.last, [95, 96, 97, 98, 99, 100]);
    reader.setEnabled(false);
    reader.setWindow(images.skip(7).take(superResolutionWindowSize).toList());
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    expect(client.windows.last, List.generate(11, (index) => index + 8));
    expect(client.choices, [true, true, true, false]);
    expect(
      container.read(superResolutionDefaultProvider),
      SuperResolutionMode.on,
    );
  });

  test('超分默认值持久化，阅读器临时关闭不修改设置，重进恢复默认', () async {
    SharedPreferences.setMockInitialValues({});
    final saved = ProviderContainer();
    await saved.read(superResolutionDefaultProvider.notifier).setEnabled(true);
    expect(await loadSuperResolutionDefault(), isTrue);
    saved.dispose();
    final container = ProviderContainer(
      overrides: [
        superResolutionDefaultProvider.overrideWith(
          () => SuperResolutionDefaultNotifier(initial: true),
        ),
      ],
    );
    addTearDown(container.dispose);
    var listener = container.listen(superResolutionProvider, (_, _) {});
    expect(container.read(superResolutionProvider).enabled, isTrue);
    final reader = container.read(superResolutionProvider.notifier);
    reader.setEnabled(false);
    reader.resetChapter();
    expect(container.read(superResolutionProvider).enabled, isFalse);
    expect(
      container.read(superResolutionDefaultProvider),
      SuperResolutionMode.on,
    );
    expect(await loadSuperResolutionDefault(), isTrue);
    listener.close();
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    listener = container.listen(superResolutionProvider, (_, _) {});
    expect(container.read(superResolutionProvider).enabled, isTrue);
    listener.close();
    SharedPreferences.setMockInitialValues({kSuperResolutionDefaultKey: 'bad'});
    expect(await loadSuperResolutionMode(), SuperResolutionMode.adaptive);
  });

  test('关闭、换章和切服务器后超分晚到结果均不发布', () async {
    SharedPreferences.setMockInitialValues({});
    final clients = <_DelayedUpscaleClient>[];
    final container = ProviderContainer(
      overrides: [
        superResolutionDefaultProvider.overrideWith(
          () => SuperResolutionDefaultNotifier(initial: false),
        ),
        serverSessionProvider.overrideWith(
          () => ServerSessionNotifier(initialUrl: 'http://example.test'),
        ),
        apiClientFactoryProvider.overrideWithValue(({
          required baseUrl,
          required generation,
        }) {
          final client = _DelayedUpscaleClient(baseUrl, generation);
          clients.add(client);
          return client;
        }),
      ],
    );
    addTearDown(container.dispose);
    container.listen(superResolutionProvider, (_, _) {});
    const image = ImageItem(
      id: 1,
      filename: '1.jpg',
      pageNumber: 0,
      url: 'http://example.test/1.jpg?v=20-30',
    );
    final controller = container.read(superResolutionProvider.notifier);
    controller.setWindow([image]);
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    expect(clients.single.responses, isEmpty);
    for (final stop in [
      () => controller.setEnabled(false),
      controller.resetChapter,
    ]) {
      controller.setEnabled(true);
      controller.setWindow([image]);
      await container.pump();
      await Future<void>.delayed(Duration.zero);
      await container.pump();
      stop();
      clients.single.responses.last.complete([
        SuperResolutionJob(
          key: 'a' * 64,
          imageId: 1,
          status: 'ready',
          url: 'http://example.test/enhanced.webp',
        ),
      ]);
      await container.pump();
      await Future<void>.delayed(Duration.zero);
      await container.pump();
      expect(container.read(superResolutionProvider).results, isEmpty);
    }
    controller.setEnabled(true);
    controller.setWindow([image]);
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    final oldClient = clients.single;
    await container
        .read(serverSessionProvider.notifier)
        .save('http://other.test');
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    oldClient.responses.last.completeError(StateError('旧请求失败'));
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    expect(container.read(superResolutionProvider).enabled, isFalse);
    expect(container.read(superResolutionProvider).results, isEmpty);
    controller.setEnabled(true);
    controller.setWindow([image]);
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    expect(clients.last.responses, isEmpty);
    expect(
      container.read(superResolutionProvider).results[image.url]!.status,
      'failed',
    );
  });

  test('旧增强图解码失败不能覆盖关闭后重新开启的新结果', () async {
    final client = _DelayedUpscaleClient('http://example.test', 0);
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        superResolutionDefaultProvider.overrideWith(
          () => SuperResolutionDefaultNotifier(initial: true),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(client.close);
    container.listen(superResolutionProvider, (_, _) {});
    final controller = container.read(superResolutionProvider.notifier);
    const image = ImageItem(
      id: 1,
      filename: '1.jpg',
      pageNumber: 0,
      url: 'http://example.test/1.jpg?v=20-30',
    );
    controller.setEnabled(true);
    controller.setWindow([image]);
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    client.responses.last.complete([
      SuperResolutionJob(
        key: 'a' * 64,
        imageId: 1,
        status: 'ready',
        url: 'http://example.test/enhanced.webp',
      ),
    ]);
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    final expected = container.read(superResolutionProvider).results[image.url];
    final generation = controller.generation;
    controller.setEnabled(false);
    controller.setEnabled(true);
    controller.setWindow([image]);
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    controller.imageFailed(
      image.url,
      generation: generation,
      expected: expected,
    );
    expect(
      container.read(superResolutionProvider).results[image.url]!.status,
      'ready',
    );
  });

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

  test('一次性读取连接测试时 HTTP 客户端存活到请求完成', () async {
    final completer = Completer<void>();
    late _DelayedApiClient client;
    final container = ProviderContainer(
      overrides: [
        apiClientFactoryProvider.overrideWithValue(({
          required baseUrl,
          required generation,
        }) {
          return client = _DelayedApiClient(completer);
        }),
      ],
    );
    addTearDown(container.dispose);

    final result = container.read(
      serverConnectionTestProvider('http://example.test').future,
    );
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    expect(client.closed, isFalse);

    completer.complete();
    await expectLater(result, completes);
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    expect(client.closed, isTrue);
  });
}

class _DelayedUpscaleClient extends ApiClient {
  _DelayedUpscaleClient(String url, int version)
    : super(baseUrl: url, generation: version);
  @override
  Future<int> getSuperResolutionLookahead() async => 10;
  final responses = <Completer<List<SuperResolutionJob>>>[];
  @override
  Future<List<ImageResolution>> resolveImages(
    List<ImageItem> images, {
    required bool upscale,
    Map<int, int>? priorities,
  }) {
    if (!upscale) {
      return Future.value(
        images
            .map(
              (image) =>
                  ImageResolution(imageId: image.id, originalUrl: image.url),
            )
            .toList(),
      );
    }
    final response = Completer<List<SuperResolutionJob>>();
    responses.add(response);
    return response.future.then(
      (jobs) => images
          .map(
            (image) => ImageResolution(
              imageId: image.id,
              originalUrl: image.url,
              superResolution: jobs.singleWhere(
                (job) => job.imageId == image.id,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _WindowUpscaleClient extends ApiClient {
  _WindowUpscaleClient() : super(baseUrl: 'http://example.test', generation: 0);
  var lookahead = 10;
  var policyFails = false;
  final submittedPriorities = <Map<int, int>>[];
  @override
  Future<int> getSuperResolutionLookahead() async {
    if (policyFails) throw StateError('策略不可用');
    return lookahead;
  }

  final windows = <List<int>>[];
  final choices = <bool>[];
  @override
  Future<List<ImageResolution>> resolveImages(
    List<ImageItem> images, {
    required bool upscale,
    Map<int, int>? priorities,
  }) async {
    windows.add(images.map((image) => image.id).toList());
    submittedPriorities.add(priorities ?? {});
    choices.add(upscale);
    return images
        .map(
          (image) => ImageResolution(
            imageId: image.id,
            originalUrl: image.url,
            superResolution: upscale
                ? SuperResolutionJob(
                    key: 'a' * 64,
                    imageId: image.id,
                    status: 'ready',
                    url: 'http://example.test/enhanced-${image.id}.webp',
                  )
                : null,
          ),
        )
        .toList();
  }
}

class _DelayedPolicyClient extends _WindowUpscaleClient {
  final policy = Completer<int>();
  @override
  Future<int> getSuperResolutionLookahead() => policy.future;
}
