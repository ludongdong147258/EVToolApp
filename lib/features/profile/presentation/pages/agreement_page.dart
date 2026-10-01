import 'package:flutter/material.dart';

import 'package:ev_tool_app/features/profile/presentation/legal_texts.dart';
import 'package:ev_tool_app/features/profile/presentation/widgets/legal_doc_page.dart';

/// 用户协议页（子页，从「关于应用 → 用户协议」进入）。
class AgreementPage extends StatelessWidget {
  const AgreementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocPage(title: '用户协议', sections: agreementSections);
  }
}
