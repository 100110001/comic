import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../theme.dart';

/// 两处入口共用选项与保存路径，compact 只改变排版。
class ReaderSettingsControls extends ConsumerStatefulWidget {
  const ReaderSettingsControls({super.key, this.compact = false});
  final bool compact;

  @override
  ConsumerState<ReaderSettingsControls> createState() =>
      _ReaderSettingsControlsState();
}

class _ReaderSettingsControlsState
    extends ConsumerState<ReaderSettingsControls> {
  bool _saving = false;

  Future<void> _save(Future<void> Function() operation) async {
    setState(() => _saving = true);
    try {
      await operation();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('阅读设置保存失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _update(ReaderPreferences Function(ReaderPreferences) change) =>
      _save(() => ref.read(readerPreferencesProvider.notifier).update(change));

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(readerPreferencesProvider);
    final sr = ref.watch(superResolutionDefaultProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row(
          '阅读模式',
          '跟随设备：桌面单页、手机连续；窄屏双页按单页显示',
          _choices(
            readerModeLabels,
            prefs.mode,
            (value) => _update((p) => p.copyWith(mode: value)),
          ),
        ),
        const Divider(height: 1),
        _row(
          '翻页方向',
          '控制分页顺序、左右滑动与方向键',
          _choices(
            readingDirectionLabels,
            prefs.direction,
            (value) => _update((p) => p.copyWith(direction: value)),
          ),
        ),
        const Divider(height: 1),
        _row(
          '页面适配',
          '用于单页与双页；连续阅读始终适应宽度',
          _choices(
            readerFitLabels,
            prefs.fit,
            (value) => _update((p) => p.copyWith(fit: value)),
          ),
        ),
        const Divider(height: 1),
        _row(
          '阅读背景',
          '只调整阅读画布，工具栏沿用应用主题',
          _choices(
            readerBackgroundLabels,
            prefs.background,
            (value) => _update((p) => p.copyWith(background: value)),
          ),
        ),
        const Divider(height: 1),
        SwitchListTile(
          contentPadding: EdgeInsets.symmetric(
            vertical: widget.compact ? 4 : 12,
          ),
          title: const Text('自动隐藏工具栏'),
          subtitle: const Text('无操作 3 秒后隐藏，点击阅读区域恢复'),
          value: prefs.autoHide,
          onChanged: _saving
              ? null
              : (value) => _update((p) => p.copyWith(autoHide: value)),
        ),
        const Divider(height: 1),
        _row(
          '超分策略',
          switch (sr) {
            SuperResolutionMode.on => '始终使用 2× 增强',
            SuperResolutionMode.adaptive => '原图清晰度不足时自动增强',
            SuperResolutionMode.off => '保持原图显示',
          },
          _choices(
            superResolutionModeLabels,
            sr,
            (value) => _save(
              () => ref
                  .read(superResolutionDefaultProvider.notifier)
                  .setMode(value),
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(String title, String description, Widget control) => Padding(
    padding: EdgeInsets.symmetric(vertical: widget.compact ? 12 : 20),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final label = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 5),
            Text(description, style: Theme.of(context).textTheme.bodySmall),
          ],
        );
        if (!widget.compact &&
            constraints.maxWidth >= 600 &&
            MediaQuery.textScalerOf(context).scale(14) <= 18) {
          return Row(
            children: [
              Expanded(child: label),
              const SizedBox(width: 20),
              Flexible(child: control),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [label, const SizedBox(height: 12), control],
        );
      },
    ),
  );

  Widget _choices<T>(
    Map<T, String> labels,
    T selected,
    ValueChanged<T> onChanged,
  ) {
    final c = context.appColors;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final option in labels.entries)
          ChoiceChip(
            label: Text(option.value),
            selected: selected == option.key,
            showCheckmark: false,
            selectedColor: c.accent.withValues(alpha: 0.14),
            labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected == option.key ? c.accent : c.text2,
            ),
            onSelected: _saving ? null : (_) => onChanged(option.key),
          ),
      ],
    );
  }
}
