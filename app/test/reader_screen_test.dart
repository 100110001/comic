import 'package:comic/screens/settings_screen.dart';
import 'package:comic/platform.dart';
import 'package:comic/models/reading_progress_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:comic/models/image_resolution.dart';
import 'package:comic/providers/settings_provider.dart';
import 'dart:async';
import 'dart:io';

import 'package:comic/models/chapter.dart';
import 'package:comic/models/comic.dart';
import 'package:comic/models/image_item.dart';
import 'package:comic/models/super_resolution_job.dart';
import 'package:comic/providers/super_resolution_provider.dart';
import 'package:comic/widgets/enhanced_image.dart';
import 'package:comic/widgets/loading_placeholders.dart';
import 'package:comic/widgets/reader_progress_bar.dart';
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
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> settleReader(WidgetTester tester) async {
  // 布局与延迟图片可能跨帧挂载。先等待真实首帧，再等待有限过渡；
  // 不能让假时钟一直等待首帧前的循环加载动效。
  for (var pass = 0; pass < 10; pass++) {
    await tester.pump();
    await tester.runAsync(() async {
      for (final element
          in find.byType(Image, skipOffstage: false).evaluate()) {
        final image = element.widget as Image;
        await precacheImage(image.image, element, onError: (error, stack) {});
      }
    });
    await tester.pump(const Duration(milliseconds: 200));
    if (pass >= 2 &&
        find
            .byType(ImageLoadingPlaceholder, skipOffstage: false)
            .evaluate()
            .isEmpty) {
      break;
    }
  }
  await tester.pumpAndSettle();
}

final _imageRequests = <String, int>{};
final _failedImageUrls = <String>{};

Future<void> openReaderMenu(WidgetTester tester) async {
  if (find.text('阅读设置').evaluate().isNotEmpty) return;
  final context = tester.element(find.byType(ReaderScreen));
  if (isDesktopAt(MediaQuery.sizeOf(context).width)) {
    await tester.tapAt(const Offset(200, 200), buttons: kSecondaryMouseButton);
  } else {
    if (find.byTooltip('菜单').evaluate().isEmpty) {
      await tester.tapAt(const Offset(160, 260));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(const Offset(160, 260));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byTooltip('菜单'));
  }
  await tester.pumpAndSettle();
}

Future<void> openReaderSettings(WidgetTester tester) async {
  await openReaderMenu(tester);
}

ReadingProgressEntry positionOf(WidgetTester tester) =>
    ProviderScope.containerOf(
      tester.element(find.byType(ReaderScreen)),
    ).read(readingProgressQueueProvider).requireValue.first.entry;

void expectPage(WidgetTester tester, int page) =>
    expect(positionOf(tester).pageNumber, page - 1);
void expectChapter(WidgetTester tester, int chapter) =>
    expect(positionOf(tester).chapterId, chapter);

Future<void> selectReaderOption(WidgetTester tester, String option) async {
  await openReaderSettings(tester);
  await tester.pumpAndSettle();
  final choice = find.widgetWithText(ChoiceChip, option);
  await tester.ensureVisible(choice);
  await tester.pumpAndSettle();
  await tester.tap(choice);
  await settleReader(tester);
  await tester.tap(find.byTooltip('关闭阅读设置'));
  await settleReader(tester);
}

Future<void> selectReadingMode(WidgetTester tester, String mode) =>
    selectReaderOption(tester, mode);

