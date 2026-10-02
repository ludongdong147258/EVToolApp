import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:ev_tool_app/core/utils/share_files.dart';

import 'package:ev_tool_app/core/domain/backup_file.dart';
import 'package:ev_tool_app/core/domain/export_data.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/utils/logger.dart';
import 'package:ev_tool_app/core/widgets/app_primary_button.dart';
import 'package:ev_tool_app/core/widgets/app_toast.dart';
import 'package:ev_tool_app/features/costs/data/repositories/cost_repository.dart';
import 'package:ev_tool_app/features/costs/presentation/providers/costs_provider.dart';
import 'package:ev_tool_app/features/memos/data/repositories/memo_repository.dart';
import 'package:ev_tool_app/features/records/data/repositories/record_repository.dart';
import 'package:ev_tool_app/features/records/presentation/providers/records_provider.dart';
import 'package:ev_tool_app/features/vehicles/data/repositories/vehicle_repository.dart';

/// 备份文本 + 大小文案（导出与复制共用同一份载荷）。
class BackupPayload {
  const BackupPayload({
    required this.text,
    required this.size,
    required this.recordCount,
    required this.vehicleCount,
    required this.expenseCount,
    required this.memoCount,
  });

  final String text;
  final String size;
  final int recordCount;
  final int vehicleCount;
  final int expenseCount;
  final int memoCount;
}

/// 四类本地数据 → JSON 备份文本（存储即真相，现算不缓存）。
final backupPayloadProvider = Provider<BackupPayload>((ref) {
  final records = ref.watch(recordsProvider);
  final vehicles = ref.watch(vehiclesProvider);
  final expenses = ref.watch(costsProvider);
  final memos = ref.watch(memoListProvider);
  final backup = buildExportJson(
    records: records,
    vehicles: vehicles,
    expenses: expenses,
    memos: memos,
    exportedAt: DateTime.now().millisecondsSinceEpoch,
  );
  final text = jsonEncode(backup);
  return BackupPayload(
    text: text,
    size: formatPayloadSize(text),
    recordCount: records.length,
    vehicleCount: vehicles.length,
    expenseCount: expenses.length,
    memoCount: memos.length,
  );
});

