/// 工具「最近使用」列表（纯函数）
///
/// 移植自 EVTool 小程序 src/lib/recentTools.js。
/// 工具页置顶展示最近使用的 N 个工具，存储读写由服务层负责。
library;

/// 最近使用列表默认上限
const int recentToolsLimit = 3;

/// 把一个工具 id 置顶到最近使用列表（去重 + 截断，不可变）
///
/// [toolId] 非法（非字符串或空串）或 [limit] 非法（≤0）时，
/// 返回原列表的有效部分；否则返回以 [toolId] 置顶的新列表。
List<String> pushRecentTool(
  List<String>? recentIds,
  Object? toolId, [
  int? limit,
]) {
  final ids = (recentIds ?? const <String>[])
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
  if (toolId is! String || toolId.isEmpty) {
    return ids;
  }
  final effectiveLimit = limit ?? recentToolsLimit;
  if (effectiveLimit <= 0) {
    return ids;
  }
  final next = <String>[toolId, ...ids.where((id) => id != toolId)];
  return next.length <= effectiveLimit ? next : next.sublist(0, effectiveLimit);
}
