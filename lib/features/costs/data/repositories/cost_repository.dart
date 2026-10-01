import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/domain/export_data.dart';
import 'package:ev_tool_app/core/domain/maintenance_costs.dart';
import 'package:ev_tool_app/core/storage/key_value_store.dart';
import 'package:ev_tool_app/core/utils/logger.dart';
import 'package:ev_tool_app/features/records/data/repositories/record_repository.dart'
    show StorageException;

/// 养车支出仓储（移植小程序 costService.js）。
///
/// 存储key `maintenanceCosts`，JSON 数组；读 → normalize 过滤脏数据 →
/// 日期降序（同日按 createdAt 降序）；写失败抛 [StorageException]
/// 由页面层捕获 toast。
class CostRepository {
  CostRepository(this._kv);

  static const String storageKey = 'maintenanceCosts';
  final KeyValueStore _kv;

  /// 全量支出（date 降序，同日按 createdAt 降序）。
  List<Expense> getExpenses() {
    final raw = _kv.getJsonList(storageKey);
    if (raw == null) return [];
    final expenses = <Expense>[];
    for (final item in raw) {
      final expense = normalizeStoredExpense(
        item is Map<String, dynamic> ? item : null,
      );
      if (expense != null) expenses.add(expense);
    }
    return sortExpensesDesc(expenses);
  }

  /// 新增（写回后保持降序）；记录保持原 id / createdAt。
  Future<List<Expense>> addExpense(Expense expense) async {
    final next = [expense, ...getExpenses()];
    await _save(next);
    return sortExpensesDesc(next);
  }

  /// 更新：保留既有 id 与 createdAt；日期可能变化，写回前重排。
  /// id 不存在时幂等返回原数组。
  Future<List<Expense>> updateExpense(String id, Expense next) async {
    final expenses = getExpenses();
    var found = false;
    final mapped = [
      for (final expense in expenses)
        expense.id == id
            ? () {
                found = true;
                return next.copyWith(
                  id: expense.id,
                  createdAt: expense.createdAt,
                );
              }()
            : expense,
    ];
    if (found) {
      await _save(mapped);
      return sortExpensesDesc(mapped);
    }
    return expenses;
  }

  /// 删除（幂等）。
  Future<List<Expense>> removeExpense(String id) async {
    final next = [
      for (final expense in getExpenses())
        if (expense.id != id) expense,
    ];
    await _save(next);
    return next;
  }

  /// 备份导入：按 id 去重合并（仅新增本地不存在的支出）。
  ///
  /// 无可新增项时不写回，直接返回挑选结果。
  Future<ImportPick<Expense>> importExpenses(List<Expense> incoming) async {
    final existing = getExpenses();
    final pick = pickImportItems(existing, incoming, (expense) => expense.id);
    if (pick.toAdd.isEmpty) {
      return pick;
    }
    await _save(sortExpensesDesc([...pick.toAdd, ...existing]));
    return pick;
  }

  /// 车辆改名 → 同步支出 vehicleName 快照（由车辆仓储调用）。
  Future<void> syncVehicleRename(String vehicleId, String nextName) async {
    await _save(applyVehicleSnapshotRename(getExpenses(), vehicleId, nextName));
  }

  /// 车辆删除 → 清空关联支出上的车辆字段（由车辆仓储调用）。
  Future<void> syncVehicleRemoval(String vehicleId) async {
    await _save(applyVehicleSnapshotRemoval(getExpenses(), vehicleId));
  }

  Future<void> _save(List<Expense> expenses) {
    try {
      return _kv.setJson(storageKey, [
        for (final expense in expenses) expense.toJson(),
      ]);
    } on Exception catch (e) {
      appLogger.e('保存养车支出失败', error: e);
      throw const StorageException('支出保存失败');
    }
  }
}

final costRepositoryProvider = Provider<CostRepository>(
  (ref) => CostRepository(ref.watch(keyValueStoreProvider)),
);
