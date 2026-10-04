import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:ev_tool_app/core/utils/share_files.dart';

import 'package:ev_tool_app/core/domain/annual_report.dart';
import 'package:ev_tool_app/core/domain/charge_records.dart';
import 'package:ev_tool_app/core/domain/date_utils.dart';
import 'package:ev_tool_app/core/domain/numbers.dart';
import 'package:ev_tool_app/core/domain/poster.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/routing/route_names.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/utils/logger.dart';
import 'package:ev_tool_app/core/widgets/app_sheet.dart';
import 'package:ev_tool_app/core/widgets/app_toast.dart';
import 'package:ev_tool_app/core/widgets/empty_state.dart';
import 'package:ev_tool_app/core/widgets/gradient_hero_card.dart';
import 'package:ev_tool_app/core/widgets/month_bar_chart.dart';
import 'package:ev_tool_app/features/records/presentation/providers/records_provider.dart';
import 'package:ev_tool_app/features/pro/presentation/paywall_sheet.dart';
import 'package:ev_tool_app/features/stats/presentation/widgets/annual_poster.dart';

/// 海报导出像素倍率（750 设计宽 × 2 = 1500px 输出）。
const double _posterPixelRatio = 2;

/// 充电年度报告页（子页，从充电统计页进入）：
/// 年份切换 + 总览/月度费用/方式占比/年度之最 + 分享海报。
class AnnualReportPage extends ConsumerStatefulWidget {
  const AnnualReportPage({super.key});

  @override
  ConsumerState<AnnualReportPage> createState() => _AnnualReportPageState();
}

