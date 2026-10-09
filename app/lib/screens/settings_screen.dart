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
    // 桌面侧栏嵌入时无需标题；手机端推入时保留返回箭头。
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      appBar: canPop ? AppBar(title: const Text('设置')) : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (!canPop) ...[
                Text('设置', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  '按你的习惯，调整阅读体验',
                  style: TextStyle(color: c.text2, fontSize: 13),
                ),
                const SizedBox(height: 28),
              ],
              Text(
                '服务器',
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
                child: _buildServerSection(c, serverSession),
              ),
              const SizedBox(height: 24),
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
                      '控制 App 整体配色：浅色、深色，或跟随系统自动切换',
                      style: TextStyle(color: c.text2, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final mode in ThemeMode.values)
                          ChoiceChip(
                            avatar: Icon(
                              switch (mode) {
                                ThemeMode.light => Icons.light_mode_outlined,
                                ThemeMode.dark => Icons.dark_mode_outlined,
                                ThemeMode.system =>
                                  Icons.brightness_auto_outlined,
                              },
                              size: 18,
                              color: themeMode == mode ? c.accent : c.text2,
                            ),
                            label: Text(switch (mode) {
                              ThemeMode.light => '浅色',
                              ThemeMode.dark => '深色',
                              ThemeMode.system => '跟随系统',
                            }),
                            selected: themeMode == mode,
                            showCheckmark: false,
                            selectedColor: c.accent.withValues(alpha: 0.12),
                            labelStyle: TextStyle(
                              color: themeMode == mode ? c.accent : c.text1,
                            ),
                            onSelected: (_) => ref
                                .read(themeModeProvider.notifier)
                                .setMode(mode),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '阅读',
                style: TextStyle(
                  color: c.text2,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: c.surface2,
                  borderRadius: BorderRadius.circular(kRadiusCard),
                  border: Border.all(color: c.border),
                ),
                child: SwitchListTile(
                  value: superResolutionDefault,
                  onChanged: _savingSuperResolution
                      ? null
                      : _saveSuperResolutionDefault,
                  title: Text(
                    '默认开启 2× 超分',
                    style: TextStyle(
                      color: c.text1,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    '阅读时先显示原图，后台增强当前页并提前处理后十页。可在阅读器临时关闭。',
                    style: TextStyle(color: c.text2, fontSize: 13),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
              if (defaultTargetPlatform == TargetPlatform.windows) ...[
                const SizedBox(height: 24),
                Text(
                  '窗口',
                  style: TextStyle(
                    color: c.text2,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: c.surface2,
                    borderRadius: BorderRadius.circular(kRadiusCard),
                    border: Border.all(color: c.border),
                  ),
                  child: SwitchListTile(
                    value: closeToTray,
                    onChanged: (value) => ref
                        .read(closeToTrayProvider.notifier)
                        .setEnabled(value),
                    title: Text(
                      '关闭窗口时最小化到系统托盘',
                      style: TextStyle(
                        color: c.text1,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      '开启：点右上角 X 退到系统托盘继续运行；关闭：点右上角 X 直接退出',
                      style: TextStyle(color: c.text2, fontSize: 13),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                '关于',
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
                child: _buildAboutSection(c),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveSuperResolutionDefault(bool value) async {
    setState(() => _savingSuperResolution = true);
    try {
      await ref.read(superResolutionDefaultProvider.notifier).setEnabled(value);
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
          '漫画服务器地址',
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
        TextField(
          controller: _serverController,
          keyboardType: TextInputType.url,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: '服务器地址',
            hintText: 'http://192.168.1.100:8888',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
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
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comic',
                    style: TextStyle(
                      color: c.text1,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FutureBuilder<String>(
                    future: _loadVersion(),
                    builder: (context, snap) => Text(
                      '当前版本 v${snap.data ?? '…'}',
                      style: TextStyle(color: c.text2, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            if (!kIsWeb)
              FilledButton.tonal(
                onPressed:
                    _status == _UpdateStatus.checking ||
                        _status == _UpdateStatus.downloading
                    ? null
                    : _checkUpdate,
                child: Text(
                  _status == _UpdateStatus.checking ? '检查中…' : '检查更新',
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
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
