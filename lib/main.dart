import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'platform.dart';
import 'providers/comics_providers.dart';
import 'providers/settings_provider.dart';
import 'screens/discovery_screen.dart';
import 'screens/home_screen.dart';
import 'screens/mine_screen.dart';
import 'screens/settings_screen.dart';
import 'theme.dart';
import 'tray/close_to_tray.dart';
import 'widgets/reading_lists.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupCloseToTray();
  final themeMode = await loadThemeMode();
  final closeToTray = await loadCloseToTray();
  runApp(
    ProviderScope(
      overrides: [
        themeModeProvider.overrideWith(
          () => ThemeModeNotifier(initial: themeMode),
        ),
        closeToTrayProvider.overrideWith(
          () => CloseToTrayNotifier(initial: closeToTray),
        ),
      ],
      child: const ComicApp(),
    ),
  );
}

final _navigatorKey = GlobalKey<NavigatorState>();

class ComicApp extends ConsumerWidget {
  const ComicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: '漫画库',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: themeMode,
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
          _DesktopSidebar(
            selectedIndex: _index,
            onSelect: (i) {
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
          ),
          const VerticalDivider(width: 1),
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
                const _PageScaffold(title: '设置', child: SettingsScreen()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 主侧栏导航项（不含底部固定的"设置"）。
const _mainNavItems = [
  (icon: Icons.menu_book_outlined, selectedIcon: Icons.menu_book, label: '首页'),
  (icon: Icons.explore_outlined, selectedIcon: Icons.explore, label: '发现'),
  (icon: Icons.history, selectedIcon: Icons.history, label: '最近阅读'),
  (icon: Icons.favorite_border, selectedIcon: Icons.favorite, label: '收藏'),
  (icon: Icons.star_border, selectedIcon: Icons.star, label: '收藏作者'),
];

/// 桌面左侧导航：图标+文字列表式，选中强调色淡底，悬停浅底，"设置"固定底部。
class _DesktopSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _DesktopSidebar({required this.selectedIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 208,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Text(
              '漫画库',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (var i = 0; i < _mainNavItems.length; i++)
                  _SideNavItem(
                    icon: _mainNavItems[i].icon,
                    selectedIcon: _mainNavItems[i].selectedIcon,
                    label: _mainNavItems[i].label,
                    selected: selectedIndex == i,
                    onTap: () => onSelect(i),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 12, endIndent: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: _SideNavItem(
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings,
              label: '设置',
              selected: selectedIndex == _mainNavItems.length,
              onTap: () => onSelect(_mainNavItems.length),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideNavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SideNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Material(
      color: selected ? c.accent.withValues(alpha: 0.15) : Colors.transparent,
      borderRadius: BorderRadius.circular(kRadiusButton),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadiusButton),
        hoverColor: selected ? Colors.transparent : c.surface2,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                selected ? selectedIcon : icon,
                size: 20,
                color: selected ? c.accent : c.text2,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: selected ? c.accent : c.text2,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
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
      appBar: AppBar(title: Text(title)),
      body: child,
    );
  }
}
