import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/update_info.dart';
import '../services/preference_writes.dart';
import '../services/update_service.dart';

const updateCacheKey = 'appUpdateManifest.v1';

class AppUpdateState {
  const AppUpdateState({
    this.info,
    this.currentVersion,
    this.checking = false,
    this.installing = false,
    this.startupPending = false,
    this.dismissed = false,
    this.message,
  });

  final UpdateInfo? info;
  final String? currentVersion;
  final bool checking;
  final bool installing;
  final bool startupPending;
  final bool dismissed;
  final String? message;

  bool get required =>
      info != null &&
      currentVersion != null &&
      requiresUpdate(info!, currentVersion!);
  bool get available =>
      info != null &&
      currentVersion != null &&
      updateUrlFor(info!) != null &&
      compareVersions(info!.latestVersion, currentVersion!) > 0;
}

final appUpdateProvider = NotifierProvider<AppUpdateNotifier, AppUpdateState>(
  AppUpdateNotifier.new,
);

class AppUpdateNotifier extends Notifier<AppUpdateState> {
  AppUpdateNotifier({
    Future<UpdateInfo?> Function()? fetch,
    Future<String> Function()? version,
  }) : _fetch = fetch ?? fetchUpdateInfo,
       _version = version ?? _loadVersion;

  final Future<UpdateInfo?> Function() _fetch;
  final Future<String> Function() _version;

  static Future<String> _loadVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  @override
  AppUpdateState build() =>
      AppUpdateState(startupPending: kReleaseMode && supportsAppUpdates);

  Future<void> check() async {
    if (!supportsAppUpdates || state.checking || state.installing) return;
    state = AppUpdateState(
      info: state.info,
      currentVersion: state.currentVersion,
      checking: true,
      startupPending: state.startupPending,
      dismissed: state.dismissed,
    );
    try {
      final current = await _version();
      stableVersionParts(current);
      var info = state.info;
      if (info == null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final cached = prefs.getString(updateCacheKey);
          if (cached != null) {
            info = UpdateInfo.fromJson(
              jsonDecode(cached) as Map<String, dynamic>,
            );
          }
        } catch (_) {
          // 缓存损坏不阻止在线检查。
        }
      }
      state = AppUpdateState(
        info: info,
        currentVersion: current,
        checking: true,
        startupPending: state.startupPending,
        dismissed: state.dismissed,
      );
      final fetched = await _fetch();
      if (fetched == null || updateUrlFor(fetched) == null) {
        throw const FormatException('当前平台暂无更新信息');
      }
      // 所有入口（包含测试或缓存）均使用同一个清单验证。
      final validated = UpdateInfo.fromJson(fetched.toJson());
      String? message;
      try {
        final prefs = await SharedPreferences.getInstance();
        final saved = await writePreference(
          prefs,
          () => prefs.setString(updateCacheKey, jsonEncode(validated.toJson())),
        );
        if (!saved) throw StateError('保存失败');
      } catch (_) {
        message = '更新要求未能保存，下次启动需要联网重新检查';
      }
      final changed = state.info?.latestVersion != validated.latestVersion;
      state = AppUpdateState(
        info: validated,
        currentVersion: current,
        dismissed: changed ? false : state.dismissed,
        message: message,
      );
    } catch (_) {
      state = AppUpdateState(
        info: state.info,
        currentVersion: state.currentVersion,
        dismissed: state.dismissed,
        message: '检查更新失败，请检查网络后重试${state.required ? '；仍需更新后使用' : ''}',
      );
    }
  }

  void dismiss() {
    if (state.required) return;
    state = AppUpdateState(
      info: state.info,
      currentVersion: state.currentVersion,
      dismissed: true,
      message: state.message,
    );
  }

  Future<void> install() async {
    final info = state.info;
    if (info == null || state.checking || state.installing) return;
    final url = updateUrlFor(info);
    if (url == null) return;
    state = AppUpdateState(
      info: info,
      currentVersion: state.currentVersion,
      installing: true,
      dismissed: state.dismissed,
    );
    String message;
    try {
      final android = defaultTargetPlatform == TargetPlatform.android;
      final path = await downloadUpdate(
        url,
        platform: android ? 'android' : 'windows',
      );
      if (android) {
        await installAndroidUpdate(path);
      } else {
        await installWindowsUpdate(path);
      }
      message = '已打开安装器；请完成安装，更新后重新打开应用';
    } catch (_) {
      message = '下载安装失败，请重试';
    }
    state = AppUpdateState(
      info: info,
      currentVersion: state.currentVersion,
      dismissed: state.dismissed,
      message: message,
    );
  }
}
