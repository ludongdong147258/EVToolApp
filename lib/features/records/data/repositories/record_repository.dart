import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/domain/charge_records.dart';
import 'package:ev_tool_app/core/domain/date_utils.dart';
import 'package:ev_tool_app/core/domain/export_data.dart';
import 'package:ev_tool_app/core/storage/key_value_store.dart';
import 'package:ev_tool_app/core/utils/logger.dart';

/// 充电记录仓储（移植小程序 recordService.js）。
///
/// 存储key `chargeRecords`，JSON 数组；读 → normalize 过滤 → 降序排序；
/// 写失败抛 [StorageException] 由页面层捕获 toast。
class StorageException implements Exception {
  const StorageException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RecordRepository {
  RecordRepository(this._kv);

  static const String storageKey = 'chargeRecords';
  final KeyValueStore _kv;

  /// 全量记录（date 降序，同日按 createdAt 降序）。
  List<ChargeRecord> getRecords() {
    final raw = _kv.getJsonList(storageKey);
    if (raw == null) return [];
    final records = <ChargeRecord>[];
    for (final item in raw) {
      final record = normalizeStoredRecord(item);
      if (record != null) records.add(record);
    }
    return sortRecordsDesc(records);
  }

  /// 新增（prepend）；记录保持原 id / createdAt。
  Future<List<ChargeRecord>> addRecord(ChargeRecord record) async {
    final records = getRecords();
    final next = [record, ...records];
    await _save(next);
    return sortRecordsDesc(next);
  }

  /// 更新：保留既有 id 与 createdAt；id 不存在时幂等返回。
  Future<List<ChargeRecord>> updateRecord(String id, ChargeRecord next) async {
    final records = getRecords();
    var found = false;
    final mapped = [
      for (final record in records)
        record.id == id
            ? () {
                found = true;
                return next.copyWith(
                  id: record.id,
                  createdAt: record.createdAt,
                );
              }()
            : record,
    ];
    if (found) {
      await _save(mapped);
      return sortRecordsDesc(mapped);
    }
    return records;
  }

  /// 删除（幂等）。
  Future<List<ChargeRecord>> removeRecord(String id) async {
    final next = [
      for (final record in getRecords())
        if (record.id != id) record,
    ];
    await _save(next);
    return next;
  }

  /// 批量导入（按 id 去重，仅添加本地不存在的）。
  Future<ImportPick<ChargeRecord>> importRecords(
    List<ChargeRecord> incoming,
  ) async {
    final pick = pickImportItems(getRecords(), incoming, (r) => r.id);
    final merged = [...pick.toAdd, ...getRecords()];
    await _save(merged);
    return pick;
  }

  List<ChargeRecord> getRecordsForMonth(String monthKey) => [
    for (final record in getRecords())
      if (getMonthKey(record.date) == monthKey) record,
  ];

  /// 车辆改名 → 同步记录快照（vehicleName）。
  Future<void> syncVehicleRename(String vehicleId, String nextName) async {
    await _save(applyVehicleSnapshotRename(getRecords(), vehicleId, nextName));
  }

  /// 车辆删除 → 清空记录上的车辆关联快照。
  Future<void> syncVehicleRemoval(String vehicleId) async {
    await _save(applyVehicleSnapshotRemoval(getRecords(), vehicleId));
  }

  Future<void> _save(List<ChargeRecord> records) {
    try {
      return _kv.setJson(storageKey, [
        for (final record in records) record.toJson(),
      ]);
    } on Exception catch (e) {
      appLogger.e('保存充电记录失败', error: e);
      throw const StorageException('记录保存失败');
    }
  }
}

final recordRepositoryProvider = Provider<RecordRepository>(
  (ref) => RecordRepository(ref.watch(keyValueStoreProvider)),
);
