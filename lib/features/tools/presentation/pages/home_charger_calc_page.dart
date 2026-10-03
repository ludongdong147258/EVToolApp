import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/domain/date_utils.dart';
import 'package:ev_tool_app/core/domain/home_charger_calc.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/widgets/app_primary_button.dart';
import 'package:ev_tool_app/core/widgets/app_sheet.dart';
import 'package:ev_tool_app/core/widgets/app_toast.dart';
import 'package:ev_tool_app/core/widgets/empty_state.dart';
import 'package:ev_tool_app/features/tools/presentation/providers/tools_provider.dart';
import 'package:ev_tool_app/features/tools/presentation/widgets/calc_form_widgets.dart';
import 'package:ev_tool_app/features/tools/presentation/widgets/home_charger_widgets.dart';

/* 安装位置（互斥单选，价格文案取自 conditionSurcharges） */
const List<Map<String, Object>> _spotOptions = [
  {
    'id': 'undergroundGarage',
    'title': '地下车库',
    'subtitle': '走线增项 +¥200',
    'icon': Icons.directions_car,
  },
  {
    'id': 'groundSpot',
    'title': '地面私有车位',
    'subtitle': '一般无需增项',
    'icon': Icons.landscape,
  },
];

/* 环境条件开关（仅记录状态，第 3 步统一计价） */
const Map<String, Map<String, Object>> _toggleOptions = {
  'wallDrilling': {
    'title': '需要穿墙打孔',
    'subtitle': '走线需穿过承重或非承重墙体',
    'icon': Icons.build_outlined,
    'defaultOn': false,
  },
  'protectionBox': {
    'title': '需安装保护箱',
    'subtitle': '户外或公共区域防止破坏及恶劣天气',
    'icon': Icons.verified_user_outlined,
    'defaultOn': true,
  },
};

/* 环境增项明细文案（key 与 conditionSurcharges 对应） */
const Map<String, String> _surchargeLabels = {
  'undergroundGarage': '地下车库走线难度',
  'wallDrilling': '穿墙打孔施工',
  'protectionBox': '室外防护箱配置',
};

/* 「查看所需文件」弹层内容：私桩报装通用材料清单 */
const List<Map<String, String>> _requiredDocuments = [
  {'name': '身份证原件', 'desc': '车主本人有效身份证件'},
  {'name': '车位产权/使用证明', 'desc': '产权证或租赁合同（一年及以上）'},
  {'name': '物业施工许可', 'desc': '物业出具的充电桩安装同意书'},
  {'name': '购车证明', 'desc': '购车发票或车辆行驶证'},
  {'name': '电表申请信息', 'desc': '向电网公司报装需提供的用电地址'},
];

/// 私桩安装测算页（移植小程序 home-charger-calc，3 步向导）。
class HomeChargerCalcPage extends ConsumerStatefulWidget {
  const HomeChargerCalcPage({super.key});

  @override
  ConsumerState<HomeChargerCalcPage> createState() =>
      _HomeChargerCalcPageState();
}

class _HomeChargerCalcPageState extends ConsumerState<HomeChargerCalcPage> {
  int _step = 1;
  int _cableLength = cableDefault;
  String _powerId = defaultPowerId;
  String _spot = 'undergroundGarage';
  Map<String, bool> _conditions = {
    for (final entry in _toggleOptions.entries)
      entry.key: entry.value['defaultOn'] == true,
  };
  bool _isSaving = false;

  /* spot 单选 + 布尔开关 → lib 需要的环境条件布尔映射 */
  Map<String, bool> get _builtConditions => {
    'undergroundGarage': _spot == 'undergroundGarage',
    'groundSpot': _spot == 'groundSpot',
    ..._conditions,
  };

  InstallEstimate? get _estimate => calcInstallEstimate(
    HomeChargerInputs(
      cableLength: _cableLength,
      powerId: _powerId,
      conditions: _builtConditions,
    ),
  );

  void _goToStep(int step) {
    setState(() => _step = step.clamp(1, totalSteps));
  }

