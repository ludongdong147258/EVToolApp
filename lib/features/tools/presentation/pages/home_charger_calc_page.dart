import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/domain/date_utils.dart';
import 'package:ev_tool_app/core/domain/numbers.dart';
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
    'title': 'Underground garage',
    'subtitle': 'Extra wiring +\$200',
    'icon': Icons.directions_car,
  },
  {
    'id': 'groundSpot',
    'title': 'Ground private spot',
    'subtitle': 'Usually no extras',
    'icon': Icons.landscape,
  },
];

/* 环境条件开关（仅记录状态，第 3 步统一计价） */
const Map<String, Map<String, Object>> _toggleOptions = {
  'wallDrilling': {
    'title': 'Wall drilling needed',
    'subtitle': 'Cable routing must pass through walls',
    'icon': Icons.build_outlined,
    'defaultOn': false,
  },
  'protectionBox': {
    'title': 'Install protection box',
    'subtitle': 'Protects outdoor installs from damage and weather',
    'icon': Icons.verified_user_outlined,
    'defaultOn': true,
  },
};

/* 环境增项明细文案（key 与 conditionSurcharges 对应） */
const Map<String, String> _surchargeLabels = {
  'undergroundGarage': 'Underground garage wiring',
  'wallDrilling': 'Wall drilling',
  'protectionBox': 'Outdoor protection box',
};

/* 「查看所需文件」弹层内容：私桩报装通用材料清单 */
const List<Map<String, String>> _requiredDocuments = [
  {'name': "Owner's ID", 'desc': 'Valid ID of the vehicle owner'},
  {
    'name': 'Parking spot proof',
    'desc': 'Property deed or lease (1 year or longer)',
  },
  {
    'name': 'Property approval',
    'desc': 'Written consent from property management',
  },
  {
    'name': 'Proof of purchase',
    'desc': 'Purchase invoice or vehicle registration',
  },
  {
    'name': 'Meter application info',
    'desc': 'Service address required by the grid company',
  },
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
      showAppToast(context, 'Something went wrong. Please go back and check.');
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
      showSuccessToast(context, message: 'Saved');
    } on Exception {
      if (mounted) showAppToast(context, 'Failed to save. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _removeEstimate(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete estimate'),
        content: const Text('Delete this saved estimate?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: dialogContext.palette.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(estimatesProvider.notifier).remove(id);
    } on Exception {
      if (mounted) showAppToast(context, 'Failed to delete. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final estimates = ref.watch(estimatesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Home Charger Setup')),
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
          title: 'Cable length (m)',
          icon: Icons.ev_station,
          iconColor: palette.primary,
          subtitle:
              'The base package includes ${includedCableM}m of cable; extra length is billed separately.',
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
          title: 'Charging power',
          icon: Icons.bolt_rounded,
          iconColor: palette.info,
          subtitle:
              'Pick a power level that suits your EV; higher power needs heavier cable.',
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
                        'from ${formatMoney(option.basePrice)}',
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
          label: 'Current estimate',
          total: estimate?.total ?? 0,
          lines: [
            (
              'Base package (incl. ${includedCableM}m)',
              estimate?.basePrice ?? 0,
            ),
            if (estimate != null && estimate.extraCableLength > 0)
              (
                'Extra cable (${estimate.extraCableLength}m)',
                estimate.extraCableCost,
              ),
          ],
          hint:
              'Site extras (garage, drilling, protection box) are added in the next step',
        ),
        const SizedBox(height: 12),
        AppPrimaryButton(text: 'Next', onTap: () => _goToStep(2)),
      ],
    );
  }

  Widget _buildStep2() {
    final palette = context.palette;
    final surchargeTotal = _estimate?.surchargeTotal ?? 0;

    return Column(
      children: [
        CalcCard(
          title: 'Location & conditions',
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
                    'Extras subtotal',
                    style: TextStyle(
                      fontSize: 13,
                      color: palette.textSecondary,
                    ),
                  ),
                  Text(
                    formatMoney(surchargeTotal),
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
                text: 'Back',
                backgroundColor: palette.surfaceContainerLow,
                textColor: palette.onSurfaceVariant,
                onTap: () => _goToStep(1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppPrimaryButton(text: 'Next', onTap: () => _goToStep(3)),
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
          title: 'Estimate unavailable',
          subtitle: 'Please go back and check the installation details',
          compact: true,
        ),
      );
    }

    return Column(
      children: [
        CalcCard(
          title: 'Cost breakdown',
          icon: Icons.payments_outlined,
          iconColor: palette.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DetailLine(
                label: 'Base package',
                value: formatMoney(estimate.basePrice),
              ),
              const SizedBox(height: 2),
              Text(
                'Includes ${includedCableM}m standard cable and basic labor',
                style: TextStyle(fontSize: 11, color: palette.textHint),
              ),
              if (estimate.extraCableLength > 0) ...[
                const SizedBox(height: 10),
                DetailLine(
                  label: 'Extra cable (${estimate.extraCableLength}m)',
                  value: formatMoney(estimate.extraCableCost),
                ),
              ],
              const SizedBox(height: 10),
              DetailLine(
                label: 'Site extras',
                value: formatMoney(estimate.surchargeTotal),
              ),
              const SizedBox(height: 4),
              if (estimate.surcharges.isEmpty)
                Text(
                  'No extras',
                  style: TextStyle(fontSize: 11, color: palette.textHint),
                )
              else
                for (final item in estimate.surcharges)
                  Text(
                    '• ${_surchargeLabels[item.id] ?? item.id}'
                    ' +${formatMoney(item.price)}',
                    style: TextStyle(fontSize: 11, color: palette.textHint),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TotalCard(label: 'Estimated total', total: estimate.total),
        const SizedBox(height: 12),
        AppPrimaryButton(
          text: _isSaving ? 'Saving…' : 'Save estimate',
          onTap: _isSaving ? null : _saveResult,
        ),
        const SizedBox(height: 12),
        AppPrimaryButton(
          text: 'Required documents',
          backgroundColor: Colors.transparent,
          textColor: palette.primaryContainer,
          onTap: _showFileSheet,
        ),
        const SizedBox(height: 8),
        const CalcDisclaimer(
          'This breakdown is an estimate only; the final price follows the official quote after an on-site survey. Contact support with any questions.',
        ),
      ],
    );
  }

  void _showFileSheet() {
    showAppSheet(
      context: context,
      title: 'Required documents',
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
      title: 'Saved estimates',
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
                                  formatMoney(item.estimate.total),
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
                              '${powerLabelOf(item.powerId)} · '
                              '${item.cableLength}m cable'
                              '${item.estimate.surchargeTotal > 0 ? ' · extras ${formatMoney(item.estimate.surchargeTotal)}' : ''}',
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
