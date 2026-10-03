import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/domain/home_charger_calc.dart';
import 'package:ev_tool_app/core/storage/key_value_store.dart';
import 'package:ev_tool_app/core/utils/logger.dart';
import 'package:ev_tool_app/features/records/data/repositories/record_repository.dart'
    show StorageException;

/// 私桩测算结果仓储（移植小程序 estimateService.js）。
///
/// 存储 key `homeChargerEstimate`（沿用旧版直写时的 key，保证数据延续）。
/// 兼容旧版单对象形态（无 id、非数组），读取时包成单元素数组；
/// 读出时逐条 normalizeStoredEstimate（用入参重算校验和过滤脏数据），
/// 按保存时间降序。写失败抛 [StorageException] 由页面层捕获 toast。
class EstimateRepository {
  EstimateRepository(this._kv);

  static const String storageKey = 'homeChargerEstimate';
  final KeyValueStore _kv;

  /// 全部已保存测算（已过滤脏数据并按保存时间降序）。
  List<StoredEstimate> getEstimates() {
    final dynamic raw;
    try {
      raw = _kv.getJson(storageKey);
    } on Exception catch (e) {
      appLogger.e('Failed to load charger estimates', error: e);
      return const <StoredEstimate>[];
    }
    if (raw == null) return const <StoredEstimate>[];

    /* 旧版单对象 → 补合成 id 后包成单元素数组，走同一套列表守卫 */
    final List<dynamic> list = raw is List
        ? raw
        : <dynamic>[legacyWrap(raw as Map<String, dynamic>)];
    final estimates = <StoredEstimate>[];
    for (final item in list) {
      if (item is! Map) continue;
      final estimate = normalizeStoredEstimate(
        storedEstimateInputFromJson(item.cast<String, dynamic>()),
      );
      if (estimate != null) estimates.add(estimate);
    }
    estimates.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return estimates;
  }

  /// 保存一条测算（前插并截断上限 [maxSavedEstimates]）。
  Future<List<StoredEstimate>> saveEstimate(StoredEstimate entry) async {
    final next = <StoredEstimate>[entry, ...getEstimates()];
    final capped = next.length > maxSavedEstimates
        ? next.sublist(0, maxSavedEstimates)
        : next;
    await _save(capped);
    return capped;
  }

  /// 按 id 删除测算（id 不存在时为幂等 no-op）。
  Future<List<StoredEstimate>> removeEstimate(String id) async {
    final next = [
      for (final estimate in getEstimates())
        if (estimate.id != id) estimate,
    ];
    await _save(next);
    return next;
  }

  Future<void> _save(List<StoredEstimate> estimates) async {
    try {
      await _kv.setJson(storageKey, [
        for (final estimate in estimates) storedEstimateToJson(estimate),
      ]);
    } on Exception catch (e) {
      appLogger.e('Failed to save charger estimate', error: e);
      throw const StorageException('Failed to save');
    }
  }
}

/// 旧版单对象合成 id：savedAt 缺失时给 0（normalize 会判脏丢弃）。
Map<String, dynamic> legacyWrap(Map<String, dynamic> raw) {
  final dynamic savedAt = raw['savedAt'];
  final int fallback = savedAt is num ? savedAt.toInt() : 0;
  final dynamic id = raw['id'];
  return <String, dynamic>{
    ...raw,
    'id': id is String && id.isNotEmpty ? id : 'legacy-$fallback',
  };
}

/// 存储单条测算 → JSON（storage 结构与小程序保持一致）。
Map<String, dynamic> storedEstimateToJson(StoredEstimate estimate) {
  return <String, dynamic>{
    'id': estimate.id,
    'cableLength': estimate.cableLength,
    'powerId': estimate.powerId,
    'spot': estimate.spot,
    'conditions': estimate.conditions,
    'estimate': <String, dynamic>{
      'basePrice': estimate.estimate.basePrice,
      'extraCableLength': estimate.estimate.extraCableLength,
      'extraCableCost': estimate.estimate.extraCableCost,
      'surcharges': <Map<String, dynamic>>[
        for (final item in estimate.estimate.surcharges)
          <String, dynamic>{'id': item.id, 'price': item.price},
      ],
      'surchargeTotal': estimate.estimate.surchargeTotal,
      'total': estimate.estimate.total,
    },
    'savedAt': estimate.savedAt,
  };
}

/// JSON → 存储单条测算入参（供 normalizeStoredEstimate 重算校验）。
StoredEstimateInput storedEstimateInputFromJson(Map<String, dynamic> json) {
  final dynamic conditions = json['conditions'];
  return StoredEstimateInput(
    id: json['id'],
    cableLength: json['cableLength'],
    powerId: json['powerId'] is String ? json['powerId'] as String? : null,
    spot: json['spot'] is String ? json['spot'] as String? : null,
    conditions: conditions is Map
        ? <String, bool>{
            for (final entry in conditions.entries)
              if (entry.key is String && entry.value is bool)
                entry.key as String: entry.value as bool,
          }
        : const <String, bool>{},
    savedAt: json['savedAt'],
  );
}

final estimateRepositoryProvider = Provider<EstimateRepository>(
  (ref) => EstimateRepository(ref.watch(keyValueStoreProvider)),
);
