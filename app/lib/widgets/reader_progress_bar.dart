import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 章内进度；输入框与滑杆共用页码范围，不创建会截获 Esc 的路由。
class ReaderProgressBar extends StatefulWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onSeek;
  const ReaderProgressBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onSeek,
  });
  @override
  State<ReaderProgressBar> createState() => _ReaderProgressBarState();
}

class _ReaderProgressBarState extends State<ReaderProgressBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String? _error;
  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _seek() {
    final value = int.tryParse(_controller.text);
    if (value == null || value < 1 || value > widget.totalPages) {
      setState(() => _error = '请输入 1–${widget.totalPages}');
      return;
    }
    setState(() => _error = null);
    _focus.unfocus();
    widget.onSeek(value - 1);
  }

  @override
  Widget build(BuildContext context) {
    final max = widget.totalPages > 1 ? widget.totalPages - 1 : 0;
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '第 ${widget.totalPages == 0 ? 0 : widget.currentPage + 1} / ${widget.totalPages} 页',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: TextField(
                    key: const ValueKey('reader-page-input'),
                    controller: _controller,
                    focusNode: _focus,
                    enabled: widget.totalPages > 0,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      hintText: '页码',
                      isDense: true,
                      contentPadding: EdgeInsets.all(10),
                    ),
                    onSubmitted: (_) => _seek(),
                  ),
                ),
                IconButton(
                  tooltip: '跳转到页码',
                  onPressed: widget.totalPages > 0 ? _seek : null,
                  icon: const Icon(Icons.arrow_forward, size: 20),
                ),
              ],
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            Slider(
              value: widget.currentPage.clamp(0, max).toDouble(),
              max: max > 0 ? max.toDouble() : 1,
              onChanged: max > 0
                  ? (value) => widget.onSeek(value.round())
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
