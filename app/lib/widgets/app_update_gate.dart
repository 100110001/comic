import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/progress_lifecycle_provider.dart';
import '../providers/update_provider.dart';
import '../services/update_service.dart';

/// 位于 Navigator 外；强更时不挂载业务路由，返回不能露出原页面。
class AppUpdateGate extends ConsumerStatefulWidget {
  const AppUpdateGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<AppUpdateGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(appUpdateProvider).startupPending) {
        ref.read(appUpdateProvider.notifier).check();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final update = ref.watch(appUpdateProvider);
    if (update.startupPending && !update.required) {
      return const Material(child: Center(child: CircularProgressIndicator()));
    }
    if (update.required) {
      return const AppUpdatePage();
    }
    final showOptional = update.available && !update.dismissed;
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: showOptional,
          child: _UpdateApproved(child: widget.child),
        ),
        if (showOptional) const Positioned.fill(child: AppUpdatePage()),
      ],
    );
  }
}

class _UpdateApproved extends ConsumerWidget {
  const _UpdateApproved({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(progressLifecycleProvider);
    return child;
  }
}

class AppUpdatePage extends ConsumerWidget {
  const AppUpdatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appUpdateProvider);
    final notifier = ref.read(appUpdateProvider.notifier);
    final info = state.info!;
    final busy = state.checking || state.installing;
    final reason = minimumReasonFor(info);
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.system_update, size: 48),
                  const SizedBox(height: 20),
                  Text(
                    state.required ? '需要更新后继续使用' : '发现新版本',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '当前版本 v${state.currentVersion} · 最新版本 v${info.latestVersion}',
                  ),
                  if (state.required) ...[
                    const SizedBox(height: 8),
                    Text('最低支持版本 v${minimumVersionFor(info)}'),
                    if (reason != null && reason.isNotEmpty) Text(reason),
                  ],
                  if (info.releaseNotes?.isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    Text(info.releaseNotes!),
                  ],
                  if (state.message != null) ...[
                    const SizedBox(height: 16),
                    Text(state.message!, semanticsLabel: state.message),
                  ],
                  if (busy) ...[
                    const SizedBox(height: 16),
                    Text(state.installing ? '正在下载并准备安装…' : '正在检查更新…'),
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                  ],
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: busy ? null : notifier.install,
                        icon: const Icon(Icons.download),
                        label: const Text('下载并更新'),
                      ),
                      OutlinedButton(
                        onPressed: busy ? null : notifier.check,
                        child: const Text('重新检查'),
                      ),
                      if (!state.required)
                        TextButton(
                          onPressed: busy ? null : notifier.dismiss,
                          child: const Text('稍后更新'),
                        ),
                      TextButton(
                        onPressed: () => exitForUpdate(SystemNavigator.pop),
                        child: const Text('退出应用'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
