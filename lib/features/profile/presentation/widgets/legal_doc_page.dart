import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/features/profile/presentation/legal_texts.dart';

/// 协议/政策正文页（用户协议与隐私政策共用）。
///
/// 更新日期置顶 + 章节标题与段落列表，文案见 legal_texts.dart。
class LegalDocPage extends StatelessWidget {
  const LegalDocPage({super.key, required this.title, required this.sections});

  final String title;
  final List<LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Last updated: $legalUpdatedAt',
                    style: TextStyle(fontSize: 12, color: palette.textHint),
                  ),
                  for (final section in sections) ...[
                    const SizedBox(height: 18),
                    Text(
                      section.title,
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    for (final paragraph in section.paragraphs) ...[
                      const SizedBox(height: 8),
                      Text(
                        paragraph,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: palette.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
