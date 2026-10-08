import 'package:comic/models/chapter.dart';
import 'package:comic/models/comic.dart';
import 'package:comic/models/reading_progress_entry.dart';
import 'package:comic/providers/comics_providers.dart';
import 'package:comic/providers/reader_providers.dart';
import 'package:comic/screens/home_screen.dart';
import 'package:comic/screens/reader_screen.dart';
import 'package:comic/theme.dart';
import 'package:comic/widgets/comic_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _EmptyLibrary extends RandomLibraryNotifier {
  @override
  Future<RandomLibraryState> build() async => const RandomLibraryState(
    seed: 1,
    pageOffset: 1,
    total: 0,
    pageSize: 30,
    comics: [],
  );
}

void main() {
  testWidgets('续读提示显示期间可点击并传递原章节与页码', (tester) async {
    const entry = ReadingProgressEntry(
      comic: Comic(id: 1, title: '续读测试漫画'),
      chapterId: 10,
      chapterTitle: '第一话',
      pageNumber: 5,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          randomLibraryProvider.overrideWith(_EmptyLibrary.new),
          recentReadingProvider.overrideWith((ref) async => [entry]),
          comicDetailProvider.overrideWith(
            (ref, id) async => const ComicDetail(
              comic: Comic(id: 1, title: '续读测试漫画'),
              chapters: [Chapter(id: 10, title: '第一话', sortOrder: 0)],
              favorited: false,
              authorFavorited: false,
            ),
          ),
          chapterImagesProvider.overrideWith((ref, id) async => []),
        ],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.dark),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('继续阅读').hitTestable(), findsOneWidget);
    await tester.tap(find.text('继续阅读'));
    await tester.pumpAndSettle();
    final reader = tester.widget<ReaderScreen>(find.byType(ReaderScreen));
    expect(reader.comicId, 1);
    expect(reader.chapterId, 10);
    expect(reader.initialPage, 5);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('续读提示5秒收起，同一位置刷新不重复，新位置重新提示', (tester) async {
    var page = 5;
    final container = ProviderContainer(
      overrides: [
        randomLibraryProvider.overrideWith(_EmptyLibrary.new),
        recentReadingProvider.overrideWith(
          (ref) async => [
            ReadingProgressEntry(
              comic: const Comic(id: 1, title: '续读测试漫画'),
              chapterId: 10,
              chapterTitle: '第一话',
              pageNumber: page,
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('继续阅读'), findsOneWidget);
    expect(
      tester.widget<ComicGrid>(find.byType(ComicGrid)).bottomPadding,
      greaterThan(0),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('继续阅读'), findsNothing);
    expect(tester.widget<ComicGrid>(find.byType(ComicGrid)).bottomPadding, 0);
    container.invalidate(recentReadingProvider);
    await tester.pumpAndSettle();
    expect(find.text('继续阅读'), findsNothing);
    page = 6;
    container.invalidate(recentReadingProvider);
    await tester.pumpAndSettle();
    expect(find.text('继续阅读'), findsOneWidget);
    expect(find.text('第一话 · 第7页'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('页大小按实际内容宽度计算并随布局变化更新', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final width = ValueNotifier<double>(550);
    addTearDown(width.dispose);
    final container = ProviderContainer(
      overrides: [
        randomLibraryProvider.overrideWith(_EmptyLibrary.new),
        recentReadingProvider.overrideWith((ref) async => []),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(Brightness.dark),
          home: ValueListenableBuilder<double>(
            valueListenable: width,
            builder: (context, value, child) => Align(
              child: SizedBox(width: value, child: const HomeScreen()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(randomLibraryProvider).requireValue.pageSize, 18);
    width.value = 950;
    await tester.pumpAndSettle();
    expect(container.read(randomLibraryProvider).requireValue.pageSize, 30);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
