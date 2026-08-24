import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final c = context.appColors;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
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
                  '选择浅色、深色或跟随系统外观',
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
        ],
      ),
    );
  }
}
