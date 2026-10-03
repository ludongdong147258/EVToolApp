import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/domain/export_data.dart';
import 'package:ev_tool_app/core/domain/inspection_memo_calc.dart';
import 'package:ev_tool_app/core/domain/numbers.dart';
import 'package:ev_tool_app/core/storage/key_value_store.dart';
import 'package:ev_tool_app/core/utils/logger.dart';
import 'package:ev_tool_app/features/records/data/repositories/record_repository.dart';

/// 年检维保备忘仓储（移植小程序 memoService.js）。
///
/// 存储key `inspectionMemos`；每车一条（saveMemo 为按 vehicleId 的 upsert）。
class MemoRepository {
  MemoRepository(this._kv);

  static const String storageKey = 'inspectionMemos';
  final KeyValueStore _kv;

  /// 全部备忘（按 updatedAt 降序）。
  List<MemoItem> getMemos() {
    final raw = _kv.getJsonList(storageKey);
    if (raw == null) return [];
    final memos = <MemoItem>[];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) continue;
      final memo = normalizeStoredMemo(_inputFromMap(item));
      if (memo != null) memos.add(memo);
    }
    memos.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return memos;
  }

  MemoItem? getMemoByVehicle(String vehicleId) {
    for (final memo in getMemos()) {
      if (memo.vehicleId == vehicleId) return memo;
    }
    return null;
  }

  /// 保存（按 vehicleId upsert，保留既有 id/createdAt）。
  Future<List<MemoItem>> saveMemo(MemoItem memo) async {
    if (memo.vehicleId.isEmpty ||
        parseDateStr(memo.registrationDate) == null ||
        memo.mileageKm <= 0) {
      throw const StorageException('Invalid memo details');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final memos = getMemos();
    final next = <MemoItem>[];
    var replaced = false;
    for (final existing in memos) {
      if (existing.vehicleId == memo.vehicleId) {
        next.add(
          MemoItem(
            id: existing.id,
            vehicleId: memo.vehicleId,
            vehicleName: memo.vehicleName,
            registrationDate: memo.registrationDate,
            mileageKm: memo.mileageKm,
            insuranceExpiryDate: memo.insuranceExpiryDate,
            createdAt: existing.createdAt,
            updatedAt: now,
          ),
        );
        replaced = true;
      } else {
        next.add(existing);
      }
    }
    if (!replaced) {
      next.add(
        MemoItem(
          id: memo.id.isEmpty ? generateId(nowMs: now) : memo.id,
          vehicleId: memo.vehicleId,
          vehicleName: memo.vehicleName,
          registrationDate: memo.registrationDate,
          mileageKm: memo.mileageKm,
          insuranceExpiryDate: memo.insuranceExpiryDate,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    await _save(next);
    return getMemos();
  }

  Future<List<MemoItem>> removeMemo(String vehicleId) async {
    final next = [
      for (final memo in getMemos())
        if (memo.vehicleId != vehicleId) memo,
    ];
    await _save(next);
    return next;
  }

  /// 批量导入（id 去重 + vehicleId 去重，同车备份条目跳过）。
  Future<ImportPick<MemoItem>> importMemos(List<MemoItem> incoming) async {
    final memos = getMemos();
    final existingIds = {for (final m in memos) m.id};
    final existingVehicleIds = {for (final m in memos) m.vehicleId};
    final toAdd = <MemoItem>[];
    var skippedCount = 0;
    for (final memo in incoming) {
      if (memo.id.isEmpty ||
          existingIds.contains(memo.id) ||
          existingVehicleIds.contains(memo.vehicleId)) {
        skippedCount += 1;
        continue;
      }
      existingIds.add(memo.id);
      existingVehicleIds.add(memo.vehicleId);
      toAdd.add(memo);
    }
    await _save([...toAdd, ...memos]);
    return ImportPick(toAdd: toAdd, skippedCount: skippedCount);
  }

  Future<void> _save(List<MemoItem> memos) {
    try {
      return _kv.setJson(storageKey, [
        for (final memo in memos)
          {
            'id': memo.id,
            'vehicleId': memo.vehicleId,
            'vehicleName': memo.vehicleName,
            'registrationDate': memo.registrationDate,
            'mileageKm': memo.mileageKm,
            'insuranceExpiryDate': memo.insuranceExpiryDate,
            'createdAt': memo.createdAt,
            'updatedAt': memo.updatedAt,
          },
      ]);
    } on Exception catch (e) {
      appLogger.e('Failed to save memos', error: e);
      throw const StorageException('Failed to save memo');
    }
  }

  static MemoInput _inputFromMap(Map<String, dynamic> m) => MemoInput(
    id: m['id'],
    vehicleId: m['vehicleId'],
    vehicleName: m['vehicleName'] is String ? m['vehicleName'] : null,
    registrationDate: m['registrationDate'] is String
        ? m['registrationDate']
        : '',
    mileageKm: m['mileageKm'],
    insuranceExpiryDate: m['insuranceExpiryDate'] is String
        ? m['insuranceExpiryDate']
        : null,
    createdAt: m['createdAt'],
    updatedAt: m['updatedAt'],
  );
}

final memoRepositoryProvider = Provider<MemoRepository>(
  (ref) => MemoRepository(ref.watch(keyValueStoreProvider)),
);
