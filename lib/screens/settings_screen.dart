import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final closeToTray = ref.watch(closeToTrayProvider);
    final c = context.appColors;
    // 桌面侧栏嵌入时无需标题；手机端推入时保留返回箭头。
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      appBar: canPop ? AppBar() : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '外观',
            style: TextStyle(
              color: c.text2,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(kRadiusCard),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '主题模式',
                  style: TextStyle(
                    color: c.text1,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '控制 App 整体配色：浅色、深色，或跟随系统自动切换',
                  style: TextStyle(color: c.text2, fontSize: 13),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    expandedInsets: EdgeInsets.zero,
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined),
                        label: Text('浅色'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined),
                        label: Text('深色'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_outlined),
                        label: Text('跟随系统'),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (selection) => ref
                        .read(themeModeProvider.notifier)
                        .setMode(selection.first),
                  ),
                ),
              ],
            ),
          ),
          if (defaultTargetPlatform == TargetPlatform.windows) ...[
            const SizedBox(height: 24),
            Text(
              '窗口',
              style: TextStyle(
                color: c.text2,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: BorderRadius.circular(kRadiusCard),
                border: Border.all(color: c.border),
              ),
              child: SwitchListTile(
                value: closeToTray,
                onChanged: (value) =>
                    ref.read(closeToTrayProvider.notifier).setEnabled(value),
                title: Text(
                  '关闭窗口时最小化到系统托盘',
                  style: TextStyle(
                    color: c.text1,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  '开启：点右上角 X 退到系统托盘继续运行；关闭：点右上角 X 直接退出',
                  style: TextStyle(color: c.text2, fontSize: 13),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
