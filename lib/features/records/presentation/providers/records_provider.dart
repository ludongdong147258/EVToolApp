import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/domain/charge_records.dart';
import 'package:ev_tool_app/core/domain/date_utils.dart';
import 'package:ev_tool_app/core/domain/inspection_memo_calc.dart';
import 'package:ev_tool_app/core/domain/memo_reminder.dart';
import 'package:ev_tool_app/core/domain/vehicles.dart';
import 'package:ev_tool_app/features/memos/data/repositories/memo_repository.dart';
import 'package:ev_tool_app/features/records/data/repositories/record_repository.dart';
import 'package:ev_tool_app/features/vehicles/data/repositories/vehicle_repository.dart';

/// 充电记录状态（对应小程序 records 页的 records state + 五服务读取闭环）。
///
/// 存储即真相：所有变更走 repository 后回读刷新 state，
/// 页面从新增/统计/车辆页返回时调 [reload] 重新汇总。
class RecordsNotifier extends Notifier<List<ChargeRecord>> {
  @override
  List<ChargeRecord> build() {
    return ref.watch(recordRepositoryProvider).getRecords();
  }

  RecordRepository get _repo => ref.read(recordRepositoryProvider);

  void reload() {
    state = _repo.getRecords();
  }

  Future<void> add(ChargeRecord record) async {
    state = await _repo.addRecord(record);
  }

  Future<void> update(String id, ChargeRecord next) async {
    state = await _repo.updateRecord(id, next);
  }

  /// 删除并返回被删记录（供 5s 撤销窗口批量恢复）；找不到返回 null。
  Future<ChargeRecord?> remove(String id) async {
    final deleted = state.where((r) => r.id == id).firstOrNull;
    state = await _repo.removeRecord(id);
    return deleted;
  }

  /// 撤销窗口内批量恢复；全部成功返回 true。
  Future<bool> restoreAll(List<ChargeRecord> records) async {
    var allOk = true;
    for (final record in records) {
      try {
        state = await _repo.addRecord(record);
      } on Exception {
        allOk = false;
      }
    }
    reload();
    return allOk;
  }
}

final recordsProvider = NotifierProvider<RecordsNotifier, List<ChargeRecord>>(
  RecordsNotifier.new,
);

/// 车辆列表状态。
class VehiclesNotifier extends Notifier<List<Vehicle>> {
  @override
  List<Vehicle> build() {
    return ref.watch(vehicleRepositoryProvider).getVehicles();
  }

  VehicleRepository get _repo => ref.read(vehicleRepositoryProvider);

  void reload() {
    state = _repo.getVehicles();
  }

  Future<void> add(Vehicle vehicle) async {
    state = await _repo.addVehicle(vehicle);
  }

  Future<void> update(
    String id, {
    String? name,
    double? battery,
    String? note,
    String? photoPath,
  }) async {
    state = await _repo.updateVehicle(
      id,
      name: name,
      battery: battery,
      note: note,
      photoPath: photoPath,
    );
    // 车辆改名/删除会同步记录快照，联动刷新
    ref.read(recordsProvider.notifier).reload();
  }

  Future<void> remove(String id) async {
    state = await _repo.removeVehicle(id);
    ref.read(recordsProvider.notifier).reload();
  }

  Future<void> setDefault(String id) async {
    state = await _repo.setDefault(id);
  }
}

final vehiclesProvider = NotifierProvider<VehiclesNotifier, List<Vehicle>>(
  VehiclesNotifier.new,
);

/// 备忘到期提醒（最紧急一条；替代小程序 MEMO_CHANGE_EVENT 事件）。
/// 记录页提醒条与底栏红点共同 watch 此 provider；备忘页保存/删除后
/// invalidate [memoListProvider] 即可联动。
final memoReminderProvider = Provider<MemoReminder?>((ref) {
  final memos = ref.watch(memoListProvider);
  return pickMemoReminder(memos);
});

/// 备忘列表。
final memoListProvider = Provider<List<MemoItem>>(
  (ref) => ref.watch(memoRepositoryProvider).getMemos(),
);

/// 本月汇总（记录页 hero 卡）。
final monthSummaryProvider = Provider<MonthSummary>((ref) {
  final records = ref.watch(recordsProvider);
  return calcMonthSummary(records, getCurrentMonthKey());
});
