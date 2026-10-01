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

/// GLM-4V-Flash 识别 prompt：要求只输出一个 JSON 对象，字段语义见下方 schema
const String ocrPrompt = '''
你是充电小票识别助手。请仔细阅读图片中的充电订单小票，只输出一个 JSON 对象，不要任何解释、markdown 代码块或多余文本。字段定义：
{
  "stationName": "电站/运营商名称，string 或 null",
  "totalEnergyKwh": "本次充电总电量（度/kWh），number 或 null",
  "totalCostYuan": "本次订单实付总费用（元）。小票有电费/服务费等分项时必须取各项之和（即合计/实付金额），不要只取电费分项。number 或 null",
  "durationMinutes": "充电总时长折算为分钟整数。小票给开始/结束时间时按时长=结束时间-开始时间计算，如 14:05 至 15:28 = 83。integer 或 null",
  "date": "小票上的日期，格式 YYYY-MM-DD；小票只有时间没有日期则为 null",
  "chargeType": "根据电站特征推断：公共快充桩为 \\"fast\\"，家用/私桩为 \\"home\\"，不确定为 null"
}
注意：以上字段的值必须直接是字符串/数字/null，不要嵌套对象。另外在顶层输出 "confidence" 对象，为上述每个字段给出 0-1 的识别置信度（看不清或不存在时字段值为 null 且置信度给 0）。
要求：所有数值从图片中读取，禁止编造；单位换算要正确（度=kWh，元保留小数）。''';

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