void main() {
  setUpAll(() {
    HttpOverrides.global = _FakeHttpOverrides();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    _imageRequests.clear();
    _failedImageUrls.clear();
  });

  // 固定 400x800 手机宽度；图片 800x1200 → 预估高度 600px。
  Future<void> pumpReader(
    WidgetTester tester, {
    int? initialPage,
    int initialChapter = 1,
    Future<ComicDetail> Function()? loadDetail,
    double width = 400,
    List<Chapter>? chapters,
    Future<List<ImageItem>> Function(int)? loadImages,
    Future<Comic?> Function()? onNextComic,
    ApiClient? srClient,
    bool defaultUpscale = false,
    int pageCount = 10,
    double pixelRatio = 1,
    double textScale = 1,
    SuperResolutionMode? defaultMode,
    MemoryProgressStorage? progressStorage,
    bool routed = false,
    ReaderPreferences preferences = const ReaderPreferences(),
  }) async {
    final client = srClient ?? _ProgressClient();
    addTearDown(client.close);
    final images = List.generate(
      pageCount,
      (i) => ImageItem(
        id: i,
        filename: '$i.jpg',
        pageNumber: i,
        url: 'http://example.com/$i.jpg?v=1-1',
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

    tester.view.physicalSize = Size(width * pixelRatio, 800 * pixelRatio);
    tester.view.devicePixelRatio = pixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          readerPreferencesProvider.overrideWith(
            () => ReaderPreferencesNotifier(initial: preferences),
          ),
          superResolutionDefaultProvider.overrideWith(
            () => SuperResolutionDefaultNotifier(
              initial: defaultUpscale,
              initialMode: defaultMode,
            ),
          ),
          apiClientProvider.overrideWithValue(client),
          progressStorageProvider.overrideWithValue(
            progressStorage ?? MemoryProgressStorage(),
          ),
          serverSessionProvider.overrideWith(
            () => ServerSessionNotifier(initialUrl: 'http://example.com'),
          ),
          comicDetailProvider.overrideWithBuild(
            (ref, notifier) async =>
                loadDetail == null ? detail : await loadDetail(),
          ),
          chapterImagesProvider.overrideWith(
            (ref, id) async =>
                loadImages == null ? images : await loadImages(id),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: routed
              ? const Scaffold(body: Text('阅读入口'))
              : ReaderScreen(
                  comicId: 1,
                  chapterId: initialChapter,
                  title: '测试漫画',
                  initialPage: initialPage,
                  onNextComic: onNextComic,
                ),
        ),
      ),
    );
    if (routed) {
      unawaited(
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .push<void>(
              MaterialPageRoute(
                builder: (_) => ReaderScreen(
                  comicId: 1,
                  chapterId: initialChapter,
                  title: '测试漫画',
                  initialPage: initialPage,
                  onNextComic: onNextComic,
                ),
              ),
            ),
      );
    }
    await settleReader(tester);
  }

  testWidgets('手机连续跨章保留尾页并支持回滚和本章页码跳转', (tester) async {
    await pumpReader(
      tester,
      pageCount: 3,
      chapters: const [
        Chapter(id: 1, title: '第1话', sortOrder: 0),
        Chapter(id: 2, title: '第2话', sortOrder: 1),
        Chapter(id: 3, title: '第3话', sortOrder: 2),
      ],
    );
    final controller = tester
        .widget<ListView>(find.byType(ListView))
        .controller!;
    controller.jumpTo(1000);
    await settleReader(tester);
    expectChapter(tester, 1);
    expect(controller.offset, 1000);
    controller.jumpTo(1800);
    await settleReader(tester);
    expectChapter(tester, 2);
    expectPage(tester, 1);
    await openReaderMenu(tester);
    await tester.enterText(
      find.byKey(const ValueKey('reader-page-input')),
      '2',
    );
    await tester.tap(find.byTooltip('跳转到页码'));
    await settleReader(tester);
    expectChapter(tester, 2);
    expectPage(tester, 2);
    expect(controller.offset, closeTo(2400, 1));
    await tester.tap(find.byTooltip('关闭阅读设置'));
    await tester.pumpAndSettle();
    controller.jumpTo(0);
    await settleReader(tester);
    expectChapter(tester, 1);
    expectPage(tester, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '跨章后桌面与手机形态切换保持章内页码及连续位置',
    (tester) async {
      await pumpReader(
        tester,
        pageCount: 3,
        chapters: const [
          Chapter(id: 1, title: '第1话', sortOrder: 0),
          Chapter(id: 2, title: '第2话', sortOrder: 1),
        ],
        preferences: const ReaderPreferences(mode: ReaderMode.continuous),
      );
      var controller = tester
          .widget<ListView>(find.byType(ListView))
          .controller!;
      controller.jumpTo(1000);
      await settleReader(tester);
      controller.jumpTo(2400);
      await settleReader(tester);
      expectChapter(tester, 2);
      expectPage(tester, 2);
      tester.view.physicalSize = const Size(1200, 800);
      await settleReader(tester);
      expectChapter(tester, 2);
      expectPage(tester, 2);
      controller = tester.widget<ListView>(find.byType(ListView)).controller!;
      expect(controller.offset, closeTo(1440, 1));
      tester.view.physicalSize = const Size(400, 800);
      await settleReader(tester);
      expect(controller.offset, closeTo(2400, 1));
      tester.view.physicalSize = const Size(1200, 800);
      await settleReader(tester);
      await selectReadingMode(tester, '单页阅读');
      tester.view.physicalSize = const Size(400, 800);
      await settleReader(tester);
      expectChapter(tester, 2);
      expectPage(tester, 2);
      controller = tester.widget<ListView>(find.byType(ListView)).controller!;
      expect(controller.offset, closeTo(2400, 1));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('下一章失败保留当前正文和断点，重试可以衔接', (tester) async {
    var fail = true;
    await pumpReader(
      tester,
      chapters: const [
        Chapter(id: 1, title: '第1话', sortOrder: 0),
        Chapter(id: 2, title: '第2话', sortOrder: 1),
      ],
      loadImages: (id) async {
        if (id == 2 && fail) throw StateError('离线');
        return List.generate(
          3,
          (page) => ImageItem(
            id: id * 10 + page,
            filename: '$page.jpg',
            pageNumber: page,
            url: 'http://example.com/$id/$page.jpg',
            width: 800,
            height: 1200,
          ),
        );
      },
    );
    final controller = tester
        .widget<ListView>(find.byType(ListView))
        .controller!;
    controller.jumpTo(1000);
    await settleReader(tester);
    expectChapter(tester, 1);
    controller.jumpTo(controller.position.maxScrollExtent);
    await settleReader(tester);
    expect(find.text('下一章加载失败，点击重试'), findsOneWidget);
    fail = false;
    await tester.ensureVisible(find.text('下一章加载失败，点击重试'));
    await tester.tap(find.text('下一章加载失败，点击重试'));
    await tester.pump(const Duration(milliseconds: 350));
    await settleReader(tester);
    controller.jumpTo(1800);
    await settleReader(tester);
    expectChapter(tester, 2);
    expectPage(tester, 1);
  });

  testWidgets('目录恢复后当前图片仍归属于原章节', (tester) async {
    var ready = false;
    await pumpReader(
      tester,
      initialChapter: 2,
      loadDetail: () async {
        if (!ready) throw StateError('离线');
        return const ComicDetail(
          comic: Comic(id: 1, title: '测试漫画'),
          chapters: [
            Chapter(id: 1, title: '第一话', sortOrder: 0),
            Chapter(id: 2, title: '第二话', sortOrder: 1),
            Chapter(id: 3, title: '第三话', sortOrder: 2),
          ],
          favorited: false,
          authorFavorited: false,
        );
      },
    );
    ready = true;
    await openReaderMenu(tester);
    await tester.tap(find.text('章节目录'));
    await settleReader(tester);
    expect(find.text('共 3 章'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭目录'));
    await tester.pumpAndSettle();
    final controller = tester
        .widget<ListView>(find.byType(ListView))
        .controller!;
    controller.jumpTo(600);
    await settleReader(tester);
    expectChapter(tester, 2);
    expectPage(tester, 2);
  });

  for (final width in [320.0, 1200.0]) {
    testWidgets(
      '阅读面板外侧与关闭按钮只收起面板（$width）',
      (tester) async {
        await pumpReader(tester, width: width, initialPage: 2);
        await openReaderSettings(tester);
        await tester.tap(find.text('阅读设置'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('关闭阅读设置'), findsOneWidget);
        await tester.tapAt(const Offset(12, 12));
        await tester.pumpAndSettle();
        expect(find.byTooltip('关闭阅读设置'), findsNothing);
        expect(find.byType(ReaderScreen), findsOneWidget);
        expectPage(tester, 3);
        await openReaderSettings(tester);
        await tester.tap(find.byTooltip('关闭阅读设置'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('关闭阅读设置'), findsNothing);
        expectPage(tester, 3);
        expect(tester.takeException(), isNull);
      },
      variant: const TargetPlatformVariant({TargetPlatform.windows}),
    );
  }

  testWidgets('手机系统返回先关闭设置，全部分组展开且关闭入口固定', (tester) async {
    await pumpReader(tester, width: 320, textScale: 2);
    await openReaderSettings(tester);
    expect(find.text('图片信息'), findsOneWidget);
    expect(find.text('自动滚动／翻页'), findsOneWidget);
    expect(find.byTooltip('关闭阅读设置').hitTestable(), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ReaderScreen), findsOneWidget);
    expect(find.byTooltip('关闭阅读设置'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('手机目录可滚动换章并关闭面板', (tester) async {
    final chapters = List.generate(
      40,
      (i) => Chapter(id: i + 1, title: '第${i + 1}话', sortOrder: i),
    );
    await pumpReader(tester, width: 320, chapters: chapters);
    await openReaderMenu(tester);
    await tester.tap(find.text('章节目录'));
    await tester.pumpAndSettle();
    expect(find.text('共 40 章'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('第40话'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('第40话'));
    await settleReader(tester);
    expectChapter(tester, 40);
    expect(find.text('共 40 章'), findsNothing);
    await openReaderMenu(tester);
    await tester.tap(find.text('章节目录'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('关闭目录'));
    await tester.pumpAndSettle();
    expect(find.text('共 40 章'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('手机阅读背景与设置页双向同步且大字体可用', (tester) async {
    await pumpReader(tester, width: 320, textScale: 2);
    expect(tester.takeException(), isNull);
    expect(find.byType(PopupMenuButton<ReaderMode>), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    await selectReaderOption(tester, '护眼米色');
    expect(find.byType(ListView), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await settleReader(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ReaderScreen)),
    );
    expect((await loadReaderPreferences()).background, ReaderBackground.paper);
    final navigator = Navigator.of(tester.element(find.byType(ReaderScreen)));
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '护眼米色'))
          .selected,
      isTrue,
    );
    final gray = find.widgetWithText(ChoiceChip, '灰色');
    await tester.ensureVisible(gray);
    await tester.pumpAndSettle();
    await tester.tap(gray);
    await tester.pumpAndSettle();
    expect(
      container.read(readerPreferencesProvider).background,
      ReaderBackground.gray,
    );
    navigator.pop();
    await settleReader(tester);
    final scaffold = tester.widget<Scaffold>(
      find
          .descendant(
            of: find.byType(ReaderScreen),
            matching: find.byType(Scaffold),
          )
          .first,
    );
    expect(scaffold.backgroundColor, const Color(0xff35383d));
    await openReaderSettings(tester);
    await tester.pumpAndSettle();
    final grayInReader = find.widgetWithText(ChoiceChip, '灰色');
    await tester.ensureVisible(grayInReader);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(grayInReader).selected, isTrue);
    expect(find.byTooltip('关闭阅读设置').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('关闭阅读设置'));
    await settleReader(tester);
    expectPage(tester, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '双页 RTL 排序、奇数尾页和窄屏回退保留全局偏好与断点',
    (tester) async {
      await pumpReader(
        tester,
        width: 1200,
        pageCount: 5,
        preferences: const ReaderPreferences(
          mode: ReaderMode.doublePage,
          direction: ReadingDirection.rightToLeft,
          autoHide: false,
        ),
      );
      final first = find.byKey(const ValueKey('page-img-0-0'));
      final second = find.byKey(const ValueKey('page-img-1-0'));
      expect(
        tester.getTopLeft(second).dx,
        lessThan(tester.getTopLeft(first).dx),
      );
      expect(tester.getSize(first).width, 600);
      expect(
        (tester.widget<Image>(first).image as DisplaySizedNetworkImage).width,
        768,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await settleReader(tester);
      expectPage(tester, 3);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await settleReader(tester);
      final last = find.byKey(const ValueKey('page-img-4-0'));
      expect(tester.getTopLeft(last).dx, 600);
      expectPage(tester, 5);
      tester.view.physicalSize = const Size(400, 800);
      await settleReader(tester);
      expect(tester.getSize(find.byType(ListView)).width, 400);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ReaderScreen)),
      );
      expect(
        container.read(readerPreferencesProvider).mode,
        ReaderMode.doublePage,
      );
      expect(
        container
            .read(readingProgressQueueProvider)
            .requireValue
            .single
            .entry
            .pageNumber,
        4,
      );
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
  );

  testWidgets(
    '适应宽度先滚动图内长图，到底后滚轮才翻页',
    (tester) async {
      await pumpReader(
        tester,
        width: 1200,
        preferences: const ReaderPreferences(
          mode: ReaderMode.single,
          fit: ReaderFit.fitWidth,
          autoHide: false,
        ),
      );
      final image = find.byKey(const ValueKey('page-img-0-0'));
      final position = tester.getCenter(find.byType(EnhancedImage).first);
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: Offset(position.dx, 300),
          scrollDelta: const Offset(0, 100),
        ),
      );
      await settleReader(tester);
      expectPage(tester, 1);
      final scrollable = tester.state<ScrollableState>(
        find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
            )
            .first,
      );
      expect(scrollable.position.pixels, greaterThan(0));
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump();
      await tester.sendEventToBinding(
        const PointerScrollEvent(
          position: Offset(600, 300),
          scrollDelta: Offset(0, 100),
        ),
      );
      await settleReader(tester);
      expectPage(tester, 2);
      expect(image, findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
  );

  testWidgets('手机忽略旧分页偏好，双击控制层手动关闭且正文不常驻缩放工具', (tester) async {
    await pumpReader(
      tester,
      width: 320,
      preferences: const ReaderPreferences(mode: ReaderMode.single),
    );
    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(ReaderProgressBar), findsNothing);
    await openReaderMenu(tester);
    await tester.tap(find.byTooltip('关闭阅读设置'));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderProgressBar), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    expect(find.byTooltip('关闭控制层').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('关闭控制层'));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderProgressBar), findsNothing);
    await openReaderSettings(tester);
    expect(find.text('页面适配'), findsNothing);
    expect(find.text('阅读模式'), findsNothing);
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('手机默认连续阅读并提供全局阅读设置', (tester) async {
    await pumpReader(tester);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.byTooltip('阅读方式'), findsNothing);
    await openReaderMenu(tester);
    expect(find.text('阅读设置'), findsOneWidget);
  });

  testWidgets('连续缩放保留页内位置，恢复默认后仍能纵向滚动', (tester) async {
    await pumpReader(tester);
    final controller = tester
        .widget<ListView>(find.byType(ListView))
        .controller!;
    controller.jumpTo(1350); // 第三页的四分之一。
    await settleReader(tester);
    expectPage(tester, 3);
    await openReaderSettings(tester);
    tester.widget<Slider>(find.byKey(const ValueKey('reader-zoom'))).onChanged!(
      2,
    );
    await settleReader(tester);
    expect(controller.offset, closeTo(2700, 1));
    expect(tester.getSize(find.byType(ListView)).width, 800);
    expectPage(tester, 3);
    await tester.tap(find.text('恢复默认大小'));
    await settleReader(tester);
    expect(controller.offset, closeTo(1350, 1));
    await tester.tap(find.byTooltip('关闭阅读设置'));
    await settleReader(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await settleReader(tester);
    expect(controller.offset, greaterThan(1350));
  });

  testWidgets('双指缩放后可横向查看，松手后恢复纵向阅读', (tester) async {
    await pumpReader(tester);
    final controller = tester
        .widget<ListView>(find.byType(ListView))
        .controller!;
    controller.jumpTo(1350);
    await settleReader(tester);
    final first = await tester.startGesture(const Offset(120, 400), pointer: 1);
    final second = await tester.startGesture(
      const Offset(280, 400),
      pointer: 2,
    );
    await tester.pump();
    await first.moveTo(const Offset(40, 400));
    await second.moveTo(const Offset(360, 400));
    await tester.pump();
    await first.up();
    await second.up();
    await settleReader(tester);
    expect(tester.getSize(find.byType(ListView)).width, closeTo(800, 1));
    expect(controller.offset, closeTo(2700, 1));
    expectPage(tester, 3);
    final horizontal = tester.widget<SingleChildScrollView>(
      find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      ),
    );
    final horizontalOffset = horizontal.controller!.offset;
    await tester.dragFrom(const Offset(200, 400), const Offset(-150, 0));
    await settleReader(tester);
    expect(horizontal.controller!.offset, greaterThan(horizontalOffset));
    expect(controller.offset, closeTo(2700, 1));
    expectPage(tester, 3);
    await tester.dragFrom(const Offset(200, 400), const Offset(0, -300));
    await settleReader(tester);
    expect(controller.offset, greaterThan(2700));
  });

  testWidgets('错误尺寸的初始跳页在解码校正后仍保持目标页', (tester) async {
    await pumpReader(
      tester,
      initialPage: 4,
      loadImages: (id) async => List.generate(
        10,
        (i) => ImageItem(
          id: i,
          filename: '$i.jpg',
          pageNumber: i,
          url: 'http://example.com/$i.jpg?v=1-1',
          width: 800,
          height: 2400,
        ),
      ),
    );
    expectPage(tester, 5);
    final controller = tester
        .widget<ListView>(find.byType(ListView))
        .controller!;
    final displayed = tester.widgetList<Image>(find.byType(Image)).toList();
    for (final image in displayed) {
      expect(tester.getSize(find.byWidget(image)).height, closeTo(600, 1));
    }
    await openReaderSettings(tester);
    tester.widget<ReaderProgressBar>(find.byType(ReaderProgressBar)).onSeek(4);
    await settleReader(tester);
    expectPage(tester, 5);
    expect(controller.offset, greaterThan(0));
  });

  testWidgets(
    '放大后桌面支持鼠标横向拖动且不改变页码',
    (tester) async {
      await pumpReader(
        tester,
        width: 1200,
        preferences: const ReaderPreferences(mode: ReaderMode.continuous),
      );
      await openReaderSettings(tester);
      tester
          .widget<Slider>(find.byKey(const ValueKey('reader-zoom')))
          .onChanged!(2);
      await settleReader(tester);
      await tester.tap(find.byTooltip('关闭阅读设置'));
      await settleReader(tester);
      final horizontal = tester.widget<SingleChildScrollView>(
        find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal,
        ),
      );
      final before = horizontal.controller!.offset;
      final pointer = await tester.startGesture(
        const Offset(600, 400),
        kind: PointerDeviceKind.mouse,
      );
      await pointer.moveBy(const Offset(-50, 0));
      await tester.pump();
      await pointer.moveBy(const Offset(-100, 0));
      await pointer.up();
      await settleReader(tester);
      expect(horizontal.controller!.offset, greaterThan(before));
      expectPage(tester, 1);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('未知及错误图片尺寸按解码比例衔接，不留下预估空白', (tester) async {
    await pumpReader(
      tester,
      loadImages: (id) async => List.generate(
        10,
        (i) => ImageItem(
          id: i,
          filename: '$i.jpg',
          pageNumber: i,
          url: 'http://example.com/$i.jpg?v=1-1',
          width: i == 0 ? null : 800,
          height: i == 0 ? null : 2400,
        ),
      ),
    );
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images.length, greaterThanOrEqualTo(2));
    expect(tester.getSize(find.byWidget(images[0])).height, closeTo(600, 1));
    expect(tester.getSize(find.byWidget(images[1])).height, closeTo(600, 1));
    expect(
      tester.getTopLeft(find.byWidget(images[1])).dy,
      closeTo(tester.getBottomLeft(find.byWidget(images[0])).dy, 1),
    );
    expectPage(tester, 1);
  });

  testWidgets(
    '桌面 Ctrl 滚轮缩放保持页内位置且不滚动或续章',
    (tester) async {
      await pumpReader(
        tester,
        width: 1200,
        preferences: const ReaderPreferences(mode: ReaderMode.continuous),
      );
      final controller = tester
          .widget<ListView>(find.byType(ListView))
          .controller!;
      controller.jumpTo(1600);
      await settleReader(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendEventToBinding(
        const PointerScrollEvent(
          position: Offset(400, 400),
          scrollDelta: Offset(0, -120),
        ),
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settleReader(tester);
      final width = tester.getSize(find.byType(ListView)).width;
      expect(width, greaterThan(960));
      expect(controller.offset, closeTo(1600 * width / 960, 1));
      expectPage(tester, 2);
      expectChapter(tester, 1);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    '桌面模式切换保留页码，连续滚动与键盘跳转同步本机断点',
    (tester) async {
      await pumpReader(tester, width: 1200, initialPage: 2);
      expect(find.byType(ListView), findsNothing);
      await selectReadingMode(tester, '连续阅读');
      final list = tester.widget<ListView>(find.byType(ListView));
      expect(tester.getSize(find.byType(ListView)).width, 960);
      expect(list.controller!.offset, closeTo(2 * 1440, 1));
      expectPage(tester, 3);
      list.controller!.jumpTo(3 * 1440);
      await settleReader(tester);
      expectPage(tester, 4);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settleReader(tester);
      expect(list.controller!.offset, closeTo(4 * 1440, 1));
      expectPage(tester, 5);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ReaderScreen)),
      );
      expect(
        container
            .read(readingProgressQueueProvider)
            .requireValue
            .single
            .entry
            .pageNumber,
        4,
      );
      await selectReadingMode(tester, '单页阅读');
      expect(find.byType(ListView), findsNothing);
      expectPage(tester, 5);
      await selectReadingMode(tester, '连续阅读');
      expect(
        tester.widget<ListView>(find.byType(ListView)).controller!.offset,
        closeTo(4 * 1440, 1),
      );
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
  );

  testWidgets(
    '连续模式窗口缩放与末页跳转保留章节，滚动到底后才续章',
    (tester) async {
      await pumpReader(
        tester,
        width: 1200,
        initialPage: 2,
        chapters: [
          const Chapter(id: 1, title: '第1话', sortOrder: 0),
          const Chapter(id: 2, title: '第2话', sortOrder: 1),
        ],
      );
      await selectReadingMode(tester, '连续阅读');
      tester.view.physicalSize = const Size(800, 800);
      await settleReader(tester);
      expect(
        tester.widget<ListView>(find.byType(ListView)).controller!.offset,
        closeTo(2 * 1200, 1),
      );
      expectPage(tester, 3);
      await openReaderMenu(tester);
      tester
          .widget<ReaderProgressBar>(find.byType(ReaderProgressBar))
          .onSeek(9);
      await tester.tap(find.byTooltip('关闭阅读设置'));
      await settleReader(tester);
      expectChapter(tester, 1);
      expectPage(tester, 10);
      tester.view.physicalSize = const Size(800, 2000);
      await settleReader(tester);
      expectChapter(tester, 1);
      expectPage(tester, 10);
      tester.view.physicalSize = const Size(800, 800);
      await settleReader(tester);
      final list = tester.widget<ListView>(find.byType(ListView));
      list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
      await settleReader(tester);
      expectChapter(tester, 2);
      expectPage(tester, 1);
      expect(
        tester.widget<ListView>(find.byType(ListView)).controller!.offset,
        0,
      );
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
  );

  testWidgets(
    '桌面连续模式超分以阅读宽度判定且隐藏进度条不改变布局',
    (tester) async {
      final client = _UpscaleProgressClient();
      await pumpReader(
        tester,
        width: 1200,
        initialPage: 2,
        srClient: client,
        defaultMode: SuperResolutionMode.adaptive,
      );
      expect(client.requested, isEmpty);
      await selectReadingMode(tester, '连续阅读');
      expect(client.requested.first.id, 2);
      final list = tester.widget<ListView>(find.byType(ListView));
      final offset = list.controller!.offset;
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(ReaderProgressBar), findsNothing);
      await openReaderMenu(tester);
      expect(find.byType(ReaderProgressBar), findsOneWidget);
      await tester.tap(find.byTooltip('关闭阅读设置'));
      await tester.pumpAndSettle();
      expect(list.controller!.offset, offset);
      client.complete();
      await settleReader(tester);
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
  );

  testWidgets(
    '桌面连续阅读短章节滚轮到底可续章，模式切换本身不续章',
    (tester) async {
      await pumpReader(
        tester,
        width: 1200,
        pageCount: 1,
        chapters: [
          const Chapter(id: 1, title: '第1话', sortOrder: 0),
          const Chapter(id: 2, title: '第2话', sortOrder: 1),
        ],
      );
      tester.view.physicalSize = const Size(1200, 2000);
      await settleReader(tester);
      await selectReadingMode(tester, '连续阅读');
      expectChapter(tester, 1);
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(find.byType(ListView)),
          scrollDelta: const Offset(0, 100),
        ),
      );
      await settleReader(tester);
      expectChapter(tester, 2);
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
  );

  testWidgets('未知尺寸按窗口补齐后自动超分，正文高度和断点保持稳定', (tester) async {
    final client = _DimensionProgressClient();
    final image = ImageItem(
      id: 20,
      filename: '20.jpg',
      pageNumber: 0,
      url: 'http://example.com/20.jpg?v=1-2.5-3.5',
    );
    await pumpReader(
      tester,
      srClient: client,
      defaultMode: SuperResolutionMode.adaptive,
      loadImages: (_) async => [image],
    );
    final before = tester.getSize(find.byType(EnhancedImage).first);
    final position = positionOf(tester);
    expect(client.dimensionIds, [20]);
    expect(client.requested, isEmpty);
    client.dimensions.complete([
      ImageItem(
        id: 20,
        filename: '20.jpg',
        pageNumber: 0,
        url: image.url,
        width: 200,
        height: 300,
      ),
    ]);
    await settleReader(tester);
    expect(client.requested.map((item) => item.id), [20]);
    expect(tester.getSize(find.byType(EnhancedImage).first), before);
    expect(positionOf(tester).pageNumber, position.pageNumber);
    await openReaderSettings(tester);
    expect(find.textContaining('200 × 300'), findsOneWidget);
  });

  testWidgets('自适应随 DPR 改变重判，即使原图解码缓存尺寸没有改变', (tester) async {
    final client = _UpscaleProgressClient();
    await pumpReader(
      tester,
      initialPage: 2,
      pixelRatio: 2,
      srClient: client,
      defaultMode: SuperResolutionMode.adaptive,
    );
    expect(client.requested, isEmpty);
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(ReaderScreen)),
      ).read(superResolutionProvider).reasons.values,
      contains('原图分辨率足够，已跳过'),
    );
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 3;
    await settleReader(tester);
    expect(
      client.requested.map((image) => image.id),
      List.generate(8, (index) => index + 2),
    );
  });

  testWidgets(
    '桌面自适应以 contain 后实际显示宽度判断长图',
    (tester) async {
      final client = _UpscaleProgressClient();
      await pumpReader(
        tester,
        width: 1200,
        srClient: client,
        defaultMode: SuperResolutionMode.adaptive,
      );
      expect(client.requested, isEmpty);
      expect(
        ProviderScope.containerOf(
          tester.element(find.byType(ReaderScreen)),
        ).read(superResolutionProvider).reasons.values,
        contains('原图分辨率足够，已跳过'),
      );
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
  );

  testWidgets('缺失原图不阻断其它页增强，保留原窗口优先级和页码', (tester) async {
    final client = _UpscaleProgressClient();
    await pumpReader(
      tester,
      srClient: client,
      defaultUpscale: true,
      loadImages: (_) async => List.generate(
        3,
        (index) => ImageItem(
          id: index,
          filename: '$index.jpg',
          pageNumber: index,
          url: 'http://example.com/$index.jpg${index == 0 ? '' : '?v=1-1'}',
          width: 800,
          height: 1200,
        ),
      ),
    );
    expect(client.requested.map((image) => image.id), [1, 2]);
    expect(client.requestedPriorities, {1: 1, 2: 2});
    final state = ProviderScope.containerOf(
      tester.element(find.byType(ReaderScreen)),
    ).read(superResolutionProvider);
    expect(state.results['http://example.com/0.jpg']?.status, 'failed');
    expectPage(tester, 1);
  });

  testWidgets('全局开启后预处理当前及后十页，阅读器关闭同步全局策略', (tester) async {
    final client = _UpscaleProgressClient();
    await pumpReader(
      tester,
      initialPage: 2,
      srClient: client,
      defaultUpscale: true,
      pageCount: 100,
    );
    expect(
      client.requested.map((image) => image.id),
      List.generate(11, (index) => index + 2),
    );
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(ReaderScreen)),
      ).read(superResolutionProvider).enabled,
      isTrue,
    );
    expect(find.text('2× 超分'), findsNothing);
    await selectReaderOption(tester, '关闭');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ReaderScreen)),
    );
    expect(
      container.read(superResolutionDefaultProvider),
      SuperResolutionMode.off,
    );
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(ReaderScreen)),
      ).read(superResolutionProvider).enabled,
      isFalse,
    );
    client.complete();
    await settleReader(tester);
    expect(find.text('2× 超分'), findsNothing);
  });

  testWidgets(
    '换书前本机写入失败保留当前漫画，恢复后可重试',
    (tester) async {
      final storage = MemoryProgressStorage();
      var calls = 0;
      await pumpReader(
        tester,
        width: 1200,
        progressStorage: storage,
        onNextComic: () async {
          calls++;
          return null;
        },
      );
      storage.failWrite = true;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settleReader(tester);
      await openReaderMenu(tester);
      await tester.tap(find.text('下一本'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(find.text('阅读进度无法保存在本机，请重试'), findsOneWidget);
      storage.failWrite = false;
      await openReaderMenu(tester);
      await tester.tap(find.text('下一本'));
      await tester.pumpAndSettle();
      expect(calls, 1);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    '路由返回先关面板，保存失败不退出，恢复后只补传一次',
    (tester) async {
      final storage = MemoryProgressStorage();
      final client = _ProgressClient();
      await pumpReader(
        tester,
        width: 1200,
        progressStorage: storage,
        srClient: client,
        routed: true,
      );
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      await openReaderMenu(tester);
      await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('阅读设置'), findsNothing);
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(client.positions, isEmpty);
      storage.failWrite = true;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settleReader(tester);
      await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(client.positions, isEmpty);
      storage.failWrite = false;
      await navigator.maybePop();
      await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(find.byType(ReaderScreen), findsNothing);
      expect(find.text('阅读入口'), findsOneWidget);
      expect(client.positions, [(comicId: 1, chapterId: 1, pageNumber: 1)]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'iOS 边缘返回先关面板，保存失败保留阅读器并可重试',
    (tester) async {
      final storage = MemoryProgressStorage()..failWrite = true;
      final client = _ProgressClient();
      await pumpReader(
        tester,
        progressStorage: storage,
        srClient: client,
        routed: true,
      );
      await tester.dragFrom(const Offset(100, 300), const Offset(150, 0));
      await settleReader(tester);
      expect(find.byType(ReaderScreen), findsOneWidget);
      await tester.dragFrom(const Offset(8, 400), const Offset(0, -150));
      await settleReader(tester);
      expect(find.byType(ReaderScreen), findsOneWidget);
      await openReaderMenu(tester);
      tester
          .widget<Slider>(find.byKey(const ValueKey('reader-zoom')))
          .onChanged!(2);
      await settleReader(tester);
      await tester.dragFrom(const Offset(8, 100), const Offset(150, 0));
      await settleReader(tester);
      expect(find.text('阅读设置'), findsNothing);
      expect(find.byType(ReaderScreen), findsOneWidget);
      await tester.dragFrom(const Offset(8, 300), const Offset(150, 0));
      await settleReader(tester);
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(client.positions, isEmpty);
      storage.failWrite = false;
      await tester.dragFrom(const Offset(8, 300), const Offset(150, 0));
      await tester.pumpAndSettle();
      expect(find.byType(ReaderScreen), findsNothing);
      expect(find.text('阅读入口'), findsOneWidget);
      expect(client.positions, hasLength(1));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  for (final action in ['快捷键', '滚轮', '拖动']) {
    testWidgets(
      '分页自动阅读遇到人工$action停止',
      (tester) async {
        await pumpReader(tester, width: 1200);
        await openReaderMenu(tester);
        final start = find.text('开始自动阅读');
        await tester.ensureVisible(start);
        await tester.tap(start);
        await tester.pump();
        expect(find.text('停止自动阅读'), findsOneWidget);
        switch (action) {
          case '快捷键':
            await tester.sendKeyEvent(LogicalKeyboardKey.end);
          case '滚轮':
            await tester.sendEventToBinding(
              const PointerScrollEvent(
                position: Offset(400, 300),
                scrollDelta: Offset(0, 50),
              ),
            );
          case '拖动':
            await tester.fling(
              find.byType(ReaderScreen),
              const Offset(-300, 0),
              1000,
            );
        }
        await tester.pump();
        expect(find.text('停止自动阅读'), findsNothing);
        final page = positionOf(tester).pageNumber;
        await tester.pump(const Duration(seconds: 6));
        expect(positionOf(tester).pageNumber, page);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets('换书请求失败后恢复按钮并可再次请求', (tester) async {
    var calls = 0;
    await pumpReader(
      tester,
      onNextComic: () async {
        calls++;
        if (calls == 1) throw Exception('续页失败');
        return null;
      },
    );
    await openReaderMenu(tester);
    await tester.tap(find.text('下一本'));
    await settleReader(tester);
    expect(calls, 1);
    expect(tester.takeException(), isNull);
    await openReaderMenu(tester);
    await tester.tap(find.text('下一本'));
    await settleReader(tester);
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320px 连续阅读器只有一个阅读设置入口且不溢出', (tester) async {
    await pumpReader(tester, width: 320, onNextComic: () async => null);
    expect(tester.takeException(), isNull);
    await openReaderMenu(tester);
    expect(find.text('阅读设置'), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });

  testWidgets('超分先保留原图，结果就绪和关闭均不改变手机阅读位置', (tester) async {
    final client = _UpscaleProgressClient();
    await pumpReader(tester, initialPage: 2, srClient: client);
    final list = tester.widget<ListView>(find.byType(ListView));
    final offset = list.controller!.offset;
    expect(client.requested, isEmpty);
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(ReaderScreen)),
      ).read(superResolutionProvider).enabled,
      isFalse,
    );
    expect(find.text('2× 超分'), findsNothing);
    await selectReaderOption(tester, '开启');
    expect(
      client.requested.map((image) => image.id),
      List.generate(8, (index) => index + 2),
    );
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(ReaderScreen)),
      ).read(superResolutionProvider).enabled,
      isTrue,
    );
    expect(find.text('2× 超分'), findsNothing);
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
    expectPage(tester, 3);
    expect(
      ProviderScope.containerOf(tester.element(find.byType(ReaderScreen)))
          .read(superResolutionProvider)
          .results
          .values
          .any((job) => job.status == 'ready'),
      isTrue,
    );
    expect(find.text('2× 超分'), findsWidgets);
    await selectReaderOption(tester, '关闭');
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
    await selectReaderOption(tester, '开启');
    client.complete();
    await settleReader(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ReaderScreen)),
    );
    expect(
      container
          .read(superResolutionProvider)
          .results['http://example.com/2.jpg?v=1-1']!
          .status,
      'failed',
    );
    expect(find.text('点击重试'), findsNothing);
    expectPage(tester, 3);
    expect(
      container
          .read(superResolutionProvider)
          .results
          .values
          .any((job) => job.status == 'failed'),
      isTrue,
    );
    expect(_imageRequests['http://example.com/2.jpg?v=1-1'], 1);
  });

  testWidgets('移动端初始定位到指定页且滚动偏移与页码一致', (tester) async {
    await pumpReader(tester, initialPage: 5);

    expectPage(tester, 6);
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
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
        ),
      ),
    );
    // 第 5 页（0 起始）的顶部偏移 = 5 × 600
    expect(scrollable.position.pixels, closeTo(5 * 600, 1));
  });

  testWidgets('连续页码定位保留页顶容差并支持向前及向后跳跃', (tester) async {
    await pumpReader(tester);
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(ReaderScreen),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
        ),
      ),
    );
    for (final (offset, page) in [
      (598.0, 1),
      (599.0, 2),
      (600.0, 2),
      (3000.0, 6),
      (1799.0, 4),
      (0.0, 1),
    ]) {
      scrollable.position.jumpTo(offset);
      await settleReader(tester);
      expectPage(tester, page);
    }
  });

  testWidgets('移动端滚动一页后页码更新', (tester) async {
    await pumpReader(tester);
    expectPage(tester, 1);

    await tester.drag(find.byType(ListView), const Offset(0, -620));
    await settleReader(tester);

    expectPage(tester, 2);
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
    '连续换书与返回保存当前漫画的章节和页码',
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
            comicDetailProvider.overrideWithBuild(
              (ref, notifier) async => ComicDetail(
                comic: Comic(
                  id: notifier.comicId,
                  title: '漫画${notifier.comicId}',
                ),
                chapters: [
                  Chapter(
                    id: notifier.comicId * 10,
                    title: '章节${notifier.comicId}',
                    sortOrder: 0,
                  ),
                ],
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
      await openReaderMenu(tester);
      await tester.tap(find.text('下一本'));
      await settleReader(tester);
      // 在第二本翻到第 2 页，再切第三本。
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settleReader(tester);
      await openReaderMenu(tester);
      await tester.tap(find.text('下一本'));
      await settleReader(tester);
      await openReaderSettings(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settleReader(tester);
      expect(find.byType(ReaderScreen), findsNothing);
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
      expectChapter(tester, 1);
      expectPage(tester, 5);
      await press(LogicalKeyboardKey.pageDown);
      expectChapter(tester, 2);
      expectPage(tester, 1);
      final entry = container
          .read(readingProgressQueueProvider)
          .requireValue
          .single
          .entry;
      expect(entry.chapterId, 2);
      expect(entry.pageNumber, 0);

      await press(LogicalKeyboardKey.arrowRight);
      expectPage(tester, 2);
      await openReaderMenu(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(ReaderProgressBar),
          matching: find.byType(Slider),
        ),
      );
      await tester.tap(find.byTooltip('关闭阅读设置'));
      await settleReader(tester);
      await press(LogicalKeyboardKey.pageUp);
      expectChapter(tester, 1);
      expectPage(tester, 1);
      await press(LogicalKeyboardKey.pageDown);
      await press(LogicalKeyboardKey.pageDown);
      expectChapter(tester, 3);
      await press(LogicalKeyboardKey.end);
      expectPage(tester, 10);
      await press(LogicalKeyboardKey.pageDown);
      expectChapter(tester, 3);
      expectPage(tester, 10);
      expect(nextComicCalls, 0);
      await press(LogicalKeyboardKey.home);
      await press(LogicalKeyboardKey.space);
      expectPage(tester, 2);
      await press(LogicalKeyboardKey.arrowLeft);
      expectPage(tester, 1);
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
        expectPage(tester, 5);
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    '桌面显示命中相邻预加载尺寸缓存，同档窗口调整复用',
    (tester) async {
      await pumpReader(tester, width: 1200);
      const url = 'http://example.com/0.jpg?v=1-1';
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
      expect(_imageRequests['http://example.com/1.jpg?v=1-1'], 1);
      expect(_imageRequests['http://example.com/2.jpg?v=1-1'], 1);
      expect(_imageRequests['http://example.com/3.jpg?v=1-1'], isNull);
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
      expect(_imageRequests['http://example.com/1.jpg?v=1-1'], 1);
      expectPage(tester, 2);
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
      expectPage(tester, 2);
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
      expectPage(tester, 2);
      tester.view.physicalSize = const Size(1100, 800);
      await settleReader(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settleReader(tester);
      tester.view.physicalSize = const Size(400, 800);
      await settleReader(tester);
      expectPage(tester, 3);
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
        const url = 'http://example.com/0.jpg?v=1-1';
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
        await tester.pump(const Duration(milliseconds: 350));
        await settleReader(tester);
        expect(_imageRequests[url], before + 1);
        expect(find.text('点击重试'), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
}

class _ProgressClient extends ApiClient {
  @override
  Future<int> getSuperResolutionLookahead() async => 10;
  @override
  Future<List<ImageResolution>> resolveImages(
    List<ImageItem> images, {
    required bool upscale,
    Map<int, int>? priorities,
  }) async => images
      .map(
        (image) => ImageResolution(imageId: image.id, originalUrl: image.url),
      )
      .toList();

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
  // 与常规章节元数据保持相同比例，尺寸校正另用不匹配的元数据覆盖。
  static final Uint8List _png = Uint8List.fromList([
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
    0,
    0,
    0,
    13,
    73,
    72,
    68,
    82,
    0,
    0,
    0,
    8,
    0,
    0,
    0,
    12,
    8,
    6,
    0,
    0,
    0,
    95,
    158,
    252,
    157,
    0,
    0,
    0,
    14,
    73,
    68,
    65,
    84,
    120,
    156,
    99,
    96,
    24,
    5,
    131,
    5,
    0,
    0,
    1,
    140,
    0,
    1,
    1,
    39,
    32,
    158,
    0,
    0,
    0,
    0,
    73,
    69,
    78,
    68,
    174,
    66,
    96,
    130,
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
  Map<int, int>? requestedPriorities;
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
    requested = images;
    requestedPriorities = priorities;
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

class _DimensionProgressClient extends _UpscaleProgressClient {
  final dimensions = Completer<List<ImageItem>>();
  List<int>? dimensionIds;
  @override
  Future<List<ImageItem>> getChapterImages(
    int chapterId, {
    List<int>? dimensions,
  }) {
    dimensionIds = dimensions;
    return this.dimensions.future;
  }
}
