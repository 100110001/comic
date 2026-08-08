import 'package:flutter/material.dart';
import 'platform.dart';
import 'screens/home_screen.dart';
import 'screens/mine_screen.dart';

void main() {
  runApp(const ComicApp());
}

class ComicApp extends StatelessWidget {
  const ComicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '漫画库',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0d1117),
        colorScheme: const ColorScheme.dark(primary: Color(0xFF58a6ff)),
      ),
      home: isDesktop ? const DesktopShell() : const MobileShell(),
    );
  }
}

/// 手机壳：底部"首页 / 我的"两个 tab。
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
        children: const [HomeScreen(), MineScreen()],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        backgroundColor: const Color(0xFF161b22),
        selectedItemColor: const Color(0xFF58a6ff),
        unselectedItemColor: const Color(0xFF8b949e),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}

/// 桌面壳：左侧边栏（首页/最近阅读/收藏）+ 内容区。
class DesktopShell extends StatefulWidget {
  const DesktopShell({super.key});

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: const Color(0xFF161b22),
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
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
                icon: Icon(Icons.history),
                label: Text('最近阅读'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.favorite_border),
                selectedIcon: Icon(Icons.favorite),
                label: Text('收藏'),
              ),
            ],
          ),
          const VerticalDivider(width: 1, color: Color(0xFF21262d)),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: const [
                HomeScreen(),
                _PlaceholderPage(title: '最近阅读'),
                _PlaceholderPage(title: '收藏'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String title;
  const _PlaceholderPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161b22),
        title: Text(title, style: const TextStyle(color: Colors.white)),
      ),
      body: const Center(
        child: Text('建设中', style: TextStyle(color: Color(0xFF8b949e))),
      ),
    );
  }
}
