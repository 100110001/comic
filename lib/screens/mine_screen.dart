import 'package:flutter/material.dart';

class MineScreen extends StatelessWidget {
  const MineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161b22),
        title: const Text('我的', style: TextStyle(color: Colors.white)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFF21262d)),
        ),
      ),
      body: const Center(
        child: Text('我的', style: TextStyle(color: Color(0xFF8b949e))),
      ),
    );
  }
}
