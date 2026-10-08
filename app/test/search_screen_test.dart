import 'package:comic/models/comic.dart';
import 'package:comic/providers/server_provider.dart';
import 'package:comic/screens/search_screen.dart';
import 'package:comic/services/api_client.dart';
import 'package:comic/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SearchClient extends ApiClient {
  _SearchClient() : super(baseUrl: 'http://example.test', generation: 0);

  bool fail = true;
  final keywords = <String>[];

  @override
  Future<({List<Comic> list, int total})> getComics({
    int pageOffset = 1,
    int pageSize = 20,
    String keyword = '',
    bool random = false,
    int? seed,
  }) async {
    keywords.add(keyword);
    if (fail) throw Exception('测试搜索失败');
    return (list: <Comic>[], total: 0);
  }
}

void main() {
  testWidgets('作者入口首帧后搜索，失败重试保留关键字', (tester) async {
    final client = _SearchClient();
    addTearDown(client.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(client)],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.dark),
          home: const SearchScreen(initialKeyword: '测试作者'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(client.keywords, ['测试作者']);
    expect(find.text('重试'), findsOneWidget);
    client.fail = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(client.keywords, ['测试作者', '测试作者']);
    expect(find.text('没有找到相关漫画'), findsOneWidget);
  });
}
