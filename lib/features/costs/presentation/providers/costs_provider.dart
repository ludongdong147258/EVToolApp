import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/domain/maintenance_costs.dart';
import 'package:ev_tool_app/features/costs/data/repositories/cost_repository.dart';

/// 养车支出状态（对应小程序 cost-list 页的 expenses state）。
///
/// 存储即真相：所有变更走 repository 后回读刷新 state，
/// 页面从新增/车辆页返回时调 [CostsNotifier.reload] 重新汇总。
class CostsNotifier extends Notifier<List<Expense>> {
  @override
  List<Expense> build() {
    return ref.watch(costRepositoryProvider).getExpenses();
  }

  CostRepository get _repo => ref.read(costRepositoryProvider);

  void reload() {
    state = _repo.getExpenses();
  }

  Future<void> add(Expense expense) async {
    state = await _repo.addExpense(expense);
  }

  Future<void> update(String id, Expense next) async {
    state = await _repo.updateExpense(id, next);
  }

  /// 删除并返回被删支出（供 5s 撤销窗口批量恢复）；找不到返回 null。
  Future<Expense?> remove(String id) async {
    final deleted = state.where((expense) => expense.id == id).firstOrNull;
    state = await _repo.removeExpense(id);
    return deleted;
  }

  /// 撤销窗口内批量恢复；全部成功返回 true。
  Future<bool> restoreAll(List<Expense> expenses) async {
    var allOk = true;
    for (final expense in expenses) {
      try {
        state = await _repo.addExpense(expense);
      } on Exception {
        allOk = false;
      }
    }
    reload();
    return allOk;
  }
}

final costsProvider = NotifierProvider<CostsNotifier, List<Expense>>(
  CostsNotifier.new,
);

/// 列表筛选 + 排序状态（移植小程序 cost-list 页的
/// timeFilter/typeFilter/vehicleFilter/sortBy）。
class CostFilters {
  const CostFilters({
    this.timePreset = 'month',
    this.type,
    this.vehicleId,
    this.sortBy = 'date',
  });

  /// 时间范围预设：month | quarter3 | year | all
  final String timePreset;

  /// 支出类型（null = 全部）
  final String? type;

  /// 车辆 id（null = 不限）
  final String? vehicleId;

  /// 排序：date（最新）| amount（金额最高）
  final String sortBy;

  static const Object _unset = Object();

  CostFilters copyWith({
    String? timePreset,
    Object? type = _unset,
    Object? vehicleId = _unset,
    String? sortBy,
  }) {
    return CostFilters(
      timePreset: timePreset ?? this.timePreset,
      type: identical(type, _unset) ? this.type : type as String?,
      vehicleId: identical(vehicleId, _unset)
          ? this.vehicleId
          : vehicleId as String?,
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

class CostFiltersNotifier extends Notifier<CostFilters> {
  @override
  CostFilters build() => const CostFilters();

  void setTimePreset(String preset) {
    state = state.copyWith(timePreset: preset);
  }

  void setType(String? type) {
    state = state.copyWith(type: type);
  }

  /// 车辆 chip 点击切换（再次点击取消）。
  void toggleVehicle(String vehicleId) {
    state = state.copyWith(
      vehicleId: state.vehicleId == vehicleId ? null : vehicleId,
    );
  }

  /// 最新 ⇄ 金额最高。
  void toggleSort() {
    state = state.copyWith(sortBy: state.sortBy == 'date' ? 'amount' : 'date');
  }

  /// 筛选叠加结果为空时的一键恢复（时间/类型/车辆全部回默认）。
  void clearAll() {
    state = const CostFilters();
  }
}

final costFiltersProvider = NotifierProvider<CostFiltersNotifier, CostFilters>(
  CostFiltersNotifier.new,
);

/// 当前筛选 + 排序后的支出列表（列表渲染与汇总共用同一口径）。
final filteredExpensesProvider = Provider<List<Expense>>((ref) {
  final filters = ref.watch(costFiltersProvider);
  final filtered = filterExpenses(
    ref.watch(costsProvider),
    ExpenseFilters(
      range: resolveTimeRange(filters.timePreset),
      type: filters.type,
      vehicleId: filters.vehicleId,
    ),
  );
  if (filters.sortBy == 'amount') {
    final sorted = List<Expense>.of(filtered)
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return sorted;
  }
  return filtered;
});

/// 周期汇总视图（hero 卡：合计 + 最高单笔）。
class ExpenseSummaryView {
  const ExpenseSummaryView({required this.summary, required this.top});

  final ExpenseSummary summary;
  final TopExpense? top;
}

final expenseSummaryProvider = Provider<ExpenseSummaryView>((ref) {
  final filtered = ref.watch(filteredExpensesProvider);
  return ExpenseSummaryView(
    summary: calcExpenseSummary(filtered),
    top: pickTopExpense(filtered),
  );
});

/// 报表图例点击跳转带来的一次性类型筛选意图（列表页消费后即清空）。
///
/// Tab 页无法通过 URL 传参，等价于 JS costService 的 filterIntent；
/// 语义改为 Riverpod StateProvider，由列表页取后置 null。
final costFilterIntentProvider = StateProvider<String?>((ref) => null);