/// 数据备份页（子页）：导出全部数据为 JSON 备份文件 / 从文件导入恢复。
///
/// 移植小程序「我的 → 数据备份」；剪贴板 32KB 阈值与微信聊天文件通道
/// 不适用于 App，导出统一走系统分享面板，导入走文件选择器。
class BackupRestorePage extends ConsumerWidget {
  const BackupRestorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final payload = ref.watch(backupPayloadProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('数据备份')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('导出数据', style: context.textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(
                  '共 ${payload.recordCount} 条充电记录、${payload.vehicleCount} 辆车、'
                  '${payload.expenseCount} 笔养车支出、${payload.memoCount} 条年检备忘，'
                  '备份大小约 ${payload.size}（车辆照片不随备份迁移）。',
                  style: TextStyle(fontSize: 13, color: palette.textSecondary),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => _copyPayload(context, ref),
                    child: const Text('复制备份文本'),
                  ),
                ),
                const SizedBox(height: 10),
                AppPrimaryButton(
                  text: '导出数据',
                  height: 44,
                  onTap: () => _exportPayload(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('导入恢复', style: context.textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(
                  '选择此前导出的 .json 备份文件，数据将与现有记录合并'
                  '（重复条目自动跳过）。',
                  style: TextStyle(fontSize: 13, color: palette.textSecondary),
                ),
                const SizedBox(height: 16),
                AppPrimaryButton(
                  text: '导入恢复',
                  height: 44,
                  backgroundColor: palette.surfaceContainerHighest,
                  textColor: palette.onSurface,
                  onTap: () => _pickAndImport(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 复制备份文本到剪贴板（粘贴到备忘录等处自行保存）。
  Future<void> _copyPayload(BuildContext context, WidgetRef ref) async {
    final payload = ref.read(backupPayloadProvider);
    try {
      await Clipboard.setData(ClipboardData(text: payload.text));
      if (context.mounted) showAppToast(context, '已复制备份文本');
    } on Exception catch (e) {
      appLogger.e('复制备份文本失败', error: e);
      if (context.mounted) showAppToast(context, '复制失败，请重试');
    }
  }

  /// 导出：备份 JSON 写临时文件 `EVTool备份-YYYY-MM-DD.json` 后拉起分享。
  Future<void> _exportPayload(BuildContext context, WidgetRef ref) async {
    final payload = ref.read(backupPayloadProvider);
    try {
      final fileName = buildBackupFileName(DateTime.now());
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(payload.text, flush: true);
      if (!context.mounted) return;
      final result = await shareFiles(context, [XFile(file.path)]);
      if (result.status == ShareResultStatus.success && context.mounted) {
        showAppToast(context, '备份文件已分享');
      }
    } on Exception catch (e) {
      appLogger.e('导出备份文件失败', error: e);
      if (context.mounted) showAppToast(context, '导出失败，请重试');
    }
  }

  /// 导入：文件选择器（仅 .json）→ 解析确认 → 按域合并写回。
  Future<void> _pickAndImport(BuildContext context, WidgetRef ref) async {
    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
    } on Exception catch (e) {
      appLogger.e('选择备份文件失败', error: e);
      if (context.mounted) showAppToast(context, '选择文件失败，请重试');
      return;
    }
    final path = picked?.files.single.path;
    if (path == null) return; // 用户取消
    if (!context.mounted) return;
    if (!isJsonFilePath(path)) {
      showAppToast(context, '文件格式不正确');
      return;
    }

    final String text;
    try {
      text = await File(path).readAsString();
    } on Exception catch (e) {
      appLogger.e('读取备份文件失败', error: e);
      if (context.mounted) showAppToast(context, '读取备份文件失败');
      return;
    }
    if (!context.mounted) return;

    final parsed = parseExportJson(text);
    if (parsed == null) {
      showAppToast(context, '文件格式不正确');
      return;
    }
    final total =
        parsed.records.length +
        parsed.vehicles.length +
        parsed.expenses.length +
        parsed.memos.length;
    if (total == 0) {
      showAppToast(context, '备份中没有可导入的数据');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('导入备份'),
        content: Text(
          '将导入 ${parsed.records.length} 条充电记录、${parsed.vehicles.length} 辆车、'
          '${parsed.expenses.length} 笔养车支出、${parsed.memos.length} 条年检备忘，'
          '与现有数据合并（重复条目自动跳过）。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _runImport(context, ref, parsed);
  }

  /// 执行导入并汇报结果（成功后失效全部列表 provider 联动刷新）。
  Future<void> _runImport(
    BuildContext context,
    WidgetRef ref,
    ParsedBackup parsed,
  ) async {
    try {
      final recordPick = await ref
          .read(recordRepositoryProvider)
          .importRecords(parsed.records);
      final vehiclePick = await ref
          .read(vehicleRepositoryProvider)
          .importVehicles(parsed.vehicles);
      final expensePick = await ref
          .read(costRepositoryProvider)
          .importExpenses(parsed.expenses);
      final memoPick = await ref
          .read(memoRepositoryProvider)
          .importMemos(parsed.memos);

      ref
        ..invalidate(recordsProvider)
        ..invalidate(costsProvider)
        ..invalidate(memoListProvider)
        ..invalidate(vehiclesProvider);

      final added =
          recordPick.toAdd.length +
          vehiclePick.toAdd.length +
          expensePick.toAdd.length +
          memoPick.toAdd.length;
      final skipped =
          recordPick.skippedCount +
          vehiclePick.skippedCount +
          expensePick.skippedCount +
          memoPick.skippedCount;
      if (context.mounted) {
        showAppToast(context, '新增 $added 条，跳过 $skipped 条');
      }
    } on Exception catch (e) {
      appLogger.e('备份导入失败', error: e);
      if (context.mounted) showAppToast(context, '导入失败，请重试');
    }
  }
}

/// 白卡片分区容器。
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}
