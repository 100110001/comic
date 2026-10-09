import 'package:comic/models/image_resolution.dart';
import 'package:comic/providers/settings_provider.dart';
import 'dart:async';

import 'package:comic/providers/server_provider.dart';
import 'package:comic/providers/super_resolution_provider.dart';
import 'package:comic/models/image_item.dart';
import 'package:comic/models/super_resolution_job.dart';
import 'package:comic/services/api_client.dart';
import 'package:comic/utils/user_error.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

void main() {
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
    expect(container.read(superResolutionDefaultProvider), isTrue);
    expect(await loadSuperResolutionDefault(), isTrue);
    listener.close();
    await container.pump();
    listener = container.listen(superResolutionProvider, (_, _) {});
    expect(container.read(superResolutionProvider).enabled, isTrue);
    listener.close();
    SharedPreferences.setMockInitialValues({kSuperResolutionDefaultKey: 'bad'});
    expect(await loadSuperResolutionDefault(), isFalse);
  });

  test('关闭、换章和切服务器后超分晚到结果均不发布', () async {
    SharedPreferences.setMockInitialValues({});
    final clients = <_DelayedUpscaleClient>[];
    final container = ProviderContainer(
      overrides: [
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
    expect(clients.single.responses, isEmpty);
    for (final stop in [
      () => controller.setEnabled(false),
      controller.resetChapter,
    ]) {
      controller.setEnabled(true);
      controller.setWindow([image]);
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
      expect(container.read(superResolutionProvider).results, isEmpty);
    }
    controller.setEnabled(true);
    controller.setWindow([image]);
    final oldClient = clients.single;
    await container
        .read(serverSessionProvider.notifier)
        .save('http://other.test');
    await container.pump();
    oldClient.responses.last.completeError(StateError('旧请求失败'));
    await container.pump();
    expect(container.read(superResolutionProvider).enabled, isFalse);
    expect(container.read(superResolutionProvider).results, isEmpty);
    controller.setEnabled(true);
    controller.setWindow([image]);
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
      overrides: [apiClientProvider.overrideWithValue(client)],
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
    client.responses.last.complete([
      SuperResolutionJob(
        key: 'a' * 64,
        imageId: 1,
        status: 'ready',
        url: 'http://example.test/enhanced.webp',
      ),
    ]);
    await container.pump();
    final expected = container.read(superResolutionProvider).results[image.url];
    final generation = controller.generation;
    controller.setEnabled(false);
    controller.setEnabled(true);
    controller.setWindow([image]);
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
    expect(client.closed, isFalse);

    completer.complete();
    await expectLater(result, completes);
    await container.pump();
    expect(client.closed, isTrue);
  });
}

class _DelayedUpscaleClient extends ApiClient {
  _DelayedUpscaleClient(String url, int version)
    : super(baseUrl: url, generation: version);
  final responses = <Completer<List<SuperResolutionJob>>>[];
  @override
  Future<List<ImageResolution>> resolveImages(
    List<ImageItem> images, {
    required bool upscale,
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
