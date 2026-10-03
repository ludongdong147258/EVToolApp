import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Export Data', style: context.textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(
                  '${payload.recordCount} charging records, ${payload.vehicleCount} vehicle(s), '
                  '${payload.expenseCount} expense(s), and ${payload.memoCount} inspection memo(s), '
                  'about ${payload.size} in total (vehicle photos are not included).',
                  style: TextStyle(fontSize: 13, color: palette.textSecondary),
                ),
                const SizedBox(height: 16),
                AppPrimaryButton(
                  text: 'Export Data',
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
                Text('Import Backup', style: context.textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(
                  'Pick a .json backup file you exported earlier. Its data will be '
                  'merged with your existing records (duplicates are skipped '
                  'automatically).',
                  style: TextStyle(fontSize: 13, color: palette.textSecondary),
                ),
                const SizedBox(height: 16),
                AppPrimaryButton(
                  text: 'Import Backup',
                  height: 44,
                  onTap: () => _pickAndImport(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
        showAppToast(context, 'Backup file shared');
      }
    } on Exception catch (e) {
      appLogger.e('Failed to export backup file', error: e);
      if (context.mounted) {
        showAppToast(context, 'Export failed, please try again');
      }
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
      appLogger.e('Failed to pick backup file', error: e);
      if (context.mounted) {
        showAppToast(context, 'Failed to pick a file, please try again');
      }
      return;
    }
    final path = picked?.files.single.path;
    if (path == null) return; // 用户取消
    if (!context.mounted) return;
    if (!isJsonFilePath(path)) {
      showAppToast(context, 'Invalid file format');
      return;
    }

    final String text;
    try {
      text = await File(path).readAsString();
    } on Exception catch (e) {
      appLogger.e('Failed to read backup file', error: e);
      if (context.mounted) {
        showAppToast(context, 'Failed to read the backup file');
      }
      return;
    }
    if (!context.mounted) return;

    final parsed = parseExportJson(text);
    if (parsed == null) {
      showAppToast(context, 'Invalid file format');
      return;
    }
    final total =
        parsed.records.length +
        parsed.vehicles.length +
        parsed.expenses.length +
        parsed.memos.length;
    if (total == 0) {
      showAppToast(context, 'No importable data in this backup');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import Backup'),
        content: Text(
          'This will import ${parsed.records.length} charging records, '
          '${parsed.vehicles.length} vehicle(s), ${parsed.expenses.length} expense(s), '
          'and ${parsed.memos.length} inspection memo(s), merged with your existing '
          'data (duplicates are skipped automatically).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Import'),
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
        showAppToast(context, '$added added, $skipped skipped');
      }
    } on Exception catch (e) {
      appLogger.e('Backup import failed', error: e);
      if (context.mounted) {
        showAppToast(context, 'Import failed, please try again');
      }
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
