import 'package:flutter/material.dart';
import '../theme.dart';

/// 工作台式页头，窄屏和大字体时操作自然换行。
class PageHeading extends StatelessWidget {
  const PageHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final heading = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.appColors.text2),
          ),
        ],
      );
      if (action == null) return heading;
      if (constraints.maxWidth < 520 ||
          MediaQuery.textScalerOf(context).scale(16) > 22) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [heading, const SizedBox(height: 14), action!],
        );
      }
      return Row(
        children: [
          Expanded(child: heading),
          const SizedBox(width: 24),
          action!,
        ],
      );
    },
  );
}
