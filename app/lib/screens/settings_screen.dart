import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../providers/update_provider.dart';
import '../providers/server_data.dart';
import '../providers/server_provider.dart';
import '../providers/settings_provider.dart';
import '../services/update_service.dart';
import '../theme.dart';
import '../widgets/reader_settings_controls.dart';
import '../utils/user_error.dart';

enum _ServerTestStatus { idle, testing, success, error }

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _serverController;
  _ServerTestStatus _serverTestStatus = _ServerTestStatus.idle;
  String? _serverTestMessage;
  String? _lastVerifiedUrl;
  String? _serverSaveMessage;
  bool _serverSaving = false;
  int _serverTestSerial = 0;

  @override
  void initState() {
    super.initState();
    _serverController = TextEditingController(
      text: ref.read(serverSessionProvider).url,
    )..addListener(_onServerInputChanged);
  }

  @override
  void dispose() {
    _serverController
      ..removeListener(_onServerInputChanged)
      ..dispose();
    super.dispose();
  }

  void _onServerInputChanged() {
    _serverTestSerial++;
    if (_serverTestStatus == _ServerTestStatus.idle &&
        _serverSaveMessage == null) {
      return;
    }
    setState(() {
      _serverTestStatus = _ServerTestStatus.idle;
      _serverTestMessage = null;
      _serverSaveMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final closeToTray = ref.watch(closeToTrayProvider);
    final serverSession = ref.watch(serverSessionProvider);
    final c = context.appColors;
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      appBar: canPop ? AppBar(title: const Text('设置')) : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: EdgeInsets.all(
              MediaQuery.sizeOf(context).width < 480 ? 16 : 28,
            ),
            children: [
              if (!canPop) ...[
                Text('设置', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  '外观、阅读习惯与服务连接',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 28),
              ],
              _settingsGroup('外观与窗口', [
                _settingRow(
                  title: '主题模式',
                  description: '选择舒适的阅读配色',
                  control: _choices(
                    const {
                      ThemeMode.system: '跟随系统',
                      ThemeMode.light: '浅色',
                      ThemeMode.dark: '深色',
                    },
                    themeMode,
                    (mode) => _savePreference(
                      () => ref.read(themeModeProvider.notifier).setMode(mode),
                    ),
                  ),
                ),
                if (!kIsWeb &&
                    defaultTargetPlatform == TargetPlatform.windows) ...[
                  const Divider(),
                  SwitchListTile(
                    value: closeToTray,
                    onChanged: (value) => _savePreference(
                      () => ref
                          .read(closeToTrayProvider.notifier)
                          .setEnabled(value),
                    ),
                    title: const Text('关闭后留在系统托盘'),
                    subtitle: Text(
                      closeToTray ? '关闭窗口后继续运行，便于下次阅读' : '关闭窗口时直接退出应用',
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ],
              ]),
              _settingsGroup('阅读器', [
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text('应用于所有漫画，与阅读器内设置同步'),
                ),
                const ReaderSettingsControls(),
              ]),
              _settingsGroup('漫画服务器', [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: _buildServerSection(c, serverSession),
                ),
              ]),
              _settingsGroup('关于', [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: _buildAboutSection(c),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _savePreference(Future<void> Function() save) async {
    try {
      await save();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userMessageFor(error, fallback: '设置保存失败，请重试'))),
      );
    }
  }

  Widget _settingsGroup(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: context.appColors.surface1,
            border: Border.all(color: context.appColors.border),
            borderRadius: BorderRadius.circular(kRadiusCard),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    ),
  );

  Widget _settingRow({
    required String title,
    required String description,
    required Widget control,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
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
        if (constraints.maxWidth >= 560 &&
            MediaQuery.textScalerOf(context).scale(16) <= 18) {
          return Row(
            children: [
              Expanded(child: label),
              const SizedBox(width: 24),
              control,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [label, const SizedBox(height: 14), control],
        );
      },
    ),
  );

  Widget _choices<T>(
    Map<T, String> labels,
    T selected,
    ValueChanged<T>? onChanged,
  ) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(kRadiusButton),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final option in labels.entries)
            ChoiceChip(
              label: Text(option.value),
              selected: selected == option.key,
              showCheckmark: false,
              selectedColor: c.surface1,
              backgroundColor: Colors.transparent,
              side: BorderSide.none,
              labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected == option.key ? c.accent : c.text2,
              ),
              onSelected: onChanged == null
                  ? null
                  : (_) => onChanged(option.key),
            ),
        ],
      ),
    );
  }

  Widget _buildServerSection(AppColors c, ServerSession session) {
    final testColor = _serverTestStatus == _ServerTestStatus.error
        ? Theme.of(context).colorScheme.error
        : _serverTestStatus == _ServerTestStatus.success
        ? c.accent
        : c.text2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '服务器地址',
          style: TextStyle(
            color: c.text1,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '当前生效：${session.url}',
          style: TextStyle(color: c.text2, fontSize: 14),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final field = TextField(
              controller: _serverController,
              enabled: !_serverSaving,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                hintText: 'http://192.168.1.100:8888',
              ),
            );
            final actions = Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _serverTestStatus == _ServerTestStatus.testing
                      ? null
                      : _testServerConnection,
                  icon: _serverTestStatus == _ServerTestStatus.testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering, size: 18),
                  label: Text(
                    _serverTestStatus == _ServerTestStatus.testing
                        ? '测试中…'
                        : '测试连接',
                  ),
                ),
                FilledButton.icon(
                  onPressed: _serverSaving ? null : _saveServerAddress,
                  icon: _serverSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(_serverSaving ? '保存中…' : '保存'),
                ),
              ],
            );
            if (constraints.maxWidth >= 560 &&
                MediaQuery.textScalerOf(context).scale(16) <= 18) {
              return Row(
                children: [
                  Expanded(child: field),
                  const SizedBox(width: 12),
                  actions,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [field, const SizedBox(height: 12), actions],
            );
          },
        ),
        if (_serverTestMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            _serverTestMessage!,
            style: TextStyle(color: testColor, fontSize: 14),
          ),
        ],
        if (_serverSaveMessage != null) ...[
          const SizedBox(height: 6),
          Text(
            _serverSaveMessage!,
            style: TextStyle(color: c.text2, fontSize: 14),
          ),
        ],
      ],
    );
  }

  Future<void> _testServerConnection() async {
    final input = _serverController.text;
    final serial = ++_serverTestSerial;
    setState(() {
      _serverTestStatus = _ServerTestStatus.testing;
      _serverTestMessage = null;
      _serverSaveMessage = null;
    });
    try {
      final normalized = normalizeServerUrl(input);
      ref.invalidate(serverConnectionTestProvider(input));
      await ref.read(serverConnectionTestProvider(input).future);
      if (!mounted ||
          serial != _serverTestSerial ||
          _serverController.text != input) {
        return;
      }
      setState(() {
        _serverTestStatus = _ServerTestStatus.success;
        _serverTestMessage = '连接成功';
        _lastVerifiedUrl = normalized;
      });
    } catch (error) {
      if (!mounted || serial != _serverTestSerial) return;
      setState(() {
        _serverTestStatus = _ServerTestStatus.error;
        _serverTestMessage = userMessageFor(error, fallback: '连接测试失败');
        _lastVerifiedUrl = null;
      });
    }
  }

  Future<void> _saveServerAddress() async {
    setState(() {
      _serverSaving = true;
      _serverSaveMessage = null;
    });
    try {
      final normalized = normalizeServerUrl(_serverController.text);
      final changed = await saveServerUrl(ref, normalized);
      if (!mounted) return;
      _serverController.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
      final verified = _lastVerifiedUrl == normalized;
      setState(() {
        _serverSaveMessage = changed
            ? verified
                  ? '服务器地址已保存并验证'
                  : '服务器地址已保存，尚未验证连接'
            : '服务器地址未变化';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _serverSaveMessage = userMessageFor(error, fallback: '服务器地址保存失败');
      });
    } finally {
      if (mounted) setState(() => _serverSaving = false);
    }
  }

  Widget _buildAboutSection(AppColors c) {
    final update = ref.watch(appUpdateProvider);
    final notifier = ref.read(appUpdateProvider.notifier);
    final busy = update.checking || update.installing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<String>(
          future: _loadVersion(),
          builder: (context, snap) => _settingRow(
            title: 'Comic',
            description: '当前版本 v${snap.data ?? '…'}',
            control: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (supportsAppUpdates)
                  FilledButton.tonal(
                    onPressed: busy ? null : notifier.check,
                    child: Text(update.checking ? '检查中…' : '检查更新'),
                  ),
                OutlinedButton.icon(
                  onPressed: _openReleasePage,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('在 GitHub 打开'),
                ),
              ],
            ),
          ),
        ),
        if (busy) const LinearProgressIndicator(minHeight: 2),
        if (update.message != null) Text(update.message!),
        if (update.info != null &&
            !update.available &&
            !update.checking &&
            update.message == null)
          const Text('已是最新版本'),
        if (update.available) ...[
          Text('发现新版本 v${update.info!.latestVersion}'),
          if (update.info!.releaseNotes?.isNotEmpty == true)
            Text(update.info!.releaseNotes!),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy ? null : notifier.install,
            icon: const Icon(Icons.download, size: 18),
            label: const Text('下载并更新'),
          ),
        ],
      ],
    );
  }

  Future<void> _openReleasePage() async {
    try {
      if (await launchUrl(
        Uri.parse(kReleasePageUrl),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      // 平台异常与无法唤起浏览器统一反馈，保留更新状态。
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('无法打开 GitHub，请稍后重试')));
  }

  Future<String> _loadVersion() async {
    try {
      return (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      return '未知';
    }
  }
}
