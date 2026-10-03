/// 充电小票 OCR 识别纯函数层
///
/// 移植自 EVTool 小程序 src/lib/ocrReceipt.js。
/// 职责：GLM-4V-Flash 的 prompt 常量、模型输出容错解析、
/// 识别结果 → record-add 表单字段归一化（置信度过滤 + 合法性校验）。
/// 网络与图片读取在服务层，此文件无副作用可单测。
library;

import 'dart:convert';
import 'dart:math' as math;

/// 字段置信度低于该阈值时留空，避免误填覆盖用户手输
const double confidenceThreshold = 0.6;

/// 备注最大长度（与充电记录 note 字段同口径）
const int noteMaxLength = 100;

/// 充电时长上限（小时），72h * 60 = 4320 分钟
const int maxDurationHours = 72;

/// 日期字符串格式 "YYYY-MM-DD"
final RegExp dateRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// 等比缩放目标尺寸
class TargetSize {
  const TargetSize({
    required this.targetWidth,
    required this.targetHeight,
    required this.needsScale,
  });

  final double targetWidth;
  final double targetHeight;
  final bool needsScale;

  @override
  bool operator ==(Object other) =>
      other is TargetSize &&
      other.targetWidth == targetWidth &&
      other.targetHeight == targetHeight &&
      other.needsScale == needsScale;

  @override
  int get hashCode => Object.hash(targetWidth, targetHeight, needsScale);
}

/// 归一化后的 record-add 表单字段
class ReceiptResult {
  const ReceiptResult({
    this.cost = '',
    this.energy = '',
    this.hours = '',
    this.minutes = '',
    this.date = '',
    this.note = '',
    this.chargeType = '',
    this.filledFields = const [],
  });

  final String cost;
  final String energy;
  final String hours;
  final String minutes;
  final String date;
  final String note;
  final String chargeType;

  /// 有效字段名列表（供页面 toast「已识别 N 项」）
  final List<String> filledFields;
}

/// JS `Number()` 语义：null → 0（Number(null) === 0），非法值返回 NaN
double _toNumber(dynamic value) {
  if (value == null) {
    return 0;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is bool) {
    return value ? 1 : 0;
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 0;
    }
    return double.tryParse(trimmed) ?? double.nan;
  }
  return double.nan;
}

/// JS `String(num)` 语义：整数值 double 不带小数点（25.0 → "25"）
String _numberToString(num value) {
  if (value == value.truncateToDouble() && value.abs() < 1e21) {
    return value.truncate().toString();
  }
  return value.toString();
}

/// 数字 → 两位补零字符串
String _pad2(int value) => value < 10 ? '0$value' : '$value';

/// 今天的日期字符串 "YYYY-MM-DD"（[now] 可注入，测试用）
String getTodayStr([DateTime? now]) {
  final dateTime = now ?? DateTime.now();
  return '${dateTime.year}-${_pad2(dateTime.month)}-${_pad2(dateTime.day)}';
}

/// 计算等比缩放目标尺寸（长边超过 maxSide 才缩，永不放大）
///
/// 入参非法（非正数）时 needsScale 为 false（调用方按原图处理）。
TargetSize computeTargetSize(num? width, num? height, num? maxSide) {
  final w = _toNumber(width);
  final h = _toNumber(height);
  final side = _toNumber(maxSide);
  final isInvalid =
      !w.isFinite ||
      !h.isFinite ||
      w <= 0 ||
      h <= 0 ||
      !side.isFinite ||
      side <= 0;
  if (isInvalid) {
    return TargetSize(targetWidth: w, targetHeight: h, needsScale: false);
  }
  final longest = math.max(w, h);
  if (longest <= side) {
    return TargetSize(targetWidth: w, targetHeight: h, needsScale: false);
  }
  final scale = side / longest;
  return TargetSize(
    targetWidth: (w * scale).roundToDouble(),
    targetHeight: (h * scale).roundToDouble(),
    needsScale: true,
  );
}

/// GLM-4V-Flash 识别 prompt（双语：中英文小票均可识别，始终输出英文值）：
/// 要求只输出一个 JSON 对象，字段语义见下方 schema
const String ocrPrompt = '''
You are a charging receipt recognition assistant / 充电小票识别助手。Carefully read the charging order receipt in the image (it may be in Chinese or English). Output ONLY one JSON object, with no explanations, markdown code fences, or extra text. Field definitions:
{
  "stationName": "Charging station or operator name, translated into English. string or null",
  "totalEnergyKwh": "Total energy charged this session (kWh / 度). number or null",
  "totalCostYuan": "Total amount actually paid for this order (CNY / 元). When the receipt lists itemized fees such as energy fee + service fee, take the sum of all items (i.e. the total / amount due), NOT just the energy fee. number or null",
  "durationMinutes": "Total charging duration converted to whole minutes. If the receipt gives start/end times, duration = end - start, e.g. 14:05 to 15:28 = 83. integer or null",
  "date": "Date from the receipt, format YYYY-MM-DD; null if the receipt shows only a time without a date",
  "chargeType": "Infer from station characteristics: public DC fast charger = \\"fast\\", home/private charger = \\"home\\", null if uncertain"
}
Notes: field values must be plain strings/numbers/null — never nested objects. Additionally output a top-level "confidence" object giving a 0-1 recognition confidence for each field above (if a field is unreadable or absent, its value is null and confidence is 0).
Requirements: read all numbers from the image, never fabricate values; convert units correctly (度 = kWh; keep decimal precision for CNY amounts).''';

final RegExp _fenceRe = RegExp(r'```(?:json)?\s*([\s\S]*?)```');

Map<String, dynamic>? _tryDecode(String text) {
  try {
    final decoded = jsonDecode(text);
    return decoded is Map<String, dynamic> ? decoded : null;
  } on FormatException {
    return null;
  }
}

