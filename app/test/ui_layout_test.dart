import 'package:comic/providers/discovery_providers.dart';
import 'package:comic/screens/discovery_screen.dart';
import 'package:comic/widgets/reading_lists.dart';
import 'package:comic/models/chapter.dart';
import 'package:comic/models/comic.dart';
import 'package:comic/models/reading_progress_entry.dart';
import 'package:comic/providers/comics_providers.dart';
import 'package:comic/providers/reader_providers.dart';
import 'package:comic/providers/reading_progress_provider.dart';
import 'helpers/progress_storage.dart';
import 'package:comic/screens/detail_screen.dart';
import 'package:comic/screens/home_screen.dart';
import 'package:comic/screens/settings_screen.dart';
import 'package:comic/screens/reader_screen.dart';
import 'package:comic/theme.dart';
import 'package:comic/widgets/comic_grid.dart';
import 'package:comic/widgets/comic_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PreviewLibrary extends RandomLibraryNotifier {
  @override
  Future<RandomLibraryState> build() async => const RandomLibraryState(
    seed: 1,
    pageOffset: 1,
    total: 6,
    pageSize: 12,
    comics: [
      Comic(id: 1, title: '测试漫画'),
      Comic(id: 2, title: '第二本'),
      Comic(id: 3, title: '第三本'),
      Comic(id: 4, title: '第四本'),
      Comic(id: 5, title: '第五本'),
      Comic(id: 6, title: '第六本'),
    ],
  );
}

class _PreviewDiscovery extends DiscoveryNotifier {
  @override
  Future<DiscoveryState> build() async => const DiscoveryState(
    seed: 1,
    pageOffset: 1,
    total: 3,
    pageSize: 30,
    index: 1,
    comics: [
      Comic(id: 1, title: '第一本'),
      Comic(id: 2, title: '很长的漫画标题需要在矮窗口里完整保持阅读入口', author: '测试作者'),
      Comic(id: 3, title: '第三本'),
    ],
  );
}

