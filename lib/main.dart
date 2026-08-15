import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'platform.dart';
import 'providers/comics_providers.dart';
import 'screens/discovery_screen.dart';
import 'screens/home_screen.dart';
import 'screens/mine_screen.dart';
import 'tray/close_to_tray.dart';
import 'widgets/reading_lists.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupCloseToTray();
  runApp(const ProviderScope(child: ComicApp()));
}

final _navigatorKey = GlobalKey<NavigatorState>();

class ComicApp extends StatelessWidget {
  const ComicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '漫画库',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0d1117),
        colorScheme: const ColorScheme.dark(primary: Color(0xFF58a6ff)),
      ),
      builder: (context, child) => Listener(
        behavior: HitTestBehavior.translucent,
        // 鼠标侧键（后退键）触发页面返回
        onPointerDown: (event) {
          if (event.buttons & kBackMouseButton != 0) {
            _navigatorKey.currentState?.maybePop();
          }
        },
        child: child!,
      ),
      home: const _AdaptiveShell(),
    );
  }
}

/// 按窗口宽度选择桌面壳或手机壳，窗口尺寸变化时自动切换。
class _AdaptiveShell extends StatelessWidget {
  const _AdaptiveShell();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return isDesktopAt(width) ? const DesktopShell() : const MobileShell();
  }
}

/// 手机壳：底部"首页 / 发现 / 我的"三个 tab。
class MobileShell extends StatefulWidget {
  const MobileShell({super.key});

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [HomeScreen(), DiscoveryScreen(), MineScreen()],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        backgroundColor: const Color(0xFF161b22),
        selectedItemColor: const Color(0xFF58a6ff),
        unselectedItemColor: const Color(0xFF8b949e),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: '发现'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}

/// 桌面壳：左侧边栏（首页/发现/最近阅读/收藏/收藏作者）+ 内容区。
class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: const Color(0xFF161b22),
            selectedIndex: _index,
            onDestinationSelected: (i) {
              setState(() => _index = i);
              // 切换侧栏入口时后台刷新对应列表
              switch (i) {
                case 2:
                  ref.invalidate(recentReadingProvider);
                  break;
                case 3:
                  ref.invalidate(favoritesProvider);
                  break;
                case 4:
                  ref.invalidate(favoriteAuthorsProvider);
                  break;
              }
            },
            labelType: NavigationRailLabelType.all,
            selectedIconTheme: const IconThemeData(color: Color(0xFF58a6ff)),
            unselectedIconTheme: const IconThemeData(color: Color(0xFF8b949e)),
            selectedLabelTextStyle: const TextStyle(
              color: Color(0xFF58a6ff),
              fontSize: 12,
            ),
            unselectedLabelTextStyle: const TextStyle(
              color: Color(0xFF8b949e),
              fontSize: 12,
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.menu_book),
                label: Text('首页'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.explore),
                label: Text('发现'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history),
                label: Text('最近阅读'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.favorite_border),
                selectedIcon: Icon(Icons.favorite),
                label: Text('收藏'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.star_border),
                selectedIcon: Icon(Icons.star),
                label: Text('收藏作者'),
              ),
            ],
          ),
          const VerticalDivider(width: 1, color: Color(0xFF21262d)),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                const HomeScreen(),
                const DiscoveryScreen(),
                const _PageScaffold(title: '最近阅读', child: RecentReadingList()),
                const _PageScaffold(title: '收藏', child: FavoritesList()),
                const _PageScaffold(
                  title: '收藏作者',
                  child: FavoriteAuthorsList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  const _PageScaffold({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161b22),
        title: Text(title, style: const TextStyle(color: Colors.white)),
      ),
      body: child,
    );
  }
}
