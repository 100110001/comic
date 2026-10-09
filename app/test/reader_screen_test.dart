import 'dart:async';
import 'dart:io';

import 'package:comic/models/chapter.dart';
import 'package:comic/models/comic.dart';
import 'package:comic/models/image_item.dart';
import 'package:comic/models/super_resolution_job.dart';
import 'package:comic/providers/super_resolution_provider.dart';
import 'package:comic/widgets/enhanced_image.dart';
import 'package:comic/providers/comics_providers.dart';
import 'package:comic/providers/reader_providers.dart';
import 'package:comic/providers/reading_progress_provider.dart';
import 'helpers/progress_storage.dart';
import 'package:comic/providers/server_provider.dart';
import 'package:comic/screens/reader_screen.dart';
import 'package:comic/services/api_client.dart';
import 'package:comic/theme.dart';
import 'package:comic/utils/display_image_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> settleReader(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  // 尺寸解码会读取原图描述符；等待真实引擎任务，避免假时钟饿死解码。
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      await precacheImage(image.image, element, onError: (error, stack) {});
    }
  });
  await tester.pumpAndSettle();
}

final _imageRequests = <String, int>{};
final _failedImageUrls = <String>{};

void main() {
  setUpAll(() {
    HttpOverrides.global = _FakeHttpOverrides();
  });

  setUp(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    _imageRequests.clear();
    _failedImageUrls.clear();
  });

  // 固定 400x800 手机宽度；图片 800x1200 → 预估高度 600px。
  Future<void> pumpReader(
    WidgetTester tester, {
    int? initialPage,
    double width = 400,
    List<Chapter>? chapters,
    Future<Comic?> Function()? onNextComic,
    ApiClient? srClient,
  }) async {
    final client = srClient ?? _ProgressClient();
    addTearDown(client.close);
    final images = List.generate(
      10,
      (i) => ImageItem(
        id: i,
        filename: '$i.jpg',
        pageNumber: i,
        url: 'http://example.com/$i.jpg',
        width: 800,
        height: 1200,
      ),
    );
    final detail = ComicDetail(
      comic: Comic(id: 1, title: '测试漫画'),
      chapters: chapters ?? [const Chapter(id: 1, title: '第1话', sortOrder: 0)],
      favorited: false,
      authorFavorited: false,
      progress: null,
    );

    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          progressStorageProvider.overrideWithValue(MemoryProgressStorage()),
          serverSessionProvider.overrideWith(
            () => ServerSessionNotifier(initialUrl: 'http://example.com'),
          ),
          comicDetailProvider.overrideWith((ref, id) async => detail),
          chapterImagesProvider.overrideWith((ref, id) async => images),
        ],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.dark),
          home: ReaderScreen(
            comicId: 1,
            chapterId: 1,
            title: '测试漫画',
            initialPage: initialPage,
            onNextComic: onNextComic,
          ),
        ),
      ),
    );
    await settleReader(tester);
  }

  testWidgets('320px 发现阅读器新增超分入口不溢出', (tester) async {
    await pumpReader(tester, width: 320, onNextComic: () async => null);
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('开启超分 2×'), findsOneWidget);
  });

  testWidgets('超分先保留原图，结果就绪和关闭均不改变手机阅读位置', (tester) async {
    final client = _UpscaleProgressClient();
    await pumpReader(tester, initialPage: 2, srClient: client);
    final list = tester.widget<ListView>(find.byType(ListView));
    final offset = list.controller!.offset;
    expect(client.requested, isEmpty);
    await tester.tap(find.byTooltip('开启超分 2×'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开启超分 2×'));
    await tester.pump();
    expect(client.requested.map((image) => image.id), [2, 3, 4]);
    expect(
      tester
          .widgetList<EnhancedImage>(find.byType(EnhancedImage))
          .every((image) => image.enhanced == null),
      isTrue,
    );
    client.complete();
    await settleReader(tester);
    expect(
      tester
          .widgetList<EnhancedImage>(find.byType(EnhancedImage))
          .any((image) => image.enhanced != null),
      isTrue,
    );
    expect(list.controller!.offset, offset);
    expect(find.text('第 3 / 10 页'), findsOneWidget);
    await tester.tap(find.byTooltip('超分 2× 已就绪，点击显示原图'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('关闭超分 2×'));
    await tester.pump();
    expect(
      tester
          .widgetList<EnhancedImage>(find.byType(EnhancedImage))
          .every((image) => image.enhanced == null),
      isTrue,
    );
    expect(list.controller!.offset, offset);
  });

  testWidgets('增强图下载失败仍显示原图，超分错误可重试', (tester) async {
    final client = _UpscaleProgressClient();
    await pumpReader(tester, initialPage: 2, srClient: client);
    _failedImageUrls.add('http://example.com/enhanced-2.png');
    await tester.tap(find.byTooltip('开启超分 2×'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开启超分 2×'));
    await tester.pump();
    client.complete();
    await settleReader(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ReaderScreen)),
    );
    expect(
      container
          .read(superResolutionProvider)
          .results['http://example.com/2.jpg']!
          .status,
      'failed',
    );
    expect(find.text('点击重试'), findsNothing);
    expect(find.text('第 3 / 10 页'), findsOneWidget);
    expect(_imageRequests['http://example.com/2.jpg'], 1);
  });

  testWidgets('移动端初始定位到指定页且滚动偏移与页码一致', (tester) async {
    await pumpReader(tester, initialPage: 5);

    expect(find.text('第 6 / 10 页'), findsOneWidget);
    final c = ProviderScope.containerOf(
      tester.element(find.byType(ReaderScreen)),
    );
    expect(
      c.read(readingProgressQueueProvider).requireValue.single.entry.pageNumber,
      5,
    );
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(ReaderScreen),
        matching: find.byType(Scrollable),
      ),
    );
    // 第 5 页（0 起始）的顶部偏移 = 5 × 600
    expect(scrollable.position.pixels, closeTo(5 * 600, 1));
  });

  testWidgets('移动端滚动一页后页码更新', (tester) async {
    await pumpReader(tester);
    expect(find.text('第 1 / 10 页'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await settleReader(tester);

    expect(find.text('第 2 / 10 页'), findsOneWidget);
    final c = ProviderScope.containerOf(
      tester.element(find.byType(ReaderScreen)),
    );
    final client = c.read(apiClientProvider) as _ProgressClient;
    expect(
      c.read(readingProgressQueueProvider).requireValue.single.entry.pageNumber,
      1,
    );
    expect(client.positions, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await settleReader(tester);
    expect(client.positions.single.pageNumber, 1);
    expect(c.read(readingProgressQueueProvider).requireValue, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets(
    '发现连续换书与返回保存当前漫画的章节和页码',
    (tester) async {
      final client = _ProgressClient();
      addTearDown(client.close);
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var comicId = 1;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            progressStorageProvider.overrideWithValue(MemoryProgressStorage()),
            serverSessionProvider.overrideWith(
              () => ServerSessionNotifier(initialUrl: 'http://example.com'),
            ),
            apiClientProvider.overrideWithValue(client),
            comicDetailProvider.overrideWith(
              (ref, id) async => ComicDetail(
                comic: Comic(id: id, title: '漫画$id'),
                chapters: [Chapter(id: id * 10, title: '章节$id', sortOrder: 0)],
                favorited: false,
                authorFavorited: false,
              ),
            ),
            chapterImagesProvider.overrideWith(
              (ref, id) async => [
                for (var page = 0; page < 3; page++)
                  ImageItem(
                    id: id * 10 + page,
                    filename: '$page.png',
                    pageNumber: page,
                    url: 'http://example.com/$id/$page.png',
                    width: 800,
                    height: 1200,
                  ),
              ],
            ),
          ],
          child: MaterialApp(
            theme: buildAppTheme(Brightness.dark),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReaderScreen(
                        comicId: 1,
                        chapterId: 10,
                        title: '漫画1',
                        onNextComic: () async =>
                            Comic(id: ++comicId, title: '漫画$comicId'),
                      ),
                    ),
                  ),
                  child: const Text('开始阅读'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('开始阅读'));
      await settleReader(tester);
      await tester.tap(find.byTooltip('下一本'));
      await settleReader(tester);
      // 在第二本翻到第 2 页，再切第三本。
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settleReader(tester);
      await tester.tap(find.byTooltip('下一本'));
      await settleReader(tester);
      await tester.pageBack();
      await settleReader(tester);
      expect(client.positions, [
        (comicId: 1, chapterId: 10, pageNumber: 0),
        (comicId: 2, chapterId: 20, pageNumber: 1),
        (comicId: 3, chapterId: 30, pageNumber: 0),
      ]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  testWidgets(
    '桌面 Page Up 和 Page Down 换章并遵循章节边界',
    (tester) async {
      var nextComicCalls = 0;
      await pumpReader(
        tester,
        width: 1200,
        initialPage: 4,
        chapters: [
          for (var i = 1; i <= 3; i++)
            Chapter(id: i, title: '第$i话', sortOrder: i - 1),
        ],
        onNextComic: () async {
          nextComicCalls++;
          return null;
        },
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ReaderScreen)),
      );
      Future<void> press(LogicalKeyboardKey key) async {
        await tester.sendKeyEvent(key);
        await settleReader(tester);
      }

      await press(LogicalKeyboardKey.pageUp);
      expect(find.text('第1话'), findsOneWidget);
      expect(find.text('第 5 / 10 页'), findsOneWidget);
      await press(LogicalKeyboardKey.pageDown);
      expect(find.text('第2话'), findsOneWidget);
      expect(find.text('第 1 / 10 页'), findsOneWidget);
      final entry = container
          .read(readingProgressQueueProvider)
          .requireValue
          .single
          .entry;
      expect(entry.chapterId, 2);
      expect(entry.pageNumber, 0);

      await press(LogicalKeyboardKey.arrowRight);
      expect(find.text('第 2 / 10 页'), findsOneWidget);
      await tester.tap(find.byType(Slider));
      await settleReader(tester);
      await press(LogicalKeyboardKey.pageUp);
      expect(find.text('第1话'), findsOneWidget);
      expect(find.text('第 1 / 10 页'), findsOneWidget);
      await press(LogicalKeyboardKey.pageDown);
      await press(LogicalKeyboardKey.pageDown);
      expect(find.text('第3话'), findsOneWidget);
      await press(LogicalKeyboardKey.end);
      expect(find.text('第 10 / 10 页'), findsOneWidget);
      await press(LogicalKeyboardKey.pageDown);
      expect(find.text('第3话'), findsOneWidget);
      expect(find.text('第 10 / 10 页'), findsOneWidget);
      expect(nextComicCalls, 0);
      await press(LogicalKeyboardKey.home);
      await press(LogicalKeyboardKey.space);
      expect(find.text('第 2 / 10 页'), findsOneWidget);
      await press(LogicalKeyboardKey.arrowLeft);
      expect(find.text('第 1 / 10 页'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    '单章节 Page Up 和 Page Down 不改变页码',
    (tester) async {
      await pumpReader(tester, width: 1200, initialPage: 4);
      for (final key in [
        LogicalKeyboardKey.pageUp,
        LogicalKeyboardKey.pageDown,
      ]) {
        await tester.sendKeyEvent(key);
        await settleReader(tester);
        expect(find.text('第 5 / 10 页'), findsOneWidget);
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    '桌面显示命中相邻预加载尺寸缓存，同档窗口调整复用',
    (tester) async {
      await pumpReader(tester, width: 1200);
      const url = 'http://example.com/0.jpg';
      final image = tester.widget<Image>(find.byType(Image).first);
      final provider = image.image as DisplaySizedNetworkImage;
      expect(provider.fit, BoxFit.contain);
      final viewport = tester.getSize(
        find
            .ancestor(
              of: find.byType(Image).first,
              matching: find.byType(LayoutBuilder),
            )
            .first,
      );
      final expected = displayImageProvider(
        url,
        logicalSize: viewport,
        devicePixelRatio: 1,
        fit: BoxFit.contain,
      );
      final key = await provider.obtainKey(ImageConfiguration.empty);
      expect(key, await expected.obtainKey(ImageConfiguration.empty));
      expect(_imageRequests['http://example.com/1.jpg'], 1);
      expect(_imageRequests['http://example.com/2.jpg'], 1);
      expect(_imageRequests['http://example.com/3.jpg'], isNull);
      expect(
        PaintingBinding.instance.imageCache.containsKey(NetworkImage(url)),
        isFalse,
      );
      tester.view.physicalSize = const Size(1100, 800);
      await settleReader(tester);
      final resized = tester.widget<Image>(find.byType(Image).first).image;
      expect(await resized.obtainKey(ImageConfiguration.empty), key);
      expect(_imageRequests[url], 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settleReader(tester);
      expect(_imageRequests['http://example.com/1.jpg'], 1);
      expect(find.text('第 2 / 10 页'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    '桌面与移动布局切换保留当前页和本机断点',
    (tester) async {
      await pumpReader(tester, width: 1200);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settleReader(tester);
      tester.view.physicalSize = const Size(400, 800);
      await settleReader(tester);
      expect(find.text('第 2 / 10 页'), findsOneWidget);
      final c = ProviderScope.containerOf(
        tester.element(find.byType(ReaderScreen)),
      );
      expect(
        c
            .read(readingProgressQueueProvider)
            .requireValue
            .single
            .entry
            .pageNumber,
        1,
      );
      final provider =
          tester.widget<Image>(find.byType(Image).first).image
              as DisplaySizedNetworkImage;
      expect(provider.fit, BoxFit.fitWidth);
      expect(provider.height, isNull);
      tester.view.physicalSize = const Size(450, 800);
      await settleReader(tester);
      expect(find.text('第 2 / 10 页'), findsOneWidget);
      tester.view.physicalSize = const Size(1100, 800);
      await settleReader(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settleReader(tester);
      tester.view.physicalSize = const Size(400, 800);
      await settleReader(tester);
      expect(find.text('第 3 / 10 页'), findsOneWidget);
      expect(
        c
            .read(readingProgressQueueProvider)
            .requireValue
            .single
            .entry
            .pageNumber,
        2,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final width in [400.0, 1200.0]) {
    testWidgets(
      '缩图失败重试清实际缓存并重新请求（宽 $width）',
      (tester) async {
        const url = 'http://example.com/0.jpg';
        _failedImageUrls.add(url);
        await pumpReader(tester, width: width);
        expect(find.text('点击重试'), findsOneWidget);
        final provider = tester.widget<Image>(find.byType(Image).first).image;
        _failedImageUrls.remove(url);
        // 在错误页面保持不变时模拟预加载获得了有效尺寸缓存。
        await tester.runAsync(
          () => precacheImage(
            provider,
            tester.element(find.byType(ReaderScreen)),
            onError: (error, stack) {},
          ),
        );
        final key = await provider.obtainKey(ImageConfiguration.empty);
        expect(PaintingBinding.instance.imageCache.containsKey(key), isTrue);
        final before = _imageRequests[url]!;
        await tester.tap(find.text('点击重试'));
        await settleReader(tester);
        expect(_imageRequests[url], before + 1);
        expect(find.text('点击重试'), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
}

class _ProgressClient extends ApiClient {
  _ProgressClient() : super(baseUrl: 'http://example.com', generation: 0);

  final positions = <({int comicId, int chapterId, int pageNumber})>[];

  @override
  Future<void> updateProgress({
    required int comicId,
    required int chapterId,
    required int pageNumber,
  }) async {
    positions.add((
      comicId: comicId,
      chapterId: chapterId,
      pageNumber: pageNumber,
    ));
  }
}

/// 测试用假网络层：所有请求返回 1x1 透明 PNG，避免真实网络报 400。
class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

class _FakeHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Duration idleTimeout = const Duration(seconds: 5);

  @override
  Duration? connectionTimeout = const Duration(seconds: 5);

  @override
  int? maxConnectionsPerHost;

  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _FakeHttpClientRequest(url.toString());

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeHttpClientRequest();

  @override
  Future<HttpClientRequest> get(String host, int port, String path) async =>
      _FakeHttpClientRequest();

  @override
  Future<HttpClientRequest> post(String host, int port, String path) async =>
      _FakeHttpClientRequest();

  @override
  Future<HttpClientRequest> put(String host, int port, String path) async =>
      _FakeHttpClientRequest();

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) async =>
      _FakeHttpClientRequest();

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest([this.url = '']);
  final String url;
  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  Future<HttpClientResponse> close() async {
    _imageRequests.update(url, (n) => n + 1, ifAbsent: () => 1);
    return _FakeHttpClientResponse(
      status: _failedImageUrls.contains(url) ? 503 : 200,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpClientResponse implements HttpClientResponse {
  _FakeHttpClientResponse({this.status = 200});
  final int status;
  static final Uint8List _png = Uint8List.fromList(const [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0A,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0x00,
    0x01,
    0x00,
    0x00,
    0x05,
    0x00,
    0x01,
    0x0D,
    0x0A,
    0x2D,
    0xB4,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ]);

  @override
  int get statusCode => status;

  @override
  int get contentLength => _png.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_png]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _UpscaleProgressClient extends _ProgressClient {
  final response = Completer<List<SuperResolutionJob>>();
  List<ImageItem> requested = [];
  @override
  Future<List<SuperResolutionJob>> requestSuperResolution(
    List<ImageItem> images,
  ) {
    requested = images;
    return response.future;
  }

  void complete() => response.complete(
    requested
        .map(
          (image) => SuperResolutionJob(
            key: '${'a' * 63}${image.id}',
            imageId: image.id,
            status: 'ready',
            url: 'http://example.com/enhanced-${image.id}.png',
          ),
        )
        .toList(),
  );
}
