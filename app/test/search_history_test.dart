import 'dart:async';
import 'dart:convert';
import 'package:comic/providers/search_history_provider.dart';
import 'package:comic/providers/server_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const origin = 'http://example.com';

class HistoryPreferences implements SharedPreferences {
  String? contents;
  bool fail = false;
  Completer<void>? block;
  @override
  String? getString(String key) => contents;
  @override
  Future<bool> setString(String key, String value) async {
    await block?.future;
    if (fail) return false;
    contents = value;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

ProviderContainer historyContainer(Future<SharedPreferences> prefs) =>
    ProviderContainer(
      overrides: [
        searchHistoryPreferencesProvider.overrideWithValue(prefs),
        serverSessionProvider.overrideWith(
          () => ServerSessionNotifier(initialUrl: origin),
        ),
      ],
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('去首尾空白、去重置顶、保留大小写并最多 20 条，重启可恢复', () async {
    final prefs = HistoryPreferences();
    var c = historyContainer(Future.value(prefs));
    final store = c.read(searchHistoryStoreProvider.notifier);
    await store.remember(origin, '  ');
    for (var i = 0; i < 22; i++) {
      await store.remember(origin, '词$i');
    }
    await store.remember(origin, '  词3  ');
    var words = c.read(searchHistoryProvider).requireValue;
    expect(words.length, 20);
    expect(words.first, '词3');
    expect(words.toSet().length, 20);
    expect(words, isNot(contains('词0')));
    await store.remember(origin, 'ABC');
    await store.remember(origin, 'abc');
    c.dispose();
    c = historyContainer(Future.value(prefs));
    addTearDown(c.dispose);
    await c.read(searchHistoryStoreProvider.future);
    words = c.read(searchHistoryProvider).requireValue;
    expect(words.take(2), ['abc', 'ABC']);
  });

  test('初始化与保存/清空串行，晚到的旧提交不能恢复已清空历史', () async {
    final ready = Completer<SharedPreferences>();
    final prefs = HistoryPreferences()..block = Completer<void>();
    final c = historyContainer(ready.future);
    addTearDown(c.dispose);
    final store = c.read(searchHistoryStoreProvider.notifier);
    final saved = store.remember(origin, '旧提交');
    final cleared = store.clear(origin);
    ready.complete(prefs);
    await Future<void>.delayed(Duration.zero);
    prefs.block!.complete();
    await Future.wait([saved, cleared]);
    expect(c.read(searchHistoryProvider).requireValue, isEmpty);
    expect((jsonDecode(prefs.contents!) as Map)['sources'], isEmpty);
  });

  test('来源切换隔离，旧来源保存完成不会显示或删除新来源历史', () async {
    final prefs = HistoryPreferences();
    final c = historyContainer(Future.value(prefs));
    addTearDown(c.dispose);
    final store = c.read(searchHistoryStoreProvider.notifier);
    await store.remember(origin, '甲');
    prefs.block = Completer<void>();
    final delayed = store.remember(origin, '晚到的甲');
    final session = c.read(serverSessionProvider.notifier);
    await session.save('http://other.com');
    expect(c.read(searchHistoryProvider).requireValue, isEmpty);
    final newSource = store.remember('http://other.com', '乙');
    prefs.block!.complete();
    await Future.wait([delayed, newSource]);
    expect(c.read(searchHistoryProvider).requireValue, ['乙']);
    await store.clear(origin);
    expect(c.read(searchHistoryProvider).requireValue, ['乙']);
    await session.save(origin);
    expect(c.read(searchHistoryProvider).requireValue, isEmpty);
  });

  test('删除持久化，写入失败保持旧快照并可继续操作', () async {
    final prefs = HistoryPreferences();
    final c = historyContainer(Future.value(prefs));
    addTearDown(c.dispose);
    final store = c.read(searchHistoryStoreProvider.notifier);
    await store.remember(origin, '甲');
    await store.remember(origin, '乙');
    prefs.fail = true;
    await expectLater(store.remove(origin, '甲'), throwsException);
    expect(c.read(searchHistoryProvider).requireValue, ['乙', '甲']);
    prefs.fail = false;
    await store.remove(origin, '甲');
    expect(c.read(searchHistoryProvider).requireValue, ['乙']);
    expect((jsonDecode(prefs.contents!) as Map)['sources'][origin], ['乙']);
  });

  test('单条和单来源损坏不妨碍有效历史恢复', () async {
    final prefs = HistoryPreferences()
      ..contents = jsonEncode({
        'version': 1,
        'sources': {
          origin: ['甲', 3, '甲', ' ', ' 乙 '],
          'http://other.com': '损坏',
          '无效地址': ['丙'],
        },
      });
    final c = historyContainer(Future.value(prefs));
    addTearDown(c.dispose);
    await c.read(searchHistoryStoreProvider.future);
    expect(c.read(searchHistoryProvider).requireValue, ['甲', '乙']);
  });
}
