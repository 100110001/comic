import 'package:flutter/material.dart';
import '../theme.dart';

/// 全 App 统一的空态/错误态组件：图标 + 文案 + 可选操作。
class StatusView extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const StatusView({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: kSurface2,
              shape: BoxShape.circle,
              border: Border.all(color: kBorder),
            ),
            child: Icon(icon, color: kText2, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: kText2, fontSize: 14),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// 列表页空态：可下拉刷新的滚动容器内居中的空状态。
class EmptyListView extends StatelessWidget {
  final String message;

  const EmptyListView({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 140),
        StatusView(icon: Icons.inbox_outlined, message: message),
      ],
    );
  }
}
