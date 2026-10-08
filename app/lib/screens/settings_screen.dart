import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/update_info.dart';
import '../providers/settings_provider.dart';
import '../services/update_service.dart';
import '../theme.dart';

enum _UpdateStatus { idle, checking, latest, available, error, downloading }

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  _UpdateStatus _status = _UpdateStatus.idle;
  UpdateInfo? _info;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final closeToTray = ref.watch(closeToTrayProvider);
    final c = context.appColors;
    // 桌面侧栏嵌入时无需标题；手机端推入时保留返回箭头。
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      appBar: canPop ? AppBar() : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    expandedInsets: EdgeInsets.zero,
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined),
                        label: Text('浅色'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined),
                        label: Text('深色'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_outlined),
                        label: Text('跟随系统'),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (selection) => ref
                        .read(themeModeProvider.notifier)
                        .setMode(selection.first),
                  ),
                ),
              ],
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
                onChanged: (value) =>
                    ref.read(closeToTrayProvider.notifier).setEnabled(value),
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
    );
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
