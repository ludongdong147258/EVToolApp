import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/domain/export_data.dart';
import 'package:ev_tool_app/core/domain/vehicles.dart';
import 'package:ev_tool_app/core/storage/key_value_store.dart';
import 'package:ev_tool_app/core/utils/logger.dart';
import 'package:ev_tool_app/features/costs/data/repositories/cost_repository.dart';
import 'package:ev_tool_app/features/records/data/repositories/record_repository.dart';

/// 车辆仓储（移植小程序 vehicleService.js）。
///
/// 存储key `vehicles`；读取经 ensureSingleDefault 维持
/// 「非空列表恰有一台默认车」不变式（只修返回值，不回写）。
/// 车辆改名/删除会联动同步充电记录（Phase 3 起再加养车支出）的快照。
class VehicleRepository {
  VehicleRepository(this._kv, this._recordRepository, this._costRepository);

  static const String storageKey = 'vehicles';
  final KeyValueStore _kv;
  final RecordRepository _recordRepository;
  final CostRepository _costRepository;

  List<Vehicle> getVehicles() {
    final raw = _kv.getJsonList(storageKey);
    if (raw == null) return [];
    final vehicles = <Vehicle>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        final vehicle = normalizeStoredVehicle(item);
        if (vehicle != null) vehicles.add(vehicle);
      }
    }
    return ensureSingleDefault(vehicles);
  }

  Vehicle? getDefaultVehicle() {
    final vehicles = getVehicles();
    if (vehicles.isEmpty) return null;
    return vehicles.firstWhere(
      (v) => v.isDefault,
      orElse: () => vehicles.first,
    );
  }

  /// 新增；首台车强制为默认车。
  Future<List<Vehicle>> addVehicle(Vehicle vehicle) async {
    final vehicles = getVehicles();
    final isFirst = vehicles.isEmpty;
    final next = [
      if (isFirst) vehicle.copyWith(isDefault: true) else vehicle,
      ...vehicles,
    ];
    await _save(next);
    return sortVehicles(next);
  }

  /// 更新白名单字段（name/battery/note/photoPath）；
  /// photoPath 传 null 表示保留，'' 表示清除。
  /// 改名会同步充电记录的 vehicleName 快照。
  Future<List<Vehicle>> updateVehicle(
    String id, {
    String? name,
    double? battery,
    String? note,
    String? photoPath,
  }) async {
    final vehicles = getVehicles();
    String? renamedTo;
    final next = <Vehicle>[];
    for (final vehicle in vehicles) {
      if (vehicle.id != id) {
        next.add(vehicle);
        continue;
      }
      final updated = vehicle.copyWith(
        name: name ?? vehicle.name,
        battery: battery ?? vehicle.battery,
        note: note ?? vehicle.note,
        photoPath: photoPath ?? vehicle.photoPath,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      if (name != null && name != vehicle.name) renamedTo = name;
      next.add(updated);
    }
    await _save(next);
    final rename = renamedTo;
    if (rename != null) {
      try {
        await _recordRepository.syncVehicleRename(id, rename);
        await _costRepository.syncVehicleRename(id, rename);
      } on Exception catch (e) {
        // 快照同步失败只记录日志，不阻塞改名（与小程序口径一致）
        appLogger.w('同步车辆快照失败', error: e);
      }
    }
    return ensureSingleDefault(next);
  }

  /// 删除：级联清默认车与充电记录关联快照。
  Future<List<Vehicle>> removeVehicle(String id) async {
    final next = [
      for (final vehicle in getVehicles())
        if (vehicle.id != id) vehicle,
    ];
    await _save(ensureSingleDefault(next));
    try {
      await _recordRepository.syncVehicleRemoval(id);
      await _costRepository.syncVehicleRemoval(id);
    } on Exception catch (e) {
      appLogger.w('同步车辆快照失败', error: e);
    }
    return ensureSingleDefault(next);
  }

  /// 设默认车（幂等）。
  Future<List<Vehicle>> setDefault(String id) async {
    final next = [
      for (final vehicle in getVehicles())
        vehicle.copyWith(isDefault: vehicle.id == id),
    ];
    await _save(next);
    return next;
  }

  /// 批量导入（按 id 去重）。
  Future<ImportPick<Vehicle>> importVehicles(List<Vehicle> incoming) async {
    final pick = pickImportItems(getVehicles(), incoming, (v) => v.id);
    final merged = [...pick.toAdd, ...getVehicles()];
    await _save(merged);
    return pick;
  }

  Future<void> _save(List<Vehicle> vehicles) {
    try {
      return _kv.setJson(storageKey, [
        for (final vehicle in vehicles) vehicle.toJson(),
      ]);
    } on Exception catch (e) {
      appLogger.e('保存车辆档案失败', error: e);
      throw const StorageException('车辆保存失败');
    }
  }
}

final vehicleRepositoryProvider = Provider<VehicleRepository>(
  (ref) => VehicleRepository(
    ref.watch(keyValueStoreProvider),
    ref.watch(recordRepositoryProvider),
    ref.watch(costRepositoryProvider),
  ),
);
