import 'package:flutter/material.dart';

class ReaderProgressBar extends StatelessWidget {
  final int currentPage; // 0 起始
  final int totalPages;
  final ValueChanged<int> onSeek;
  const ReaderProgressBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final max = totalPages > 1 ? totalPages - 1 : 0;
    final label = Text(
      '第 ${currentPage + 1} / $totalPages 页',
      style: const TextStyle(color: Colors.white, fontSize: 12),
    );
    if (max <= 0) {
      return Material(
        color: const Color(0xFF161b22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [label]),
        ),
      );
    }
    return Material(
      color: const Color(0xFF161b22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            label,
            Expanded(
              child: Slider(
                value: currentPage.clamp(0, max).toDouble(),
                max: max.toDouble(),
                onChanged: (v) => onSeek(v.round()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
