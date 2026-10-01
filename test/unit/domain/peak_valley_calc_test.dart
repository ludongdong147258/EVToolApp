import 'package:ev_tool_app/core/domain/peak_valley_calc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calcPeakValleyCost 峰谷电价计算', () {
    test('默认输入计算出与设计稿一致的成本', () {
      // Arrange
      const inputs = PeakValleyInputs();

      // Act
      final result = calcPeakValleyCost(inputs);

      // Assert
      // 需充入：75 × 60% = 45 度
      // 平准：45 × (1.25+0.35)/2 = 36.00；优化：45 × 0.35 = 15.75
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.energy, 45);
      expect(result.flatCost, 36);
      expect(result.optimizedCost, 15.75);
      expect(result.saving, 20.25);
    });

    test('目标充电量下限边界计算正确', () {
      // Arrange
      const inputs = PeakValleyInputs(targetPercent: targetMin);

      // Act
      final result = calcPeakValleyCost(inputs);

      // Assert
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.energy, 15);
      expect(result.flatCost, 12);
      expect(result.optimizedCost, 5.25);
    });

    test('目标充电量上限边界计算正确', () {
      // Arrange
      const inputs = PeakValleyInputs(targetPercent: targetMax);

      // Act
      final result = calcPeakValleyCost(inputs);

      // Assert
      // 需充入 75 × 100% = 75；平准 75 × 0.8 = 60；优化 75 × 0.35 = 26.25
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.energy, 75);
      expect(result.saving, 33.75);
    });

    test('金额保留两位小数（浮点安全）', () {
      // Arrange：0.1 + 0.2 类浮点陷阱
      const inputs = PeakValleyInputs(
        batteryCapacity: 33,
        targetPercent: 55,
        peakPrice: 1.3,
        valleyPrice: 0.4,
      );

      // Act
      final result = calcPeakValleyCost(inputs);

      // Assert
      // energy = 33 × 0.55 = 18.15；flat = 18.15 × 0.85 = 15.4275 → 15.43
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.energy, 18.15);
      expect(result.flatCost, 15.43);
      expect(result.optimizedCost, 7.26);
    });

    test('接受字符串形式的输入（来自输入框）', () {
      // Arrange
      const inputs = PeakValleyInputs(
        batteryCapacity: '75',
        targetPercent: '60',
        peakPrice: '1.25',
        valleyPrice: '0.35',
      );

      // Act
      final result = calcPeakValleyCost(inputs);

      // Assert
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.flatCost, 36);
    });

    test('任一参数为 0 或负数时返回 null', () {
      // Arrange & Act
      final zeroResult = calcPeakValleyCost(
        const PeakValleyInputs(peakPrice: 0),
      );
      final negativeResult = calcPeakValleyCost(
        const PeakValleyInputs(batteryCapacity: -1),
      );

      // Assert
      expect(zeroResult, isNull);
      expect(negativeResult, isNull);
    });

    test('任一参数为空串或非数字时返回 null', () {
      // Arrange & Act
      final emptyResult = calcPeakValleyCost(
        const PeakValleyInputs(valleyPrice: ''),
      );
      final nanResult = calcPeakValleyCost(
        const PeakValleyInputs(targetPercent: 'abc'),
      );
      final undefinedResult = calcPeakValleyCost(
        const PeakValleyInputs(batteryCapacity: null),
      );

      // Assert
      expect(emptyResult, isNull);
      expect(nanResult, isNull);
      expect(undefinedResult, isNull);
    });
  });

  group('calcTimeSpans 时段解析', () {
    test('互补时段覆盖全天：峰 14h 谷 10h 无平时段', () {
      // Arrange & Act
      final spans = calcTimeSpans(
        const PeakValleyInputs(
          peakStart: '08:00',
          peakEnd: '22:00',
          valleyStart: '22:00',
          valleyEnd: '08:00',
        ),
      );

      // Assert
      if (spans == null) {
        fail('spans should not be null');
      }
      expect(spans.peakHours, 14);
      expect(spans.valleyHours, 10);
      expect(spans.flatHours, 0);
    });

    test('支持跨零点时段（22:00→06:00 = 8h）并留出平时段', () {
      // Arrange & Act
      final spans = calcTimeSpans(
        const PeakValleyInputs(
          peakStart: '22:00',
          peakEnd: '06:00',
          valleyStart: '10:00',
          valleyEnd: '16:00',
        ),
      );

      // Assert
      if (spans == null) {
        fail('spans should not be null');
      }
      expect(spans.peakHours, 8);
      expect(spans.valleyHours, 6);
      expect(spans.flatHours, 10);
    });

    test('峰谷重叠返回 null', () {
      // Arrange & Act
      final spans = calcTimeSpans(
        const PeakValleyInputs(
          peakStart: '08:00',
          peakEnd: '22:00',
          valleyStart: '12:00',
          valleyEnd: '23:00',
        ),
      );

      // Assert
      expect(spans, isNull);
    });

    test('时长为 0 或格式非法返回 null', () {
      // Arrange & Act
      final zeroSpan = calcTimeSpans(
        const PeakValleyInputs(
          peakStart: '08:00',
          peakEnd: '08:00',
          valleyStart: '22:00',
          valleyEnd: '06:00',
        ),
      );
      final badFormat = calcTimeSpans(
        const PeakValleyInputs(
          peakStart: '8点',
          peakEnd: '22:00',
          valleyStart: '22:00',
          valleyEnd: '08:00',
        ),
      );

      // Assert
      expect(zeroSpan, isNull);
      expect(badFormat, isNull);
    });
  });

  group('calcPeakValleyCost 时长加权平准成本', () {
    test('默认互补时段：平准按峰 14h/谷 10h 加权', () {
      // Arrange
      const inputs = PeakValleyInputs(
        peakStart: '08:00',
        peakEnd: '22:00',
        valleyStart: '22:00',
        valleyEnd: '08:00',
      );

      // Act
      final result = calcPeakValleyCost(inputs);

      // Assert
      // 平准单位电价 = (14×1.25 + 10×0.35)/24 = 0.875 → 45 × 0.875 = 39.375 → 39.38
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.flatCost, 39.38);
      expect(result.optimizedCost, 15.75);
      expect(result.saving, 23.63);
    });

    test('部分覆盖（存在平时段）时平时段按峰谷均价补足', () {
      // Arrange：峰 8h、谷 6h、平 10h
      const inputs = PeakValleyInputs(
        peakStart: '08:00',
        peakEnd: '16:00',
        valleyStart: '18:00',
        valleyEnd: '00:00',
      );

      // Act
      final result = calcPeakValleyCost(inputs);

      // Assert
      // (8×1.25 + 6×0.35 + 10×0.8)/24 = 0.8375 → 45 × 0.8375 = 37.6875 → 37.69
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.flatCost, 37.69);
    });

    test('时段重叠时返回 null', () {
      // Arrange
      const inputs = PeakValleyInputs(
        peakStart: '08:00',
        peakEnd: '22:00',
        valleyStart: '10:00',
        valleyEnd: '12:00',
      );

      // Act & Assert
      expect(calcPeakValleyCost(inputs), isNull);
    });
  });
}
