import 'package:flutter/material.dart';

import 'package:ev_tool_app/features/profile/presentation/legal_texts.dart';
import 'package:ev_tool_app/features/profile/presentation/widgets/legal_doc_page.dart';

/// 隐私政策页（子页，从「关于应用 → 隐私政策」进入）。
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocPage(title: '隐私政策', sections: privacySections);
  }
}