/// 容错提取模型输出中的 JSON 对象。
///
/// 模型偶尔会带 markdown 围栏或前后缀文本，依次尝试：
/// 直接 parse → 剥 ```json / ``` 围栏 → 首个 { 到最后一个 } 的子串。
/// 解析失败或解析结果不是 JSON 对象时返回 null。
Map<String, dynamic>? extractJsonBlock(String? rawText) {
  final text = rawText?.trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  final direct = _tryDecode(text);
  if (direct != null) {
    return direct;
  }
  final fenced = _fenceRe.firstMatch(text);
  if (fenced != null) {
    final inner = fenced.group(1)?.trim();
    if (inner != null) {
      final decoded = _tryDecode(inner);
      if (decoded != null) {
        return decoded;
      }
    }
  }
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start >= 0 && end > start) {
    return _tryDecode(text.substring(start, end + 1));
  }
  return null;
}

/// 数值字段：有限数且 > 0 才有效，转字符串匹配表单 state 类型
String _toPositiveString(dynamic value) {
  final num = _toNumber(value);
  if (!num.isFinite || num <= 0) {
    return '';
  }
  return _numberToString(num);
}

/// 日期字段：YYYY-MM-DD 且不晚于今天才有效（与页面 Picker end 同口径）
String _toValidDate(dynamic value, DateTime? now) {
  if (value is! String) {
    return '';
  }
  final dateStr = value.trim();
  if (!dateRe.hasMatch(dateStr)) {
    return '';
  }
  return dateStr.compareTo(getTodayStr(now)) > 0 ? '' : dateStr;
}

/// 单个识别字段的读取结果（兼容扁平与嵌套两种真实输出）
class _FieldReading {
  const _FieldReading(this.value, this.confidence);

  final dynamic value;
  final dynamic confidence;
}

/// 读取单个识别字段。
///
/// 兼容两种真实输出：扁平结构（字段值 + 顶层 confidence 映射）与
/// 嵌套结构（字段为 { value, confidence }——glm 系模型不严格遵守 prompt 时常见）。
_FieldReading _readField(
  Map<String, dynamic> parsed,
  Map<String, dynamic> confidenceMap,
  String field,
) {
  final raw = parsed[field];
  if (raw is Map) {
    final nested = Map<String, dynamic>.from(raw);
    return _FieldReading(nested['value'], nested['confidence']);
  }
  return _FieldReading(raw, confidenceMap[field]);
}

/// JS `Number(confidence ?? 1)`：缺省置信度按 1 处理
bool _isConfident(dynamic confidence) {
  final num = confidence == null ? 1.0 : _toNumber(confidence);
  return num.isFinite && num >= confidenceThreshold;
}

/// 识别结果归一化为 record-add 表单字段。
///
/// 仅包含通过校验的字段；filledFields 为有效字段名列表
/// （供页面 toast「已识别 N 项」）。[now] 可注入当前时间（测试用）。
ReceiptResult normalizeReceiptResult(
  Map<String, dynamic>? parsed, {
  DateTime? now,
}) {
  if (parsed == null) {
    return const ReceiptResult();
  }
  final confidenceMap = parsed['confidence'] is Map
      ? Map<String, dynamic>.from(parsed['confidence'] as Map)
      : <String, dynamic>{};

  var cost = '';
  var energy = '';
  var hours = '';
  var minutes = '';
  var date = '';
  var note = '';
  var chargeType = '';
  final filledFields = <String>[];

  final costField = _readField(parsed, confidenceMap, 'totalCostYuan');
  if (_isConfident(costField.confidence)) {
    final value = _toPositiveString(costField.value);
    if (value.isNotEmpty) {
      cost = value;
      filledFields.add('cost');
    }
  }
  final energyField = _readField(parsed, confidenceMap, 'totalEnergyKwh');
  if (_isConfident(energyField.confidence)) {
    final value = _toPositiveString(energyField.value);
    if (value.isNotEmpty) {
      energy = value;
      filledFields.add('energy');
    }
  }
  final durationField = _readField(parsed, confidenceMap, 'durationMinutes');
  if (_isConfident(durationField.confidence)) {
    final raw = _toNumber(durationField.value);
    final minutesTotal = raw.isFinite ? raw.roundToDouble() : double.nan;
    const maxMinutes = maxDurationHours * 60;
    if (minutesTotal.isFinite &&
        minutesTotal >= 1 &&
        minutesTotal <= maxMinutes) {
      final total = minutesTotal.toInt();
      hours = _numberToString(total ~/ 60);
      minutes = _numberToString(total % 60);
      filledFields.add('duration');
    }
  }
  final dateField = _readField(parsed, confidenceMap, 'date');
  if (_isConfident(dateField.confidence)) {
    final value = _toValidDate(dateField.value, now);
    if (value.isNotEmpty) {
      date = value;
      filledFields.add('date');
    }
  }
  final stationField = _readField(parsed, confidenceMap, 'stationName');
  if (_isConfident(stationField.confidence) && stationField.value is String) {
    final trimmed = (stationField.value as String).trim();
    note = trimmed.length > noteMaxLength
        ? trimmed.substring(0, noteMaxLength)
        : trimmed;
    if (note.isNotEmpty) {
      filledFields.add('note');
    }
  }
  final typeField = _readField(parsed, confidenceMap, 'chargeType');
  if (typeField.value == 'fast' || typeField.value == 'home') {
    chargeType = typeField.value as String;
    filledFields.add('chargeType');
  }
  return ReceiptResult(
    cost: cost,
    energy: energy,
    hours: hours,
    minutes: minutes,
    date: date,
    note: note,
    chargeType: chargeType,
    filledFields: List.unmodifiable(filledFields),
  );
}
