import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/constants/app_constants.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        children: const [
          SizedBox(height: 24),
          ListTile(title: Text('应用名称'), trailing: Text(AppConstants.appName)),
          ListTile(title: Text('版本'), trailing: Text(AppConstants.appVersion)),
        ],
      ),
    );
  }
}
