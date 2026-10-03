import 'dart:convert';

import 'package:ev_tool_app/core/domain/charge_records.dart';
import 'package:ev_tool_app/core/domain/inspection_memo_calc.dart';
import 'package:ev_tool_app/core/domain/maintenance_costs.dart';
import 'package:ev_tool_app/core/domain/vehicles.dart';

/// 数据导出（纯函数，移植小程序 src/lib/exportData.js）。
///
/// CSV 前置 BOM 保证 Excel 中文不乱码；JSON 带版本号 v1（与小程序备份
/// 双向兼容）。非法输入返回空结果，绝不抛错。

const String csvBom = '﻿';

const String _recordCsvHeader =
    'Date,Type,Cost (\$),Energy (kWh),Duration (min),Cost per kWh (\$/kWh),Vehicle,Note';
const String _vehicleCsvHeader = 'Vehicle Name,Battery (kWh),Note,Default';

final RegExp _csvEscapeRe = RegExp(r'[",\n\r]');

/// CSV 单元格转义：含逗号/引号/换行时双引号包裹，内部引号翻倍。
String escapeCsvCell(Object? value) {
  final text = value == null ? '' : value.toString();
  if (_csvEscapeRe.hasMatch(text)) {
    return '"${text.replaceAll('"', '""')}"';
  }
  return text;
}

String _toCsv(String header, List<String> rows) =>
    '$csvBom${[header, ...rows].join('\n')}\n';

/// 充电记录数组 → CSV 文本（空数组只剩表头）。
String recordsToCsv(List<ChargeRecord>? records) {
  if (records == null) return _toCsv(_recordCsvHeader, []);
  final rows = records.map((record) {
    final costPerKwh = record.cost > 0 && record.energy > 0
        ? (record.cost / record.energy).toStringAsFixed(2)
        : '';
    return [
      record.date,
      typeDefaultTitles[record.type] ?? record.type,
      _numToCsv(record.cost),
      _numToCsv(record.energy),
      record.durationMinutes != null && record.durationMinutes! > 0
          ? record.durationMinutes.toString()
          : '',
      costPerKwh,
      record.vehicleName ?? '',
      record.note,
    ].map(escapeCsvCell).join(',');
  }).toList();
  return _toCsv(_recordCsvHeader, rows);
}

/// JS String(number)：整数 double 序列化为 "30" 而非 "30.0"。
String _numToCsv(num value) =>
    value == value.roundToDouble() && value.abs() < 1e15
    ? value.round().toString()
    : value.toString();

/// 车辆数组 → CSV 文本（空数组只剩表头）。
String vehiclesToCsv(List<Vehicle>? vehicles) {
  if (vehicles == null) return _toCsv(_vehicleCsvHeader, []);
  final rows = vehicles
      .map(
        (vehicle) => [
          vehicle.name,
          _numToCsv(vehicle.battery),
          vehicle.note,
          vehicle.isDefault ? 'Yes' : 'No',
        ].map(escapeCsvCell).join(','),
      )
      .toList();
  return _toCsv(_vehicleCsvHeader, rows);
}

/// 四类本地数据 → JSON 备份结构（充电记录/车辆/养车支出/年检备忘）。
Map<String, dynamic> buildExportJson({
  List<ChargeRecord>? records,
  List<Vehicle>? vehicles,
  List<Expense>? expenses,
  List<MemoItem>? memos,
  required int exportedAt,
}) {
  return {
    'version': 1,
    'exportedAt': exportedAt,
    'records': records ?? const [],
    'vehicles': vehicles ?? const [],
    'expenses': expenses ?? const [],
    'memos': memos ?? const [],
  };
}

/// 备份解析结果（规范化后的四类数据）。
class ParsedBackup {
  const ParsedBackup({
    required this.records,
    required this.vehicles,
    required this.expenses,
    required this.memos,
  });

  final List<ChargeRecord> records;
  final List<Vehicle> vehicles;
  final List<Expense> expenses;
  final List<MemoItem> memos;
}

/// 解析备份 JSON 文本（[buildExportJson] 的逆操作，脏数据逐条过滤）。
///
/// 非 JSON、结构不符（缺 records/vehicles 数组）返回 null，绝不抛错；
/// 兼容旧版备份（无 expenses/memos → 空数组）；车辆 photoPath 一律剥离
/// （本机照片路径无法随 JSON 迁移）。
ParsedBackup? parseExportJson(String? text) {
  if (text == null || text.trim().isEmpty) return null;
  dynamic data;
  try {
    data = jsonDecode(text);
  } on FormatException {
    return null;
  }
  if (data is! Map<String, dynamic>) return null;
  if (data['records'] is! List || data['vehicles'] is! List) return null;

  final records = (data['records'] as List)
      .map(normalizeStoredRecord)
      .whereType<ChargeRecord>()
      .toList();
  final vehicles = (data['vehicles'] as List)
      .whereType<Map<String, dynamic>>()
      .map(normalizeStoredVehicle)
      .whereType<Vehicle>()
      .map((vehicle) => vehicle.copyWith(photoPath: ''))
      .toList();
  final expenses = data['expenses'] is List
      ? (data['expenses'] as List)
            .whereType<Map<String, dynamic>>()
            .map(normalizeStoredExpense)
            .whereType<Expense>()
            .toList()
      : <Expense>[];
  final memos = data['memos'] is List
      ? (data['memos'] as List)
            .whereType<Map<String, dynamic>>()
            .map(_memoInputFromMap)
            .map(normalizeStoredMemo)
            .whereType<MemoItem>()
            .toList()
      : <MemoItem>[];

  return ParsedBackup(
    records: records,
    vehicles: vehicles,
    expenses: expenses,
    memos: memos,
  );
}

/// 导入合并：按 id 去重，仅挑出本地不存在的条目。
///
/// skippedCount = 重复 id + 非法条目数。
class ImportPick<T> {
  const ImportPick({required this.toAdd, required this.skippedCount});

  final List<T> toAdd;
  final int skippedCount;
}

ImportPick<T> pickImportItems<T>(
  List<T>? existingItems,
  List<T>? incomingItems,
  String Function(T) idOf,
) {
  final existingIds = <String>{
    for (final item in existingItems ?? const []) idOf(item),
  };
  final incoming = incomingItems ?? const [];
  final toAdd = <T>[];
  var skippedCount = 0;
  for (final item in incoming) {
    if (idOf(item).isEmpty || existingIds.contains(idOf(item))) {
      skippedCount += 1;
      continue;
    }
    toAdd.add(item);
  }
  return ImportPick(toAdd: toAdd, skippedCount: skippedCount);
}

/// 备份 JSON 的备忘条目（宽容 Map）→ [MemoInput]。
MemoInput? _memoInputFromMap(Map<String, dynamic> m) {
  final registrationDate = m['registrationDate'];
  if (registrationDate is! String) return null;
  return MemoInput(
    id: m['id'],
    vehicleId: m['vehicleId'],
    vehicleName: m['vehicleName'] is String ? m['vehicleName'] : null,
    registrationDate: registrationDate,
    mileageKm: m['mileageKm'],
    insuranceExpiryDate: m['insuranceExpiryDate'] is String
        ? m['insuranceExpiryDate']
        : null,
    createdAt: m['createdAt'],
    updatedAt: m['updatedAt'],
  );
}
