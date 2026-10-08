import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import '../config.dart';
import '../models/update_info.dart';

/// 拉取更新清单；清单不存在或解析失败返回 null。
Future<UpdateInfo?> fetchUpdateInfo() async {
  final res = await http
      .get(Uri.parse(kUpdateManifestUrl))
      .timeout(requestTimeout);
  if (res.statusCode != 200) return null;
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  final info = UpdateInfo.fromJson(data);
  if (info.latestVersion.isEmpty) return null;
  return info;
}

/// 数字段版本比较（忽略 build/prerelease）：latest 高于 current 返回 true。
bool isNewerVersion(String latest, String current) {
  final l = _segments(latest);
  final c = _segments(current);
  for (var i = 0; i < 3; i++) {
    final a = i < l.length ? l[i] : 0;
    final b = i < c.length ? c[i] : 0;
    if (a != b) return a > b;
  }
  return false;
}

List<int> _segments(String v) {
  final main = v.split('+').first.split('-').first;
  return main.split('.').map((s) => int.tryParse(s) ?? 0).toList();
}

/// 下载更新文件到系统临时目录，返回本地路径。
Future<String> downloadUpdate(String url, {required String platform}) async {
  final res = await http
      .get(Uri.parse(url))
      .timeout(const Duration(minutes: 10));
  if (res.statusCode != 200) {
    throw Exception('下载失败（HTTP ${res.statusCode}）');
  }
  final ext = platform == 'android' ? 'apk' : 'exe';
  final file = File('${Directory.systemTemp.path}/comic-update.$ext');
  await file.writeAsBytes(res.bodyBytes, flush: true);
  return file.path;
}

/// Windows：静默启动安装器并退出 App（安装器负责替换文件）。
Future<void> installWindowsUpdate(String installerPath) async {
  await Process.start(installerPath, const [
    '/VERYSILENT',
    '/SUPPRESSMSGBOXES',
    '/NORESTART',
  ]);
  await Future<void>.delayed(const Duration(milliseconds: 800));
  exit(0);
}

/// Android：唤起系统安装器安装 APK。
Future<void> installAndroidUpdate(String apkPath) async {
  final result = await OpenFilex.open(
    apkPath,
    type: 'application/vnd.android.package-archive',
  );
  if (result.type != ResultType.done) {
    throw Exception('无法打开系统安装器：${result.message}');
  }
}

/// 当前平台的下载地址（Windows/Android）。
String? updateUrlFor(UpdateInfo info) {
  if (kIsWeb) return null;
  return defaultTargetPlatform == TargetPlatform.android
      ? info.androidUrl
      : info.windowsUrl;
}