class _AnnualReportPageState extends ConsumerState<AnnualReportPage> {
  int? _year;
  final GlobalKey _posterKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 与统计页一致的防御性刷新（本页只读，返回时数据保持同步）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(recordsProvider.notifier).reload();
    });
  }

  /* ---------- 分享海报 ---------- */

  Future<void> _openPosterSheet(
    AnnualReport report,
    int totalRecordCount,
  ) async {
    await showAppSheet<void>(
      context: context,
      title: 'Annual Report Poster',
      builder: (sheetContext) => AppSheetScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: _posterKey,
                child: AnnualPoster(
                  model: buildPosterModel(report, totalRecordCount),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => unawaited(_sharePoster()),
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text('Save / Share Poster'),
            ),
          ],
        ),
      ),
    );
  }

  /// RepaintBoundary 截图 → PNG 临时文件 → 系统分享。
  Future<void> _sharePoster() async {
    // Pro 门控：海报预览免费，仅分享导出受限
    if (!await ensurePro(context, ref)) return;
    final renderObject = _posterKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      if (mounted) {
        showAppToast(context, 'Poster is still rendering, try again');
      }
      return;
    }
    try {
      final image = await renderObject.toImage(pixelRatio: _posterPixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = data?.buffer.asUint8List();
      if (bytes == null || bytes.isEmpty) {
        if (mounted) showAppToast(context, 'Poster export failed. Try again');
        return;
      }
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/voltledger_annual_$stamp.png');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      await shareFiles(context, [XFile(file.path)]);
    } on Exception catch (err) {
      appLogger.e('Poster export failed', error: err);
      if (mounted) showAppToast(context, 'Poster export failed. Try again');
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(recordsProvider);
    final years = getAvailableYears(records);

    // 两类情况整页空态：从未记录 / 数据被删空
    if (years.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Annual Charging Report')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            EmptyState(
              icon: Icons.insights_rounded,
              title: 'No charging data yet',
              subtitle: 'Add charging records to see your annual report',
              ctaText: 'Add Records',
              onCta: () => context.go(RouteNames.records),
            ),
          ],
        ),
      );
    }

    // 已选年份仍有记录则保持；记录删除导致年份消失则重置到最新有记录年份
    final year = _year != null && years.contains(_year) ? _year : years.first;
    final report = calcAnnualReport(records, year);
    final percents = calcBarPercents(report.months);

    return Scaffold(
      appBar: AppBar(title: const Text('Annual Charging Report')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // 年份切换（仅有记录的年份）
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in years)
                _YearChip(
                  label: '$item',
                  isSelected: item == year,
                  onTap: () {
                    unawaited(HapticFeedback.selectionClick());
                    setState(() => _year = item);
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 总览卡
          GradientHeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$year Annual Charging Spend',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.onPrimaryA85,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                HeroValue(value: formatMoney(report.totalCost)),
                const SizedBox(height: 16),
                HeroStatsRow(
                  items: [
                    HeroStatItem(label: 'Sessions', value: '${report.count}'),
                    HeroStatItem(
                      label: 'Energy',
                      value: formatYuan(report.totalEnergy),
                      unit: 'kWh',
                    ),
                    HeroStatItem(
                      label: 'Avg Cost',
                      value: report.costPerKwh == null
                          ? '--'
                          : formatMoney(report.costPerKwh!),
                      unit: '/kWh',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 月度费用柱状图（12 柱）
          _SectionCard(
            icon: Icons.bar_chart_rounded,
            title: 'Monthly Cost',
            hint: 'in USD',
            child: MonthBarChart(
              bars: [
                for (var i = 0; i < report.months.length; i++)
                  MonthBar(
                    month: i + 1,
                    percent: percents[i],
                    hasData: report.months[i].count > 0,
                    valueLabel: report.months[i].count > 0
                        ? formatAmount(report.months[i].totalCost)
                        : '',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 充电方式占比
          _SplitCard(report: report),
          const SizedBox(height: 12),

          // 年度之最
          _BestCard(report: report),
          const SizedBox(height: 16),

          // 一键生成分享海报（主操作）
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: () =>
                unawaited(_openPosterSheet(report, records.length)),
            icon: const Icon(Icons.insights_rounded, size: 18),
            label: const Text('Create Share Poster'),
          ),
        ],
      ),
    );
  }
}

/// 卡片头（图标 + 标题 + 右侧提示文案）。
class _CardHead extends StatelessWidget {
  const _CardHead({required this.icon, required this.title, this.hint});

  final IconData icon;
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Icon(icon, size: 16, color: palette.primaryContainer),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (hint != null)
          Text(hint!, style: TextStyle(fontSize: 12, color: palette.textHint)),
      ],
    );
  }
}

/// 浅色卡片（卡片头 + 内容）。
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    this.hint,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHead(icon: icon, title: title, hint: hint),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// 年份 chip。
class _YearChip extends StatelessWidget {
  const _YearChip({required this.label, required this.isSelected, this.onTap});

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? palette.secondaryContainer : palette.inputBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? palette.primaryContainer : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isSelected
                ? palette.onSecondaryContainer
                : palette.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// 快充/家充占比卡（双色占比条 + 图例）。
class _SplitCard extends StatelessWidget {
  const _SplitCard({required this.report});

  final AnnualReport report;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final totalCount = report.count;
    final fastPercent = totalCount > 0
        ? ((report.fast.count / totalCount) * 100).round()
        : 0;

    return _SectionCard(
      icon: Icons.bolt_rounded,
      title: 'Charging Mix',
      hint: 'by sessions',
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 16,
              color: palette.surfaceVariant,
              child: Row(
                // stretch：色块填满条高（ColoredBox 无 child 在宽松高度
                // 约束下会塌缩为 0 高，占比条会一直只剩灰色轨道）
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (report.fast.count > 0)
                    Expanded(
                      flex: fastPercent,
                      child: ColoredBox(color: palette.primary),
                    ),
                  if (report.home.count > 0)
                    Expanded(
                      flex: 100 - fastPercent,
                      child: const ColoredBox(color: AppColors.amber),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (report.fast.count > 0)
            _SplitRow(
              dotColor: palette.primary,
              label: 'Fast (DC)',
              summary: report.fast,
              totalCount: totalCount,
            ),
          if (report.home.count > 0)
            _SplitRow(
              dotColor: AppColors.amber,
              label: 'Home (AC)',
              summary: report.home,
              totalCount: totalCount,
            ),
        ],
      ),
    );
  }
}

class _SplitRow extends StatelessWidget {
  const _SplitRow({
    required this.dotColor,
    required this.label,
    required this.summary,
    required this.totalCount,
  });

  final Color dotColor;
  final String label;
  final TotalSummary summary;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final percent = totalCount > 0
        ? ((summary.count / totalCount) * 100).round()
        : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: palette.textSecondary),
          ),
          const Spacer(),
          Text(
            '${summary.count} · ${formatMoney(summary.totalCost)} · $percent%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: palette.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// 年度之最卡（单次之最 + 最活跃月份）。
class _BestCard extends StatelessWidget {
  const _BestCard({required this.report});

  final AnnualReport report;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final maxCost = report.maxCostRecord;
    final maxEnergy = report.maxEnergyRecord;
    final topMonth = report.topMonth;

    return _SectionCard(
      icon: Icons.trending_up_rounded,
      title: 'Year Highlights',
      child: maxCost == null
          ? Text(
              'No data yet',
              style: TextStyle(fontSize: 13, color: palette.textHint),
            )
          : Column(
              children: [
                _BestRow(
                  icon: Icons.star_rounded,
                  label: 'Most Expensive Session',
                  value: formatMoney(maxCost.cost),
                  sub: [
                    formatRecordDate(maxCost.date),
                    typeDefaultTitles[maxCost.type] ?? '',
                    '${formatYuan(maxCost.energy)} kWh',
                  ].where((part) => part.isNotEmpty).join(' · '),
                ),
                if (maxEnergy != null)
                  _BestRow(
                    icon: Icons.battery_charging_full_rounded,
                    label: 'Most Energy in a Session',
                    value: '${formatYuan(maxEnergy.energy)} kWh',
                    sub: [
                      formatRecordDate(maxEnergy.date),
                      formatMoney(maxEnergy.cost),
                    ].join(' · '),
                  ),
                if (topMonth != null)
                  _BestRow(
                    icon: Icons.trending_up_rounded,
                    label: 'Most Active Month',
                    value: formatMonthLabel(topMonth.monthKey),
                    sub:
                        '${topMonth.count} charges · '
                        '${formatMoney(topMonth.totalCost)}',
                    isLast: true,
                  ),
              ],
            ),
    );
  }
}

class _BestRow extends StatelessWidget {
  const _BestRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: palette.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: palette.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: palette.onSecondaryContainer),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: palette.textHint),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: palette.primary,
            ),
          ),
        ],
      ),
    );
  }
}
