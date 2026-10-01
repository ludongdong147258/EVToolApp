import 'package:flutter_test/flutter_test.dart';

import 'package:ev_tool_app/core/domain/charge_records.dart';
import 'package:ev_tool_app/core/domain/export_data.dart';
import 'package:ev_tool_app/core/domain/vehicles.dart';

ChargeRecord _record(Map<String, dynamic> overrides) {
  return ChargeRecord.fromJson({
    'id': 'r1',
    'type': 'fast',
    'date': '2026-08-01',
    'cost': 30,
    'energy': 40,
    'createdAt': 1,
    ...overrides,
  });
}

Vehicle _vehicle(Map<String, dynamic> overrides) {
  final vehicle = Vehicle.fromJson({
    'id': 'v1',
    'name': '小海豹',
    'battery': 82,
    'createdAt': 1,
    'updatedAt': 1,
    ...overrides,
  });
  // 测试夹具字段齐全，规范化必不失败。
  return vehicle!;
}

void main() {
  group('recordsToCsv 充电记录导出', () {
    test('表头 + 数据行，含 BOM 前缀', () {
      final csv = recordsToCsv([
        _record({
          'type': 'fast',
          'cost': 30,
          'energy': 40.5,
          'durationMinutes': 85,
          'vehicleName': '我的车',
          'note': '服务区快充',
        }),
      ]);
      expect(csv.startsWith(csvBom), isTrue);
      final lines = csv.substring(1).trim().split('\n');
      expect(lines[0], '日期,类型,费用(元),电量(kWh),时长(分钟),度电成本(元/kWh),车辆,备注');
      expect(lines[1], '2026-08-01,快充,30,40.5,85,0.74,我的车,服务区快充');
    });

    test('时长/车辆/备注缺失时对应单元格为空串', () {
      final csv = recordsToCsv([
        _record({'type': 'home', 'cost': 10, 'energy': 15}),
      ]);
      final cells = csv.substring(1).trim().split('\n')[1].split(',');
      expect(cells[4], '');
      expect(cells[6], '');
      expect(cells[7], '');
    });

    test('含逗号/引号/换行的备注做 CSV 转义', () {
      final csv = recordsToCsv([
        _record({
          'type': 'home',
          'cost': 5,
          'energy': 8,
          'note': '含,逗号 和"引号"\n换行',
        }),
      ]);
      // 引号包裹 + 内部引号翻倍（换行保留在引号内，是合法 CSV）
      expect(csv, contains('"含,逗号 和""引号""\n换行"'));
    });

    test('空数组只输出表头；null 输入同空数组', () {
      final empty = recordsToCsv([]);
      expect(empty.substring(1).trim().split('\n'), hasLength(1));
      expect(recordsToCsv(null).substring(1).trim().split('\n'), hasLength(1));
    });
  });

  group('vehiclesToCsv 车辆导出', () {
    test('表头 + 数据行（默认车标记为是）', () {
      final csv = vehiclesToCsv([
        _vehicle({'note': '', 'isDefault': true}),
        _vehicle({'id': 'v2', 'name': '老车', 'battery': 60, 'note': '备用'}),
      ]);
      final lines = csv.substring(1).trim().split('\n');
      expect(lines[0], '车辆名称,电池容量(kWh),备注,默认车');
      expect(lines[1], '小海豹,82,,是');
      expect(lines[2], '老车,60,备用,否');
    });

    test('空数组 / null 只输出表头', () {
      expect(vehiclesToCsv([]).substring(1).trim().split('\n'), hasLength(1));
      expect(vehiclesToCsv(null).substring(1).trim().split('\n'), hasLength(1));
    });
  });

  group('buildExportJson 备份结构', () {
    test('带版本号与导出时间，四类数据原样携带', () {
      // Arrange
      final records = [
        _record({'id': 'r1'}),
      ];
      final vehicles = [
        _vehicle({'id': 'v1'}),
      ];

      // Act
      final json = buildExportJson(
        records: records,
        vehicles: vehicles,
        exportedAt: 1756000000000,
      );

      // Assert
      expect(json['version'], 1);
      expect(json['exportedAt'], 1756000000000);
      expect(json['records'], records);
      expect(json['vehicles'], vehicles);
      expect(json['expenses'], isEmpty);
      expect(json['memos'], isEmpty);
    });

    test('空输入降级为空数组，不抛错', () {
      // Act
      final json = buildExportJson(exportedAt: 0);

      // Assert
      expect(json['records'], isEmpty);
      expect(json['vehicles'], isEmpty);
      expect(json['expenses'], isEmpty);
      expect(json['memos'], isEmpty);
    });
  });

  group('parseExportJson 备份解析', () {
    test('合法备份文本还原四类规范数据（脏数据被过滤）', () {
      // Arrange
      const backup =
          '{"version":1,"exportedAt":1756000000000,'
          '"records":[{"id":"r1","date":"2026-08-01","type":"fast","cost":30,"energy":40},{"junk":true}],'
          '"vehicles":[{"id":"v1","name":"小海豹","battery":82,"isDefault":true},{"id":"bad","name":"","battery":0}],'
          '"expenses":[{"id":"e1","type":"insurance","amount":3000,"date":"2026-01-01"},{"id":"bad","type":"unknown","amount":-1}],'
          '"memos":[{"id":"m1","vehicleId":"v1","registrationDate":"2024-06-01","mileageKm":10000,"createdAt":1,"updatedAt":2},'
          '{"id":"bad","vehicleId":"v1","registrationDate":"x","mileageKm":10000}]}';

      // Act
      final parsed = parseExportJson(backup);

      // Assert
      expect(parsed, isNotNull);
      expect(parsed!.records, hasLength(1));
      expect(parsed.records.first.id, 'r1');
      expect(parsed.vehicles, hasLength(1));
      expect(parsed.vehicles.first.id, 'v1');
      expect(parsed.expenses, hasLength(1));
      expect(parsed.expenses.first.id, 'e1');
      expect(parsed.memos, hasLength(1));
      expect(parsed.memos.first.id, 'm1');
    });

    test('导入的车辆剥离 photoPath（换机后为死路径，照片不随 JSON 迁移）', () {
      // Arrange
      const backup =
          '{"version":1,"records":[],"vehicles":[{"id":"v1","name":"小海豹","battery":82,"photoPath":"wxfile://tmp_old"}]}';

      // Act
      final parsed = parseExportJson(backup);

      // Assert
      expect(parsed!.vehicles.first.photoPath, '');
    });

    test('旧版备份（仅记录/车辆）兼容解析，支出/备忘降级为空', () {
      // Arrange
      const backup = '{"version":1,"records":[],"vehicles":[]}';

      // Act & Assert
      final parsed = parseExportJson(backup);
      expect(parsed!.expenses, isEmpty);
      expect(parsed.memos, isEmpty);
    });

    test('非 JSON / 结构不符返回 null（不抛错）', () {
      expect(parseExportJson('not json'), isNull);
      expect(parseExportJson('{}'), isNull);
      expect(
        parseExportJson('{"version":1,"records":"x","vehicles":[]}'),
        isNull,
      );
      expect(parseExportJson(null), isNull);
      expect(parseExportJson(''), isNull);
    });
  });

  group('pickImportItems 导入合并（按 id 去重）', () {
    test('仅返回 id 不存在的条目并统计跳过数', () {
      // Arrange
      final existing = [
        _vehicle({'id': 'a'}),
        _vehicle({'id': 'b'}),
      ];
      final incoming = [
        _vehicle({'id': 'b'}),
        _vehicle({'id': 'c'}),
      ];

      // Act
      final result = pickImportItems(existing, incoming, (v) => v.id);

      // Assert
      // （JS 测试中的 null/空 id 条目在 Dart 强类型模型中不存在，
      //   该分支由 idOf 空串守卫保留。）
      expect(result.toAdd.map((item) => item.id).toList(), ['c']);
      expect(result.skippedCount, 1);
    });

    test('空输入不抛错', () {
      expect(
        pickImportItems(null, [
          _vehicle({'id': 'x'}),
        ], (v) => v.id).toAdd,
        hasLength(1),
      );
      expect(pickImportItems(<Vehicle>[], null, (v) => v.id).skippedCount, 0);
    });
  });
}
