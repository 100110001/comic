import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_history_provider.dart';
import '../providers/server_provider.dart';
import '../utils/user_error.dart';
import 'status_views.dart';
import '../theme.dart';

void showSearchHistory(
  BuildContext context, {
  required ValueChanged<String> onSelected,
}) {
  FocusScope.of(context).unfocus();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * .6,
        child: SearchHistoryView(
          onSelected: (keyword) {
            Navigator.pop(sheetContext);
            onSelected(keyword);
          },
        ),
      ),
    ),
  );
}

class SearchHistoryView extends ConsumerStatefulWidget {
  const SearchHistoryView({super.key, required this.onSelected});
  final ValueChanged<String> onSelected;
  @override
  ConsumerState<SearchHistoryView> createState() => _SearchHistoryViewState();
}

class _SearchHistoryViewState extends ConsumerState<SearchHistoryView> {
  bool _busy = false;

  Future<void> _change(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessageFor(error, fallback: '搜索历史保存失败，请重试')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(searchHistoryProvider);
    final source = ref.watch(serverSessionProvider).url;
    final words = history.value ?? const <String>[];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '搜索历史',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: _busy || words.isEmpty
                    ? null
                    : () => _change(
                        () => ref
                            .read(searchHistoryStoreProvider.notifier)
                            .clear(source),
                      ),
                child: const Text('清空'),
              ),
            ],
          ),
        ),
        Expanded(
          child: history.isLoading && words.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : history.hasError && words.isEmpty
              ? StatusView(
                  icon: Icons.history,
                  message: '搜索历史读取失败',
                  actionLabel: '重试',
                  onAction: () => ref.invalidate(searchHistoryStoreProvider),
                )
              : words.isEmpty
              ? const StatusView(icon: Icons.search, message: '输入关键字搜索漫画或作者')
              : ListView.builder(
                  itemCount: words.length,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemBuilder: (context, index) {
                    final word = words[index];
                    return ListTile(
                      leading: Icon(
                        Icons.history,
                        size: 20,
                        color: context.appColors.text2,
                      ),
                      title: Tooltip(
                        message: word,
                        child: Text(
                          word,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      onTap: () {
                        if (ref.read(serverSessionProvider).url == source) {
                          widget.onSelected(word);
                        }
                      },
                      trailing: IconButton(
                        tooltip: '删除历史：$word',
                        icon: Icon(
                          Icons.close,
                          size: 18,
                          color: context.appColors.text2,
                        ),
                        onPressed: _busy
                            ? null
                            : () => _change(
                                () => ref
                                    .read(searchHistoryStoreProvider.notifier)
                                    .remove(source, word),
                              ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
