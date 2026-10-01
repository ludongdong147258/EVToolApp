import 'package:ev_tool_app/core/domain/ocr_receipt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('lib/ocrReceipt', () {
    group('computeTargetSize', () {
      test('横图长边超阈值时等比缩放到阈值', () {
        expect(
          computeTargetSize(4000, 3000, 1280),
          const TargetSize(
            targetWidth: 1280,
            targetHeight: 960,
            needsScale: true,
          ),
        );
      });

      test('竖图按高度缩放', () {
        expect(
          computeTargetSize(3000, 4000, 1280),
          const TargetSize(
            targetWidth: 960,
            targetHeight: 1280,
            needsScale: true,
          ),
        );
      });

      test('长边等于阈值不缩放（永不放大）', () {
        expect(computeTargetSize(1280, 720, 1280).needsScale, isFalse);
      });

      test('小于阈值不缩放', () {
        final result = computeTargetSize(800, 600, 1280);
        expect(
          result,
          const TargetSize(
            targetWidth: 800,
            targetHeight: 600,
            needsScale: false,
          ),
        );
      });

      test('非法入参（0/负数/NaN）needsScale 为 false', () {
        expect(computeTargetSize(0, 100, 1280).needsScale, isFalse);
        expect(computeTargetSize(-4000, 3000, 1280).needsScale, isFalse);
        expect(computeTargetSize(double.nan, 3000, 1280).needsScale, isFalse);
      });

      test('非整数比例结果取整', () {
        final result = computeTargetSize(4001, 3000, 1280);
        expect(result.targetWidth, 1280);
        expect(result.targetHeight, (3000 * 1280 / 4001).roundToDouble());
      });
    });

    group('extractJsonBlock', () {
      test('直接解析纯 JSON 文本', () {
        // Arrange
        const raw = '{"totalCostYuan": 25.5}';
        // Act
        final parsed = extractJsonBlock(raw);
        // Assert
        expect(parsed, {'totalCostYuan': 25.5});
      });

      test('剥离 markdown 围栏后解析', () {
        const raw = '识别结果如下：\n```json\n{"totalCostYuan": 18.6}\n```';
        expect(extractJsonBlock(raw), {'totalCostYuan': 18.6});
      });

      test('从带前后缀文本中截取大括号子串解析', () {
        const raw = '好的，这是结果 { "totalEnergyKwh": 32.1 } 请核对';
        expect(extractJsonBlock(raw), {'totalEnergyKwh': 32.1});
      });

      test('非 JSON 文本返回 null', () {
        expect(extractJsonBlock('这不是一张充电小票'), isNull);
      });

      test('空值与非字符串输入返回 null', () {
        expect(extractJsonBlock(''), isNull);
        expect(extractJsonBlock(null), isNull);
      });
    });

    group('normalizeReceiptResult', () {
      const highConfidence = {
        'stationName': 0.9,
        'totalEnergyKwh': 0.95,
        'totalCostYuan': 0.9,
        'durationMinutes': 0.8,
        'date': 0.9,
        'chargeType': 0.7,
      };

      test('完整高置信结果归一化为表单字段', () {
        final parsed = {
          'stationName': '特来电 快充站',
          'totalEnergyKwh': 32.16,
          'totalCostYuan': 45.8,
          'durationMinutes': 83,
          'date': '2026-08-28',
          'chargeType': 'fast',
          'confidence': highConfidence,
        };
        final result = normalizeReceiptResult(parsed);
        expect(result.cost, '45.8');
        expect(result.energy, '32.16');
        expect(result.hours, '1');
        expect(result.minutes, '23');
        expect(result.date, '2026-08-28');
        expect(result.note, '特来电 快充站');
        expect(result.chargeType, 'fast');
        expect(result.filledFields, [
          'cost',
          'energy',
          'duration',
          'date',
          'note',
          'chargeType',
        ]);
      });

      test('低置信字段留空且不进 filledFields', () {
        final parsed = {
          'totalCostYuan': 25,
          'totalEnergyKwh': 30,
          'confidence': {
            'totalCostYuan': confidenceThreshold + 0.1,
            'totalEnergyKwh': confidenceThreshold - 0.01,
          },
        };
        final result = normalizeReceiptResult(parsed);
        expect(result.cost, '25');
        expect(result.energy, '');
        expect(result.filledFields, ['cost']);
      });

      test('非法数值（0/负数/NaN）丢弃对应字段', () {
        final parsed = {
          'totalCostYuan': 0,
          'totalEnergyKwh': -5,
          'durationMinutes': double.nan,
          'confidence': {
            'totalCostYuan': 0.9,
            'totalEnergyKwh': 0.9,
            'durationMinutes': 0.9,
          },
        };
        final result = normalizeReceiptResult(parsed);
        expect(result.cost, '');
        expect(result.energy, '');
        expect(result.filledFields, isEmpty);
      });

      test('时长超过上限（72 小时）丢弃', () {
        final parsed = {
          'durationMinutes': 72 * 60 + 1,
          'confidence': {'durationMinutes': 0.9},
        };
        expect(normalizeReceiptResult(parsed).filledFields, isEmpty);
      });

      test('整小时时长 minutes 归零', () {
        final parsed = {
          'durationMinutes': 120,
          'confidence': {'durationMinutes': 0.9},
        };
        final result = normalizeReceiptResult(parsed);
        expect(result.hours, '2');
        expect(result.minutes, '0');
      });

      test('未来日期与格式错误日期丢弃', () {
        final future = DateTime.now().add(const Duration(days: 1));
        String pad(int n) => n < 10 ? '0$n' : '$n';
        final futureStr = [
          future.year,
          pad(future.month),
          pad(future.day),
        ].join('-');
        final parsed = {
          'date': futureStr,
          'confidence': {'date': 0.9},
        };
        expect(normalizeReceiptResult(parsed).date, '');

        const badFormat = {
          'date': '2026/08/28',
          'confidence': {'date': 0.9},
        };
        expect(normalizeReceiptResult(badFormat).date, '');
      });

      test('stationName 超长截断到 100 字符', () {
        final parsed = {
          'stationName': '站' * 150,
          'confidence': {'stationName': 0.9},
        };
        final result = normalizeReceiptResult(parsed);
        expect(result.note.length, 100);
      });

      test('chargeType 非法值丢弃，合法值保留', () {
        const illegal = {
          'chargeType': 'unknown',
          'confidence': {'chargeType': 0.9},
        };
        expect(normalizeReceiptResult(illegal).chargeType, '');

        const home = {
          'chargeType': 'home',
          'confidence': {'chargeType': 0.9},
        };
        expect(normalizeReceiptResult(home).chargeType, 'home');
      });

      test('嵌套 {value, confidence} 结构（glm 真实输出常见）同样归一化', () {
        final parsed = {
          'stationName': {'value': '特来电 快充站', 'confidence': 0.9},
          'totalEnergyKwh': {'value': 32.16, 'confidence': 0.95},
          'totalCostYuan': {'value': 45.8, 'confidence': 0.9},
          'durationMinutes': {'value': 83, 'confidence': 0.8},
          'date': {'value': '2026-08-28', 'confidence': 0.9},
          'chargeType': {'value': 'fast', 'confidence': 0.7},
        };
        final result = normalizeReceiptResult(parsed);
        expect(result.cost, '45.8');
        expect(result.energy, '32.16');
        expect(result.hours, '1');
        expect(result.minutes, '23');
        expect(result.note, '特来电 快充站');
        expect(result.chargeType, 'fast');
        expect(result.filledFields, hasLength(6));
      });

      test('嵌套结构低置信字段同样留空', () {
        final parsed = {
          'totalCostYuan': {
            'value': 25,
            'confidence': confidenceThreshold - 0.1,
          },
        };
        final result = normalizeReceiptResult(parsed);
        expect(result.cost, '');
        expect(result.filledFields, isEmpty);
      });

      test('缺少 confidence 对象时按置信度 1 处理', () {
        const parsed = {'totalCostYuan': 12.5};
        final result = normalizeReceiptResult(parsed);
        expect(result.cost, '12.5');
      });

      test('非对象输入返回全空结果', () {
        final result = normalizeReceiptResult(null);
        expect(result.cost, '');
        expect(result.energy, '');
        expect(result.hours, '');
        expect(result.minutes, '');
        expect(result.date, '');
        expect(result.note, '');
        expect(result.chargeType, '');
        expect(result.filledFields, isEmpty);
      });
    });
  });
}
