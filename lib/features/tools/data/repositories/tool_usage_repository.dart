import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/domain/recent_tools.dart';
import 'package:ev_tool_app/core/storage/key_value_store.dart';
import 'package:ev_tool_app/core/utils/logger.dart';

/// 工具「最近使用」记录仓储（移植小程序 toolUsageService.js）。
///
/// 存储 key `toolsRecentUse`（JSON 字符串数组）；读取过滤脏数据，
/// 写入走 pushRecentTool（置顶去重，保留最近 3 个）。
/// 错误策略与 JS 一致：非关键数据，读失败返回 []、写失败仅 log 不抛错。
class ToolUsageRepository {
  ToolUsageRepository(this._kv);

  static const String storageKey = 'toolsRecentUse';
  final KeyValueStore _kv;

  /// 最近使用的工具 id 列表；storage 无数据或解析异常时返回 []。
  List<String> getRecentToolIds() {
    final List<dynamic>? raw;
    try {
      raw = _kv.getJsonList(storageKey);
    } on Exception catch (e) {
      appLogger.e('读取工具使用记录失败', error: e);
      return const <String>[];
    }
    if (raw == null) return const <String>[];
    return [
      for (final item in raw)
        if (item is String && item.isNotEmpty) item,
    ];
  }

  /// 记录一次工具使用（置顶去重，保留最近 [recentToolsLimit] 个）。
  ///
  /// 写失败静默（非关键数据，不阻断工具页导航）；返回 Future 仅表示
  /// 落盘完成，调用方可安全忽略。
  Future<void> trackToolUse(String toolId) async {
    final next = pushRecentTool(getRecentToolIds(), toolId);
    try {
      await _kv.setJson(storageKey, next);
    } on Exception catch (e) {
      appLogger.e('保存工具使用记录失败', error: e);
    }
  }
}

final toolUsageRepositoryProvider = Provider<ToolUsageRepository>(
  (ref) => ToolUsageRepository(ref.watch(keyValueStoreProvider)),
);
