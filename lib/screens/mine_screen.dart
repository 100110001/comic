import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class MineScreen extends StatefulWidget {
  const MineScreen({super.key});

  @override
  State<MineScreen> createState() => _MineScreenState();
}

class _MineScreenState extends State<MineScreen> {
  String _result = '点击下方按钮测试接口';
  bool _loading = false;
  int? _status;
  int? _ms;

  static const _endpoints = [
    '/api/health',
    '/api/comics?pageOffset=1&pageSize=5',
    '/api/comics/1',
    '/api/chapters/1/images',
  ];

  Future<void> _test(String path) async {
    setState(() {
      _loading = true;
      _result = '请求中…';
      _status = null;
      _ms = null;
    });

    final url = '$baseUrl$path';
    final sw = Stopwatch()..start();

    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      sw.stop();
      String body;
      try {
        body = const JsonEncoder.withIndent('  ').convert(jsonDecode(res.body));
      } catch (_) {
        body = res.body;
      }
      setState(() {
        _status = res.statusCode;
        _ms = sw.elapsedMilliseconds;
        _result = body;
      });
    } catch (e) {
      sw.stop();
      setState(() {
        _status = 0;
        _ms = sw.elapsedMilliseconds;
        _result = e.toString();
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Color get _statusColor {
    if (_status == null) return Colors.grey;
    if (_status == 0) return Colors.red;
    if (_status! < 300) return Colors.green;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('接口测试'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              baseUrl,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // 端点按钮
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _endpoints
                  .map(
                    (p) => ElevatedButton(
                      onPressed: _loading ? null : () => _test(p),
                      child: Text(
                        p.split('?')[0],
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const Divider(),
          // 状态栏
          if (_status != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _status == 0 ? 'ERROR' : '$_status',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_ms}ms',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          // 响应内容
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                      _result,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
