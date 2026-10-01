import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/widgets/app_section_header.dart';

/// 首页占位页：后续展示车辆状态、续航、最近充电等信息。
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EV Tool')),
      body: ListView(
        children: const [
          SizedBox(height: 8),
          AppSectionHeader(title: '首页', subtitle: '车辆状态与快捷入口（占位）'),
        ],
      ),
    );
  }
}
