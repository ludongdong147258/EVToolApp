/// 数值与格式化共享工具（纯函数）
///
/// 移植自 EVTool（Taro）src/lib/numbers.js，逻辑保持一致：
/// 非法输入返回 null / 兜底值，绝不抛错。
library;

import 'dart:math';

/// JS parseFloat 的数值前缀（跳过首尾空白、接受尾随垃圾字符）
final RegExp _parseFloatPrefix = RegExp(
  r'^[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?',
);

final Random _random = Random();

/// 宽松转数字（输入框字符串 → number）
///
/// 与 JS Number.isFinite 同口径：NaN / Infinity → null。
num? toNumber(dynamic value) {
  if (value is num) {
    return value.isFinite ? value : null;
  }
  if (value is String) {
    var text = value.trim();
    final match = _parseFloatPrefix.firstMatch(text);
    if (match == null) {
      return null;
    }
    text = match.group(0) ?? '';
    if (text.endsWith('.')) {
      text = text.substring(0, text.length - 1);
    }
    final parsed = double.tryParse(text);
    if (parsed == null || !parsed.isFinite) {
      return null;
    }
    return parsed;
  }
  return null;
}

/// JS Math.round：floor(x + 0.5)（.5 向上取整，负数口径与 JS 一致）
double jsRound(num value) {
  return (value.toDouble() + 0.5).floorToDouble();
}

/// 分安全取整到两位小数（避免 0.1 + 0.2 浮点误差）
double toYuan(num value) {
  return jsRound(value.toDouble() * 100) / 100;
}

/// 整数部分加千分位（等价 JS 正则 \B(?=(\d{3})+(?!\d))）
String _withCommas(String intPart) {
  final isNegative = intPart.startsWith('-');
  final digits = isNegative ? intPart.substring(1) : intPart;
  final buffer = StringBuffer();
  final count = digits.length;
  for (var i = 0; i < count; i++) {
    buffer.write(digits[i]);
    final remaining = count - i - 1;
    if (remaining > 0 && remaining % 3 == 0) {
      buffer.write(',');
    }
  }
  return isNegative ? '-${buffer.toString()}' : buffer.toString();
}

/// 金额格式化（两位小数 + 千分位），小程序端避免依赖 toLocaleString
///
/// 345.5 → "345.50"；1234567.891 → "1,234,567.89"；非法 → "0.00"
String formatYuan(dynamic value) {
  final numValue = toNumber(value);
  if (numValue == null) {
    return '0.00';
  }
  final parts = toYuan(numValue).toStringAsFixed(2).split('.');
  return '${_withCommas(parts[0])}.${parts[1]}';
}

/// 金额千分位格式化（整数元），小程序端避免依赖 toLocaleString
///
/// 如 2850 → "2,850"
String formatAmount(num value) {
  return _withCommas(jsRound(value).toInt().toString());
}

/// 电商价签格式化（分 → 元），整数省略小数
///
/// 与 formatYuan（恒两位小数）不同，适配商品价签展示习惯。
/// 1299 → "12.99"；1200 → "12"；0 → "0"；非法/负值 → "0"
String formatPrice(dynamic value) {
  final cents = toNumber(value);
  if (cents == null || cents <= 0) {
    return '0';
  }
  final yuan = cents / 100;
  if (yuan % 1 == 0) {
    return yuan.toInt().toString();
  }
  return yuan.toStringAsFixed(2);
}

/// 本地记录 id 生成（时间戳前缀 + 随机后缀）
///
/// 如 "1755916800000-483920"；[nowMs] 可注入（测试用）
String generateId({int? nowMs}) {
  final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  return '$now-${_random.nextInt(1000000)}';
}

/// 输入合法性：正数且不超上限（兼容输入框字符串形式）
bool isValidPositiveNumber(dynamic value, {num max = double.infinity}) {
  final numValue = toNumber(value);
  return numValue != null && numValue > 0 && numValue <= max;
}