void main() {
  testWidgets('发现三卡在窄矮窗口与大字体下可滚动且保留拖拽切换', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final size in [const Size(320, 360), const Size(760, 320)]) {
      tester.view.physicalSize = size;
      final container = ProviderContainer(
        overrides: [discoveryProvider.overrideWith(_PreviewDiscovery.new)],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(Brightness.dark),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(2),
              ),
              child: Row(
                children: [
                  if (size.width > 720) const SizedBox(width: 196),
                  const Expanded(child: DiscoveryScreen()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('换一批').hitTestable(), findsOneWidget);
      final current = find.byWidgetPredicate(
        (w) => w is GestureDetector && w.onHorizontalDragStart != null,
      );
      await tester.ensureVisible(current);
      await tester.drag(current, const Offset(-140, 0));
      await tester.pumpAndSettle();
      expect(container.read(discoveryProvider).value?.current?.id, 3);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    }
  });

  testWidgets('书库行在 320px 和双倍字体下保留长标题、阅读位置与详情入口', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressStorageProvider.overrideWithValue(MemoryProgressStorage()),
          recentReadingProvider.overrideWith(
            (ref) async => const [
              ReadingProgressEntry(
                comic: Comic(
                  id: 1,
                  title: '需要两行显示的很长漫画标题还有更多文字',
                  author: '很长很长的作者名字',
                ),
                chapterId: 10,
                chapterTitle: '很长很长的章节名称',
                pageNumber: 3,
              ),
            ],
          ),
          comicDetailProvider.overrideWith(
            (ref, id) async => const ComicDetail(
              comic: Comic(id: 1, title: '漫画详情'),
              chapters: [],
              favorited: false,
              authorFavorited: false,
            ),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(320, 700),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(body: RecentReadingList()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('很长很长的章节名称 · 第4页'), findsOneWidget);
    await tester.tap(find.text('需要两行显示的很长漫画标题还有更多文字'));
    await tester.pumpAndSettle();
    expect(find.byType(DetailScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320px 手机首页放大字体后仍能使用刷新和续读', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressStorageProvider.overrideWithValue(MemoryProgressStorage()),
          randomLibraryProvider.overrideWith(_PreviewLibrary.new),
          recentReadingProvider.overrideWith(
            (ref) async => const [
              ReadingProgressEntry(
                comic: Comic(id: 1, title: '测试漫画'),
                chapterId: 10,
                chapterTitle: '第一话名字很长也需要正确截断',
                pageNumber: 2,
              ),
            ],
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(2),
            ),
            child: HomeScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('换一批').hitTestable(), findsOneWidget);
    expect(find.text('继续阅读').hitTestable(), findsOneWidget);
    expect(comicGridColumns(320), 2);
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final bar = find
        .ancestor(of: find.text('继续阅读'), matching: find.byType(Material))
        .first;
    expect(
      tester.getBottomRight(find.byType(ComicCard).last).dy,
      lessThanOrEqualTo(tester.getTopLeft(bar).dy),
    );
  });

  testWidgets('手机设置的主题选项在放大字体时自动换行', (tester) async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Comic',
      packageName: 'comic',
      version: '1.0.3',
      buildNumber: '1',
      buildSignature: '',
    );
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(320, 700),
              textScaler: TextScaler.linear(2),
            ),
            child: SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('跟随系统'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('跟随系统'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('超分默认策略'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, '开启'));
    await tester.tap(find.widgetWithText(ChoiceChip, '开启'));
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getString('superResolutionMode'),
      'on',
    );
  });

  testWidgets('小屏和放大字体下单行标题与作者不溢出', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 390.0, 600.0, 950.0]) {
      tester.view.physicalSize = Size(width, 800);
      for (final scale in [1.0, 1.3, 2.0]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(Brightness.light),
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 800),
                textScaler: TextScaler.linear(scale),
              ),
              child: const Scaffold(
                body: ComicGrid(
                  comics: [
                    Comic(
                      id: 1,
                      title: '这是一个仅显示单行而且可能被截断的漫画标题',
                      author: '很长很长的作者名称',
                    ),
                    Comic(id: 2, title: '没有作者的漫画'),
                    Comic(id: 3, title: '收藏漫画', favorited: true),
                  ],
                  loading: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '宽度 $width，字体 $scale');
        final title = tester.widget<Text>(find.text('这是一个仅显示单行而且可能被截断的漫画标题'));
        expect(title.maxLines, 1);
        expect(title.overflow, TextOverflow.ellipsis);
        expect(find.byTooltip('这是一个仅显示单行而且可能被截断的漫画标题'), findsOneWidget);
      }
    }
  });

  testWidgets('窄屏详情可滚动到末章且首次阅读进入首章节', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final chapters = List.generate(
      100,
      (i) => Chapter(id: i + 10, title: '第${i + 1}话', sortOrder: i),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressStorageProvider.overrideWithValue(MemoryProgressStorage()),
          comicDetailProvider.overrideWith(
            (ref, id) async => ComicDetail(
              comic: const Comic(
                id: 1,
                title: '很长的漫画标题也不应该让章节目录消失',
                author: '测试作者',
              ),
              chapters: chapters,
              favorited: false,
              authorFavorited: false,
            ),
          ),
          chapterImagesProvider.overrideWith((ref, id) async => []),
        ],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.dark),
          home: const DetailScreen(comicId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('第100话'), 500, maxScrolls: 30);
    expect(find.text('第100话').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('开始阅读'), -500, maxScrolls: 30);
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始阅读'));
    await tester.pumpAndSettle();
    final reader = tester.widget<ReaderScreen>(find.byType(ReaderScreen));
    expect(reader.chapterId, 10);
    expect(reader.initialPage, 0);
  });

  testWidgets('空章节详情禁用首次阅读按钮', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressStorageProvider.overrideWithValue(MemoryProgressStorage()),
          comicDetailProvider.overrideWith(
            (ref, id) async => const ComicDetail(
              comic: Comic(id: 1, title: '暂无章节的漫画'),
              chapters: [],
              favorited: false,
              authorFavorited: false,
            ),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: const DetailScreen(comicId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.byWidgetPredicate((widget) => widget is FilledButton),
    );
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  for (final validChapter in [true, false]) {
    testWidgets('详情续读${validChapter ? '优先本机位置' : '失效本机章节回退远端'}', (
      tester,
    ) async {
      final c = ProviderContainer(
        overrides: [
          progressStorageProvider.overrideWithValue(MemoryProgressStorage()),
          comicDetailProvider.overrideWith(
            (ref, id) async => const ComicDetail(
              comic: Comic(id: 1, title: '测试漫画'),
              chapters: [Chapter(id: 10, title: '第一话', sortOrder: 0)],
              favorited: false,
              authorFavorited: false,
              progress: (chapterId: 10, pageNumber: 3),
            ),
          ),
          chapterImagesProvider.overrideWith((ref, id) async => []),
        ],
      );
      addTearDown(c.dispose);
      await c
          .read(readingProgressQueueProvider.notifier)
          .record(
            ReadingProgressEntry(
              comic: const Comic(id: 1, title: '测试漫画'),
              chapterId: validChapter ? 10 : 999,
              chapterTitle: '第一话',
              pageNumber: 7,
            ),
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: buildAppTheme(Brightness.dark),
            home: const DetailScreen(comicId: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('上次读到第 ${validChapter ? 8 : 4} 页'), findsOneWidget);
      await tester.tap(find.text('继续阅读'));
      await tester.pumpAndSettle();
      final reader = tester.widget<ReaderScreen>(find.byType(ReaderScreen));
      expect(reader.chapterId, 10);
      expect(reader.initialPage, validChapter ? 7 : 3);
    });
  }
}
