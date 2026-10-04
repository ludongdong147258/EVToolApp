import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/constants/app_constants.dart';
import 'package:ev_tool_app/core/domain/date_utils.dart';
import 'package:ev_tool_app/core/storage/key_value_store.dart';
import 'package:ev_tool_app/core/utils/logger.dart';

/// OCR 免费额度用量仓储（免费档每月 [AppConstants.freeOcrMonthlyQuota] 次）。
///
/// 存储 key `ocrUsage`：`{"month": "yyyy-MM", "count": 5}`。
/// 读取时 month 与当前月不一致即视为 0（跨月自动归零，无需清理任务）。
/// 错误策略对齐 ToolUsageRepository：读失败按 0 处理，写失败仅 log。
class OcrUsageRepository {
  OcrUsageRepository(this._kv);

  static const String storageKey = 'ocrUsage';
  final KeyValueStore _kv;

  /// 本月已用次数（脏数据/跨月/无记录均返回 0）。
  int usedThisMonth({DateTime? now}) {
    final Map<String, dynamic>? raw;
    try {
      raw = _kv.getJsonMap(storageKey);
    } on Exception catch (e) {
      appLogger.e('Failed to load OCR usage', error: e);
      return 0;
    }
    if (raw == null) return 0;
    if (raw['month'] != getCurrentMonthKey(now: now)) return 0;
    final count = raw['count'];
    if (count is! int || count < 0) return 0;
    return count;
  }

  /// 本月剩余免费次数（不为负）。
  int remaining({DateTime? now}) {
    final left = AppConstants.freeOcrMonthlyQuota - usedThisMonth(now: now);
    return left < 0 ? 0 : left;
  }

  /// 是否还有免费额度。
  bool hasQuota({DateTime? now}) => remaining(now: now) > 0;

  /// 成功识别后计数 +1；写失败静默（不阻断识别结果回填）。
  Future<void> increment({DateTime? now}) async {
    final next = {
      'month': getCurrentMonthKey(now: now),
      'count': usedThisMonth(now: now) + 1,
    };
    try {
      await _kv.setJson(storageKey, next);
    } on Exception catch (e) {
      appLogger.e('Failed to save OCR usage', error: e);
    }
  }
}

final ocrUsageRepositoryProvider = Provider<OcrUsageRepository>(
  (ref) => OcrUsageRepository(ref.watch(keyValueStoreProvider)),
);
