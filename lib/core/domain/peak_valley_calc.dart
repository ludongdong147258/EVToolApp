/// 峰谷电价计算（纯函数）
///
/// 根据电池容量与目标充电量算出需充入电量，
/// 再按「平准电价」与「峰谷优化（全部谷时充电）」两种策略估算成本。
/// 平准电价按峰/谷/平时长加权：传入时段时用真实时长，
/// 未传时段时退化为峰谷均价 50/50。
library;

import 'package:ev_tool_app/core/domain/numbers.dart';

const int targetMin = 20;
const int targetMax = 100;

class PeakValleyInputs {
  const PeakValleyInputs({
    this.batteryCapacity = 75, // kWh
    this.targetPercent = 60, // 目标充电量 %
    this.peakPrice = 1.25, // ¥/kWh
    this.valleyPrice = 0.35, // ¥/kWh
    this.peakStart, // 峰时起始 "HH:mm"（可选，四项需同时提供）
    this.peakEnd,
    this.valleyStart,
    this.valleyEnd,
  });

  final dynamic batteryCapacity;
  final dynamic targetPercent;
  final dynamic peakPrice;
  final dynamic valleyPrice;
  final String? peakStart;
  final String? peakEnd;
  final String? valleyStart;
  final String? valleyEnd;

  PeakValleyInputs copyWith({
    dynamic batteryCapacity,
    dynamic targetPercent,
    dynamic peakPrice,
    dynamic valleyPrice,
    String? peakStart,
    String? peakEnd,
    String? valleyStart,
    String? valleyEnd,
  }) {
    return PeakValleyInputs(
      batteryCapacity: batteryCapacity ?? this.batteryCapacity,
      targetPercent: targetPercent ?? this.targetPercent,
      peakPrice: peakPrice ?? this.peakPrice,
      valleyPrice: valleyPrice ?? this.valleyPrice,
      peakStart: peakStart ?? this.peakStart,
      peakEnd: peakEnd ?? this.peakEnd,
      valleyStart: valleyStart ?? this.valleyStart,
      valleyEnd: valleyEnd ?? this.valleyEnd,
    );
  }
}

const PeakValleyInputs defaultPeakValleyInputs = PeakValleyInputs();

/// 峰/谷/平时段时长（小时）
class TimeSpans {
  const TimeSpans({
    required this.peakHours,
    required this.valleyHours,
    required this.flatHours,
  });

  final double peakHours;
  final double valleyHours;
  final double flatHours;
}

/// 峰谷充电成本结果（金额均保留两位小数）
class PeakValleyCost {
  const PeakValleyCost({
    required this.energy,
    required this.flatCost,
    required this.optimizedCost,
    required this.saving,
  });

  final double energy;
  final double flatCost;
  final double optimizedCost;
  final double saving;
}

const int _minutesPerDay = 24 * 60;

final RegExp _timeRe = RegExp(r'^(\d{1,2}):(\d{2})$');

/// "08:30" → 510（分钟数）；格式非法返回 null
int? _toMinutes(String? time) {
  final match = _timeRe.firstMatch(time ?? '');
  if (match == null) {
    return null;
  }
  final hours = int.parse(match.group(1)!);
  final minutes = int.parse(match.group(2)!);
  if (hours > 23 || minutes > 59) {
    return null;
  }
  return hours * 60 + minutes;
}

/// 时段时长（分钟），支持跨零点：22:00→08:00 = 600；起止相等视为 0
int? _spanMinutes(String? start, String? end) {
  final startMin = _toMinutes(start);
  final endMin = _toMinutes(end);
  if (startMin == null || endMin == null) {
    return null;
  }
  if (endMin == startMin) {
    return 0;
  }
  return endMin > startMin
      ? endMin - startMin
      : endMin - startMin + _minutesPerDay;
}

/// 判断两个 [start, start+dur) 的环形分钟区间是否重叠
bool _isOverlapping(int startA, int durA, int startB, int durB) {
  final marks = List<bool>.filled(_minutesPerDay, false);
  for (var i = 0; i < durA; i += 1) {
    marks[(startA + i) % _minutesPerDay] = true;
  }
  for (var i = 0; i < durB; i += 1) {
    if (marks[(startB + i) % _minutesPerDay]) {
      return true;
    }
  }
  return false;
}

/// 解析峰/谷时段为时长（小时）
///
/// flatHours 为峰谷未覆盖的平时段时长；格式非法、时长为 0 或峰谷重叠时返回 null
TimeSpans? calcTimeSpans(PeakValleyInputs times) {
  final peakDur = _spanMinutes(times.peakStart, times.peakEnd);
  final valleyDur = _spanMinutes(times.valleyStart, times.valleyEnd);
  if (peakDur == null || valleyDur == null) {
    return null;
  }
  if (peakDur <= 0 || valleyDur <= 0) {
    return null;
  }
  if (peakDur + valleyDur > _minutesPerDay) {
    return null;
  }
  final peakStartMin = _toMinutes(times.peakStart);
  final valleyStartMin = _toMinutes(times.valleyStart);
  if (peakStartMin == null ||
      valleyStartMin == null ||
      _isOverlapping(peakStartMin, peakDur, valleyStartMin, valleyDur)) {
    return null;
  }

  return TimeSpans(
    peakHours: peakDur / 60,
    valleyHours: valleyDur / 60,
    flatHours: (_minutesPerDay - peakDur - valleyDur) / 60,
  );
}

bool _hasTimeInputs(PeakValleyInputs inputs) {
  return inputs.peakStart != null ||
      inputs.peakEnd != null ||
      inputs.valleyStart != null ||
      inputs.valleyEnd != null;
}

/// 计算峰谷充电成本
///
/// 任一参数非法（非数字或 ≤ 0、时段重叠/格式错误）时返回 null
PeakValleyCost? calcPeakValleyCost(PeakValleyInputs inputs) {
  final batteryCapacity = toNumber(inputs.batteryCapacity);
  final targetPercent = toNumber(inputs.targetPercent);
  final peakPrice = toNumber(inputs.peakPrice);
  final valleyPrice = toNumber(inputs.valleyPrice);

  if (batteryCapacity == null ||
      targetPercent == null ||
      peakPrice == null ||
      valleyPrice == null) {
    return null;
  }
  if (batteryCapacity <= 0 ||
      targetPercent <= 0 ||
      peakPrice <= 0 ||
      valleyPrice <= 0) {
    return null;
  }

  final energy = toYuan((batteryCapacity * targetPercent) / 100);
  final avgPrice = (peakPrice + valleyPrice) / 2;

  /* 平准电价：传了时段按峰/谷/平时长加权（平时段用峰谷均价），否则 50/50 */
  var flatUnitPrice = avgPrice;
  if (_hasTimeInputs(inputs)) {
    final spans = calcTimeSpans(inputs);
    if (spans == null) {
      return null;
    }
    flatUnitPrice =
        (spans.peakHours * peakPrice +
            spans.valleyHours * valleyPrice +
            spans.flatHours * avgPrice) /
        24;
  }

  final flatCost = toYuan(energy * flatUnitPrice);
  final optimizedCost = toYuan(energy * valleyPrice);

  return PeakValleyCost(
    energy: energy,
    flatCost: flatCost,
    optimizedCost: optimizedCost,
    saving: toYuan(flatCost - optimizedCost),
  );
}
