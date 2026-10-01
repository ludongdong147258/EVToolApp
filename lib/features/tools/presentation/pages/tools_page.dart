import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/widgets/app_section_header.dart';

/// 工具占位页：后续提供续航计算、充电费用估算等工具集合。
class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tools')),
      body: ListView(
        children: const [
          SizedBox(height: 8),
          AppSectionHeader(title: '工具', subtitle: '车辆实用工具集合（占位）'),
        ],
      ),
    );
  }
}
