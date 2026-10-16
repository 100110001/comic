import 'package:comic/main.dart';
import 'package:comic/models/comic.dart';
import 'package:comic/models/favorite_author.dart';
import 'package:comic/models/reading_progress_entry.dart';
import 'package:comic/providers/reading_progress_provider.dart';
import 'package:comic/providers/server_provider.dart';
import 'package:comic/screens/home_screen.dart';
import 'package:comic/services/api_client.dart';
import 'package:comic/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/progress_storage.dart';

class _EmptyClient extends ApiClient {
  _EmptyClient() : super(baseUrl: 'http://example.test', generation: 0);
  @override
  Future<({List<Comic> list, int total})> getComics({
    int pageOffset = 1,
    int pageSize = 20,
    String keyword = '',
    bool random = false,
    int? seed,
    bool recent = false,
  }) async => (list: <Comic>[], total: 0);
  @override
  Future<List<Comic>> getFavorites() async => [];
  @override
  Future<List<FavoriteAuthor>> getFavoriteAuthors() async => [];
  @override
  Future<List<ReadingProgressEntry>> getRecent() async => [];
}

void main() {
  testWidgets(
    '桌面导航保留首页搜索及设置中的输入状态',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final client = _EmptyClient();
      addTearDown(client.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(client),
            progressStorageProvider.overrideWithValue(MemoryProgressStorage()),
          ],
          child: MaterialApp(
            theme: buildAppTheme(Brightness.light),
            home: const DesktopShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final originalHome = tester.state(find.byType(HomeScreen));
      await tester.enterText(find.byType(TextField).first, '保留的搜索');
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'http://new.example.test',
      );
      await tester.tap(find.text('首页'));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(HomeScreen)), same(originalHome));
      expect(find.text('保留的搜索'), findsOneWidget);
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      expect(find.text('http://new.example.test'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
}
