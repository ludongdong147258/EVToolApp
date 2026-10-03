/// 日期通用工具（纯函数）
///
/// 移植自 EVTool（Taro）src/lib/dateUtils.js，逻辑保持一致：
/// 非法输入返回 null / 空值，绝不抛错。
library;

import 'package:ev_tool_app/core/domain/numbers.dart';

/// 日期字符串格式 "YYYY-MM-DD"
final RegExp dateRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// 月份 key 格式 "YYYY-MM"
final RegExp monthKeyRe = RegExp(r'^\d{4}-\d{2}$');

/// JS Date 可表示的最大毫秒范围（超出视为 Invalid Date）
const int _maxDateMilliseconds = 8640000000000000;

/// 数字 → 两位补零字符串
String pad2(int value) {
  return value.toString().padLeft(2, '0');
}

/// 日期字符串是否合法（格式 + 历法均有效）
///
/// 注：JS 引擎会把 "2025-02-30" 滚动解析为 3 月 2 日（不产生 NaN），
/// 该口径沿用原实现：月必须 01-12，日 01-31 视为合法（滚动），
/// 仅拦截月份越界、日 > 31 等真正非法值。
bool isValidDateString(dynamic value) {
  if (value is! String || !dateRe.hasMatch(value)) {
    return false;
  }
  final month = int.parse(value.substring(5, 7));
  final day = int.parse(value.substring(8, 10));
  return month >= 1 && month <= 12 && day >= 1 && day <= 31;
}

/// 今天的日期字符串
///
/// [now] 可注入的当前时间（测试用）；返回 "YYYY-MM-DD"
String getTodayStr({DateTime? now}) {
  final current = now ?? DateTime.now();
  return '${current.year}-${pad2(current.month)}-${pad2(current.day)}';
}

/// 日期字符串 → 月份 key（只做字符串切割，不校验历法）
///
/// "YYYY-MM-DD" → "YYYY-MM"，格式非法返回 null
String? getMonthKey(dynamic dateStr) {
  if (dateStr is! String || !dateRe.hasMatch(dateStr)) {
    return null;
  }
  return dateStr.substring(0, 7);
}

/// 当前月份 key（"YYYY-MM"）；[now] 可注入（测试用）
String getCurrentMonthKey({DateTime? now}) {
  final current = now ?? DateTime.now();
  return '${current.year}-${pad2(current.month)}';
}

/// 英文月份缩写（Jan..Dec）
const List<String> monthShortNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// 日期字符串 → "Aug 28"（列表/卡片用）；格式非法返回 ""
String formatMonthDay(dynamic dateStr) {
  if (dateStr is! String || !dateRe.hasMatch(dateStr)) {
    return '';
  }
  final month = int.parse(dateStr.substring(5, 7));
  final day = int.parse(dateStr.substring(8, 10));
  return '${monthShortNames[month - 1]} $day';
}

/// 日期字符串 → "Aug 28, 2026"（完整日期）；格式非法返回 ""
String formatFullDate(dynamic dateStr) {
  if (dateStr is! String || !dateRe.hasMatch(dateStr)) {
    return '';
  }
  final year = dateStr.substring(0, 4);
  return '${formatMonthDay(dateStr)}, $year';
}

/// 月份 key → "Aug 2026"（图表/导航标签）；格式非法返回 ""
String formatMonthLabel(dynamic monthKey) {
  if (monthKey is! String || !monthKeyRe.hasMatch(monthKey)) {
    return '';
  }
  final month = int.parse(monthKey.substring(5, 7));
  return '${monthShortNames[month - 1]} ${monthKey.substring(0, 4)}';
}

/// 时间戳 → 日期字符串（"YYYY-MM-DD"，手拼避免 toLocaleString 兼容问题）
///
/// 1754000000000 → "2025-08-01"；非法 → ""
String formatTimestampDate(dynamic ts) {
  final numValue = toNumber(ts);
  if (numValue == null || numValue <= 0) {
    return '';
  }
  if (numValue.abs() > _maxDateMilliseconds) {
    return '';
  }
  final date = DateTime.fromMillisecondsSinceEpoch(numValue.round());
  return '${date.year}-${pad2(date.month)}-${pad2(date.day)}';
}