  Future<void> _saveResult() async {
    if (_step != totalSteps || _isSaving) return;
    final estimate = _estimate;
    if (estimate == null) {
      showAppToast(context, '测算数据异常，请返回检查');
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref
          .read(estimatesProvider.notifier)
          .save(
            cableLength: _cableLength,
            powerId: _powerId,
            spot: _spot,
            conditions: _builtConditions,
            estimate: estimate,
          );
      if (!mounted) return;
      showSuccessToast(context, message: '已保存');
    } on Exception {
      if (mounted) showAppToast(context, '保存失败，请重试');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _removeEstimate(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除测算'),
        content: const Text('确定删除这条测算记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: dialogContext.palette.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(estimatesProvider.notifier).remove(id);
    } on Exception {
      if (mounted) showAppToast(context, '删除失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final estimates = ref.watch(estimatesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('私桩安装测算')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          ProgressCard(step: _step),
          if (estimates.isNotEmpty) ...[
            const SizedBox(height: 12),
            HistoryEntry(
              count: estimates.length,
              onTap: () => _showHistorySheet(estimates),
            ),
          ],
          const SizedBox(height: 12),
          if (_step == 1) _buildStep1(),
          if (_step == 2) _buildStep2(),
          if (_step == 3) _buildStep3(),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    final palette = context.palette;
    final estimate = _estimate;

    return Column(
      children: [
        CalcCard(
          title: '线缆长度 (米)',
          icon: Icons.ev_station,
          iconColor: palette.primary,
          subtitle: '基础安装包通常包含$includedCableM米线缆，超出部分将额外计费。',
          child: Column(
            children: [
              Text(
                '$_cableLength',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: palette.onSurface,
                ),
              ),
              CalcSlider(
                value: _cableLength.toDouble(),
                min: cableMin.toDouble(),
                max: cableMax.toDouble(),
                divisions: (cableMax - cableMin) ~/ cableStep,
                onChanged: (value) =>
                    setState(() => _cableLength = value.round()),
              ),
              const SliderScaleRow(
                start: '${cableMin}m',
                end: '${cableMax ~/ 2}m · ${cableMax}m',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CalcCard(
          title: '充电功率',
          icon: Icons.bolt_rounded,
          iconColor: palette.info,
          subtitle: '选择适合您车型的充电桩功率，不同功率需匹配不同规格线缆。',
          child: Column(
            children: [
              for (final option in powerOptions)
                OptionCard(
                  isSelected: option.id == _powerId,
                  onTap: () => setState(() => _powerId = option.id),
                  child: Column(
                    children: [
                      Text(
                        option.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: palette.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        option.voltage,
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '¥ ${formatAmount(option.basePrice)} 起',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: palette.primaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TotalCard(
          label: '当前预估总额',
          total: estimate?.total ?? 0,
          lines: [
            ('基础安装包 (含$includedCableM米)', estimate?.basePrice ?? 0),
            if (estimate != null && estimate.extraCableLength > 0)
              ('超长线缆 (${estimate.extraCableLength}米)', estimate.extraCableCost),
          ],
          hint: '环境增项（车库/打孔/防护箱）将在下一步选择后计入',
        ),
        const SizedBox(height: 12),
        AppPrimaryButton(text: '下一步', onTap: () => _goToStep(2)),
      ],
    );
  }

  Widget _buildStep2() {
    final palette = context.palette;
    final surchargeTotal = _estimate?.surchargeTotal ?? 0;

    return Column(
      children: [
        CalcCard(
          title: '安装位置与条件',
          icon: Icons.home_outlined,
          iconColor: palette.primary,
          child: Column(
            children: [
              for (final option in _spotOptions)
                OptionCard(
                  isSelected: option['id'] == _spot,
                  onTap: () => setState(() => _spot = option['id'] as String),
                  child: Column(
                    children: [
                      Icon(
                        option['icon'] as IconData,
                        size: 20,
                        color: palette.info,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        option['title'] as String,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: palette.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        option['subtitle'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              for (final entry in _toggleOptions.entries)
                ConditionRow(
                  title: entry.value['title'] as String,
                  subtitle: entry.value['subtitle'] as String,
                  icon: entry.value['icon'] as IconData,
                  price: conditionSurcharges[entry.key] ?? 0,
                  value: _conditions[entry.key] ?? false,
                  onChanged: (isOn) => setState(() {
                    _conditions = {..._conditions, entry.key: isOn};
                  }),
                ),
              const Divider(height: 24, color: AppColors.divider),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '环境增项合计',
                    style: TextStyle(
                      fontSize: 13,
                      color: palette.textSecondary,
                    ),
                  ),
                  Text(
                    '¥ ${formatAmount(surchargeTotal)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: palette.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppPrimaryButton(
                text: '上一步',
                backgroundColor: palette.surfaceContainerLow,
                textColor: palette.onSurfaceVariant,
                onTap: () => _goToStep(1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppPrimaryButton(text: '下一步', onTap: () => _goToStep(3)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3() {
    final palette = context.palette;
    final estimate = _estimate;
    if (estimate == null) {
      return const Card(
        child: EmptyState(
          icon: Icons.error_outline,
          title: '测算数据异常',
          subtitle: '请返回上一步检查安装详情',
          compact: true,
        ),
      );
    }

    return Column(
      children: [
        CalcCard(
          title: '费用明细',
          icon: Icons.payments_outlined,
          iconColor: palette.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DetailLine(
                label: '基础安装包',
                value: '¥ ${formatAmount(estimate.basePrice)}',
              ),
              const SizedBox(height: 2),
              Text(
                '含$includedCableM标准线缆及基础人工费',
                style: TextStyle(fontSize: 11, color: palette.textHint),
              ),
              if (estimate.extraCableLength > 0) ...[
                const SizedBox(height: 10),
                DetailLine(
                  label: '超长线缆 (${estimate.extraCableLength}米)',
                  value: '¥ ${formatAmount(estimate.extraCableCost)}',
                ),
              ],
              const SizedBox(height: 10),
              DetailLine(
                label: '环境增项',
                value: '¥ ${formatAmount(estimate.surchargeTotal)}',
              ),
              const SizedBox(height: 4),
              if (estimate.surcharges.isEmpty)
                Text(
                  '无增项',
                  style: TextStyle(fontSize: 11, color: palette.textHint),
                )
              else
                for (final item in estimate.surcharges)
                  Text(
                    '• ${_surchargeLabels[item.id] ?? item.id}'
                    ' +¥${formatAmount(item.price)}',
                    style: TextStyle(fontSize: 11, color: palette.textHint),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TotalCard(label: '预估总费用 (元)', total: estimate.total),
        const SizedBox(height: 12),
        AppPrimaryButton(
          text: _isSaving ? '保存中…' : '保存预估结果',
          onTap: _isSaving ? null : _saveResult,
        ),
        const SizedBox(height: 12),
        AppPrimaryButton(
          text: '查看所需文件',
          backgroundColor: Colors.transparent,
          textColor: palette.primaryContainer,
          onTap: _showFileSheet,
        ),
        const SizedBox(height: 8),
        const CalcDisclaimer(
          '本页面提供的费用明细仅为系统预估，最终价格以实地勘测后出具的正式报价单为准。如有疑问请联系客服。',
        ),
      ],
    );
  }

  void _showFileSheet() {
    showAppSheet(
      context: context,
      title: '安装所需文件',
      builder: (sheetContext) {
        final palette = sheetContext.palette;
        return AppSheetScrollBody(
          child: Column(
            children: [
              for (final doc in _requiredDocuments)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.task_alt_outlined,
                        size: 16,
                        color: palette.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc['name'] ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: palette.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              doc['desc'] ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.textHint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showHistorySheet(List<StoredEstimate> estimates) {
    showAppSheet(
      context: context,
      title: '已保存的测算',
      builder: (sheetContext) {
        final palette = sheetContext.palette;
        return AppSheetScrollBody(
          child: Column(
            children: [
              for (final item in estimates)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '¥ ${formatAmount(item.estimate.total)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: palette.onSurface,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  formatTimestampDate(item.savedAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: palette.textHint,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${powerLabelOf(item.powerId)} · 线缆 '
                              '${item.cableLength} 米'
                              '${item.estimate.surchargeTotal > 0 ? ' · 增项 ¥${formatAmount(item.estimate.surchargeTotal)}' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: palette.error,
                        ),
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _removeEstimate(item.id);
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

String powerLabelOf(String powerId) {
  for (final option in powerOptions) {
    if (option.id == powerId) return option.label;
  }
  return powerId;
}
