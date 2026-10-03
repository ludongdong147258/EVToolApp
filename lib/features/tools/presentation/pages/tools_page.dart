import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/routing/route_names.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/widgets/main_shell.dart';
import 'package:ev_tool_app/features/tools/presentation/providers/tools_provider.dart';

/// 工具入口（按 group 分组渲染；最近使用的工具额外置顶一组）。
class ToolEntry {
  const ToolEntry({
    required this.id,
    required this.title,
    required this.desc,
    required this.icon,
    required this.route,
  });

  final String id;
  final String title;
  final String desc;
  final IconData icon;
  final String route;
}

const List<ToolEntry> toolEntries = <ToolEntry>[
  ToolEntry(
    id: 'range-estimate',
    title: 'Range Estimate',
    desc: 'Estimate remaining range from battery capacity and consumption.',
    icon: Icons.battery_charging_full,
    route: RouteNames.rangeCalc,
  ),
  ToolEntry(
    id: 'fuel-vs-ev',
    title: 'Fuel vs EV Cost',
    desc: 'Compare annual running costs of gas vs. electric cars.',
    icon: Icons.calculate_outlined,
    route: RouteNames.fuelEvCalc,
  ),
  ToolEntry(
    id: 'peak-valley',
    title: 'Time-of-Use Savings',
    desc: 'Calculate charging costs and savings with time-of-use rates.',
    icon: Icons.bolt_rounded,
    route: RouteNames.peakValleyCalc,
  ),
  ToolEntry(
    id: 'home-charger',
    title: 'Home Charger Setup',
    desc: 'Estimate installation and running costs of a home charger.',
    icon: Icons.ev_station,
    route: RouteNames.homeChargerCalc,
  ),
  ToolEntry(
    id: 'nearby-stations',
    title: 'Nearby Stations',
    desc: 'Find charging stations nearby and navigate in one tap.',
    icon: Icons.map_outlined,
    route: RouteNames.nearbyStations,
  ),
  ToolEntry(
    id: 'inspection-memo',
    title: 'Service & Inspection Memo',
    desc: 'Track inspection and service dates by registration and mileage.',
    icon: Icons.verified_user_outlined,
    route: RouteNames.inspectionMemo,
  ),
  ToolEntry(
    id: 'mod-compliance',
    title: 'Mod Compliance Check',
    desc: 'Quick check on legality, filing, and risks of common mods.',
    icon: Icons.tune,
    route: RouteNames.modificationCompliance,
  ),
  ToolEntry(
    id: 'warranty-handbook',
    title: 'EV Warranty Handbook',
    desc: 'EV warranty, lifetime coverage, and transfer rules by brand.',
    icon: Icons.menu_book_outlined,
    route: RouteNames.warrantyHandbook,
  ),
  ToolEntry(
    id: 'equipment',
    title: 'Charging Gear',
    desc: 'Buying guide for chargers, portable cables, and emergency gear.',
    icon: Icons.shopping_bag_outlined,
    route: RouteNames.equipment,
  ),
];

/// 工具分组：标题 + 该组工具 id 列表。
class ToolGroup {
  const ToolGroup({required this.title, required this.toolIds});

  final String title;
  final List<String> toolIds;
}

const List<ToolGroup> toolGroups = <ToolGroup>[
  ToolGroup(
    title: 'Savings Calculators',
    toolIds: <String>[
      'range-estimate',
      'fuel-vs-ev',
      'peak-valley',
      'home-charger',
    ],
  ),
  ToolGroup(title: 'Maps', toolIds: <String>['nearby-stations']),
  ToolGroup(title: 'Shopping', toolIds: <String>['equipment']),
  ToolGroup(
    title: 'Memos & Handbooks',
    toolIds: <String>['inspection-memo', 'mod-compliance', 'warranty-handbook'],
  ),
];

ToolEntry? findTool(String id) {
  for (final tool in toolEntries) {
    if (tool.id == id) return tool;
  }
  return null;
}

/// id 列表 → 工具入口（配置下线后自动消失）。
List<ToolEntry> resolveTools(List<String> ids) {
  return [
    for (final id in ids)
      for (final tool in toolEntries)
        if (tool.id == id) tool,
  ];
}

/// 实用工具页（Tab 2）：分组工具入口 + 最近使用置顶。
class ToolsPage extends ConsumerStatefulWidget {
  const ToolsPage({super.key});

  @override
  ConsumerState<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends ConsumerState<ToolsPage> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 从计算器子页返回时刷新最近使用（保存 → 返回 → 重读闭环）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(recentToolsProvider.notifier).reload();
    });
  }

  void _handleToolTap(ToolEntry tool) {
    ref.read(recentToolsProvider.notifier).track(tool.id);
    context.push(tool.route);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final recentIds = ref.watch(recentToolsProvider);
    /* 最近使用组只含仍存在的工具（配置下线后自动消失），最多 3 个 */
    final recentTools = resolveTools(recentIds.take(3).toList());

    return Scaffold(
      appBar: AppBar(title: const Text('Tools')),
      body: ListView(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: kBottomNavScrollPadding,
        ),
        children: [
          Text(
            'Explore handy tools to get more out of your EV.',
            style: TextStyle(fontSize: 13, color: palette.textSecondary),
          ),
          const SizedBox(height: 12),
          if (recentTools.isNotEmpty) ...[
            _ToolGroup(
              title: 'Recently used',
              tools: recentTools,
              onTap: _handleToolTap,
            ),
            const SizedBox(height: 16),
          ],
          for (final group in toolGroups) ...[
            _ToolGroup(
              title: group.title,
              tools: resolveTools(group.toolIds),
              onTap: _handleToolTap,
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

/// 单个分组：小标题 + 2 列网格。
class _ToolGroup extends StatelessWidget {
  const _ToolGroup({required this.title, required this.tools, this.onTap});

  final String title;
  final List<ToolEntry> tools;
  final void Function(ToolEntry tool)? onTap;

  @override
  Widget build(BuildContext context) {
    if (tools.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.4,
          children: [
            for (final tool in tools)
              _ToolCard(tool: tool, onTap: () => onTap?.call(tool)),
          ],
        ),
      ],
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.tool, this.onTap});

  final ToolEntry tool;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      borderRadius: BorderRadius.circular(AppColors.radiusLg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.surfaceCard,
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: palette.secondaryContainer,
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
              ),
              child: Icon(tool.icon, size: 16, color: palette.primaryContainer),
            ),
            const SizedBox(height: 10),
            Text(
              tool.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Text(
                tool.desc,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: palette.textHint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
