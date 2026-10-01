import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/widgets/app_section_header.dart';

/// 充电占位页：后续展示充电站地图/列表、充电进度等。
class ChargingPage extends StatelessWidget {
  const ChargingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Charging')),
      body: ListView(
        children: const [
          SizedBox(height: 8),
          AppSectionHeader(title: '充电', subtitle: '充电站与充电管理（占位）'),
        ],
      ),
    );
  }
}
