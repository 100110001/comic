import 'dart:async';
import 'dart:io';

import 'package:comic/models/chapter.dart';
import 'package:comic/models/comic.dart';
import 'package:comic/models/image_item.dart';
import 'package:comic/providers/comics_providers.dart';
import 'package:comic/providers/reader_providers.dart';
import 'package:comic/providers/server_provider.dart';
import 'package:comic/screens/reader_screen.dart';
import 'package:comic/services/api_client.dart';
import 'package:comic/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = _FakeHttpOverrides();
  });

  // 固定 400x800 手机宽度；图片 800x1200 → 预估高度 600px。
  Future<void> pumpReader(WidgetTester tester, {int? initialPage}) async {
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
    const detail = ComicDetail(
      comic: Comic(id: 1, title: '测试漫画'),
      chapters: [Chapter(id: 1, title: '第1话', sortOrder: 0)],
      favorited: false,
      authorFavorited: false,
      progress: null,
    );

    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('移动端初始定位到指定页且滚动偏移与页码一致', (tester) async {
    await pumpReader(tester, initialPage: 5);

    expect(find.text('第 6 / 10 页'), findsOneWidget);
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
    await tester.pumpAndSettle();

    expect(find.text('第 2 / 10 页'), findsOneWidget);
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
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('下一本'));
      await tester.pumpAndSettle();
      // 在第二本翻到第 2 页，再切第三本。
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('下一本'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(client.positions, [
        (comicId: 1, chapterId: 10, pageNumber: 0),
        (comicId: 2, chapterId: 20, pageNumber: 1),
        (comicId: 3, chapterId: 30, pageNumber: 0),
      ]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
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
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeHttpClientRequest();

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
  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpClientResponse implements HttpClientResponse {
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
  int get statusCode => HttpStatus.ok;

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
