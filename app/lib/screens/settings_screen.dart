import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/update_info.dart';
import '../providers/server_data.dart';
import '../providers/server_provider.dart';
import '../providers/settings_provider.dart';
import '../services/update_service.dart';
import '../theme.dart';
import '../utils/user_error.dart';

enum _UpdateStatus { idle, checking, latest, available, error, downloading }

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
  bool _savingSuperResolution = false;
  int _serverTestSerial = 0;
  _UpdateStatus _status = _UpdateStatus.idle;
  UpdateInfo? _info;
  String? _error;

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
    final superResolutionDefault = ref.watch(superResolutionDefaultProvider);
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
                  '让 Comic 更适合你的阅读习惯',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 28),
              ],
              _settingsGroup('阅读与外观', [
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
                    (mode) =>
                        ref.read(themeModeProvider.notifier).setMode(mode),
                  ),
                ),
                const Divider(),
                _settingRow(
                  title: '超分默认策略',
                  description: switch (superResolutionDefault) {
                    SuperResolutionMode.on => '始终使用 2× 增强，阅读器可临时关闭',
                    SuperResolutionMode.adaptive => '原图清晰度不足时自动增强',
                    SuperResolutionMode.off => '保持原图显示，阅读器可临时开启',
                  },
                  control: _choices(
                    const {
                      SuperResolutionMode.on: '开启',
                      SuperResolutionMode.adaptive: '自适应',
                      SuperResolutionMode.off: '关闭',
                    },
                    superResolutionDefault,
                    _savingSuperResolution ? null : _saveSuperResolutionDefault,
                  ),
                ),
                if (defaultTargetPlatform == TargetPlatform.windows) ...[
                  const Divider(),
                  SwitchListTile(
                    value: closeToTray,
                    onChanged: (value) => ref
                        .read(closeToTrayProvider.notifier)
                        .setEnabled(value),
                    title: const Text('关闭后留在系统托盘'),
                    subtitle: Text(
                      closeToTray ? '关闭窗口后继续运行，便于下次阅读' : '关闭窗口时直接退出应用',
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ],
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

  Widget _settingsGroup(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: context.appColors.surface1,
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
            MediaQuery.textScalerOf(context).scale(14) <= 18) {
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

  Future<void> _saveSuperResolutionDefault(SuperResolutionMode value) async {
    setState(() => _savingSuperResolution = true);
    try {
      await ref.read(superResolutionDefaultProvider.notifier).setMode(value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('超分设置保存失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _savingSuperResolution = false);
    }
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
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '当前生效：${session.url}',
          style: TextStyle(color: c.text2, fontSize: 13),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final field = TextField(
              controller: _serverController,
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
                MediaQuery.textScalerOf(context).scale(14) <= 18) {
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
            style: TextStyle(color: testColor, fontSize: 13),
          ),
        ],
        if (_serverSaveMessage != null) ...[
          const SizedBox(height: 6),
          Text(
            _serverSaveMessage!,
            style: TextStyle(color: c.text2, fontSize: 13),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<String>(
          future: _loadVersion(),
          builder: (context, snap) => _settingRow(
            title: 'Comic',
            description: '当前版本 v${snap.data ?? '…'}',
            control: kIsWeb
                ? const SizedBox.shrink()
                : FilledButton.tonal(
                    onPressed:
                        _status == _UpdateStatus.checking ||
                            _status == _UpdateStatus.downloading
                        ? null
                        : _checkUpdate,
                    child: Text(
                      _status == _UpdateStatus.checking ? '检查中…' : '检查更新',
                    ),
                  ),
          ),
        ),
        ..._buildUpdateStatus(c),
      ],
    );
  }

  Future<String> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '未知';
    }
  }

  List<Widget> _buildUpdateStatus(AppColors c) {
    switch (_status) {
      case _UpdateStatus.idle:
        return const [];
      case _UpdateStatus.checking:
        return [
          LinearProgressIndicator(
            minHeight: 2,
            color: c.accent,
            backgroundColor: c.border,
          ),
        ];
      case _UpdateStatus.latest:
        return [Text('已是最新版本', style: TextStyle(color: c.text2, fontSize: 13))];
      case _UpdateStatus.available:
        final info = _info!;
        return [
          Text(
            '发现新版本 v${info.latestVersion}',
            style: TextStyle(
              color: c.accent,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (info.releaseNotes != null && info.releaseNotes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              info.releaseNotes!,
              style: TextStyle(color: c.text2, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.download, size: 18),
            label: const Text('下载并更新'),
            onPressed: _downloadAndInstall,
          ),
        ];
      case _UpdateStatus.error:
        return [
          Text(
            _error ?? '检查更新失败',
            style: TextStyle(color: c.text2, fontSize: 13),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _checkUpdate, child: const Text('重试')),
        ];
      case _UpdateStatus.downloading:
        return [
          Text('正在下载更新…', style: TextStyle(color: c.text2, fontSize: 13)),
          const SizedBox(height: 8),
          const LinearProgressIndicator(minHeight: 2),
        ];
    }
  }

  Future<void> _checkUpdate() async {
    setState(() => _status = _UpdateStatus.checking);
    try {
      final info = await fetchUpdateInfo();
      if (!mounted) return;
      if (info == null) {
        setState(() {
          _status = _UpdateStatus.error;
          _error = '无法获取更新信息，请检查网络或稍后重试';
        });
        return;
      }
      final current = await PackageInfo.fromPlatform();
      if (!mounted) return;
      if (isNewerVersion(info.latestVersion, current.version)) {
        setState(() {
          _status = _UpdateStatus.available;
          _info = info;
        });
      } else {
        setState(() => _status = _UpdateStatus.latest);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = _UpdateStatus.error;
        _error = '检查更新失败，请稍后重试';
      });
    }
  }

  Future<void> _downloadAndInstall() async {
    final info = _info;
    if (info == null) return;
    final url = updateUrlFor(info);
    if (url == null) {
      setState(() {
        _status = _UpdateStatus.error;
        _error = '当前平台暂无更新包';
      });
      return;
    }
    setState(() => _status = _UpdateStatus.downloading);
    try {
      final platform = defaultTargetPlatform == TargetPlatform.android
          ? 'android'
          : 'windows';
      final path = await downloadUpdate(url, platform: platform);
      if (!mounted) return;
      if (defaultTargetPlatform == TargetPlatform.android) {
        await installAndroidUpdate(path);
        setState(() => _status = _UpdateStatus.idle);
      } else {
        await installWindowsUpdate(path);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _UpdateStatus.error;
        _error = '更新失败：$e';
      });
    }
  }
}
