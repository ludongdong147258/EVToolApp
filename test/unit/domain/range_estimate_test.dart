import 'package:ev_tool_app/core/domain/range_estimate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calcRangeEstimate 续航静态估算（美制）', () {
    test('默认输入计算出基准续航（综合路况 0.9 折扣）', () {
      // Arrange
      const inputs = RangeEstimateInputs();

      // Act
      final result = calcRangeEstimate(inputs);

      // Assert
      // 可用电量：60 × 80% = 48 度
      // 基准续航：48 × 3.4 = 163.2
      // 预估续航：163.2 × 0.9（综合路况）= 146.88 → 146.9
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.availableEnergy, 48);
      expect(result.baseRange, 163.2);
      expect(result.estimatedRange, 146.9);
      expect(result.totalFactor, 0.9);
    });

    test('全部有利条件（常温/市区/空调关）时折扣为 1', () {
      // Arrange
      const inputs = RangeEstimateInputs(road: 'city');

      // Act
      final result = calcRangeEstimate(inputs);

      // Assert
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.totalFactor, 1);
      expect(result.estimatedRange, 163.2);
    });

    test('严寒 + 高速 + 空调开三重折扣叠加正确', () {
      // Arrange
      const inputs = RangeEstimateInputs(
        temperature: 'freezing',
        road: 'highway',
        ac: 'on',
      );

      // Act
      final result = calcRangeEstimate(inputs);

      // Assert
      // 折扣：0.65 × 0.75 × 0.92 = 0.4485 → 0.45（两位小数）
      // 预估：163.2 × 0.4485 = 73.183… → 73.2
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.totalFactor, 0.45);
      expect(result.estimatedRange, 73.2);
    });

    test('低温与高温折扣正确', () {
      // Arrange & Act
      final cold = calcRangeEstimate(
        const RangeEstimateInputs(temperature: 'cold', road: 'city'),
      );
      final hot = calcRangeEstimate(
        const RangeEstimateInputs(temperature: 'hot', road: 'city'),
      );

      // Assert
      // 低温：163.2 × 0.8 = 130.56 → 130.6；高温：163.2 × 0.9 = 146.88 → 146.9
      if (cold == null || hot == null) {
        fail('results should not be null');
      }
      expect(cold.estimatedRange, 130.6);
      expect(hot.estimatedRange, 146.9);
    });

    test('电池容量与 SOC 边界值计算正确', () {
      // Arrange & Act
      final minBattery = calcRangeEstimate(
        const RangeEstimateInputs(
          battery: batteryMin,
          soc: socMax,
          road: 'city',
        ),
      );
      final maxBattery = calcRangeEstimate(
        const RangeEstimateInputs(
          battery: batteryMax,
          soc: socMin,
          road: 'city',
        ),
      );

      // Assert
      // 最小电池满电：15 × 3.4 = 51；最大电池最低档：200 × 10% × 3.4 = 68
      if (minBattery == null || maxBattery == null) {
        fail('results should not be null');
      }
      expect(minBattery.estimatedRange, 51);
      expect(maxBattery.estimatedRange, 68);
    });

    test('能效边界值计算正确', () {
      // Arrange & Act
      final economic = calcRangeEstimate(
        const RangeEstimateInputs(efficiency: efficiencyMax, road: 'city'),
      );
      final thirsty = calcRangeEstimate(
        const RangeEstimateInputs(efficiency: efficiencyMin, road: 'city'),
      );

      // Assert
      // 省电：48 × 6 = 288；费电：48 × 2 = 96
      if (economic == null || thirsty == null) {
        fail('results should not be null');
      }
      expect(economic.estimatedRange, 288);
      expect(thirsty.estimatedRange, 96);
    });

    test('结果保留一位小数（浮点安全）', () {
      // Arrange
      const inputs = RangeEstimateInputs(
        battery: 33,
        soc: 55,
        efficiency: 3.5,
        road: 'city',
      );

      // Act
      final result = calcRangeEstimate(inputs);

      // Assert
      // 可用电量：33 × 0.55 = 18.15 → 18.2；基准：18.15 × 3.5 = 63.525 → 63.5
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.availableEnergy, 18.2);
      expect(result.baseRange, 63.5);
    });

    test('接受字符串形式的输入（来自输入框）', () {
      // Arrange
      const inputs = RangeEstimateInputs(
        battery: '60',
        soc: '80',
        efficiency: '3.4',
      );

      // Act
      final result = calcRangeEstimate(inputs);

      // Assert
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.availableEnergy, 48);
    });

    test('任一数值为 0 或负数时返回 null', () {
      // Arrange & Act
      final zeroSoc = calcRangeEstimate(const RangeEstimateInputs(soc: 0));
      final negativeBattery = calcRangeEstimate(
        const RangeEstimateInputs(battery: -1),
      );
      final zeroEfficiency = calcRangeEstimate(
        const RangeEstimateInputs(efficiency: 0),
      );

      // Assert
      expect(zeroSoc, isNull);
      expect(negativeBattery, isNull);
      expect(zeroEfficiency, isNull);
    });

    test('任一数值越界或非数字时返回 null', () {
      // Arrange & Act
      final overBattery = calcRangeEstimate(
        const RangeEstimateInputs(battery: batteryMax + 1),
      );
      final overSoc = calcRangeEstimate(
        const RangeEstimateInputs(soc: socMax + 1),
      );
      final underEfficiency = calcRangeEstimate(
        const RangeEstimateInputs(efficiency: efficiencyMin - 1),
      );
      final emptyEfficiency = calcRangeEstimate(
        const RangeEstimateInputs(efficiency: ''),
      );
      final nanSoc = calcRangeEstimate(const RangeEstimateInputs(soc: 'abc'));
      final undefinedBattery = calcRangeEstimate(
        const RangeEstimateInputs(battery: null),
      );

      // Assert
      expect(overBattery, isNull);
      expect(overSoc, isNull);
      expect(underEfficiency, isNull);
      expect(emptyEfficiency, isNull);
      expect(nanSoc, isNull);
      expect(undefinedBattery, isNull);
    });

    test('任一工况选项值不合法时返回 null', () {
      // Arrange & Act
      final badTemperature = calcRangeEstimate(
        const RangeEstimateInputs(temperature: 'volcano'),
      );
      final badRoad = calcRangeEstimate(
        const RangeEstimateInputs(road: 'offroad'),
      );
      final badAc = calcRangeEstimate(const RangeEstimateInputs(ac: 'maybe'));
      final missingTemperature = calcRangeEstimate(
        const RangeEstimateInputs(temperature: null),
      );

      // Assert
      expect(badTemperature, isNull);
      expect(badRoad, isNull);
      expect(badAc, isNull);
      expect(missingTemperature, isNull);
    });
  });

  group('getFactorBreakdown 折扣明细', () {
    test('默认输入返回三项系数与综合折扣', () {
      // Arrange
      const inputs = RangeEstimateInputs();

      // Act
      final breakdown = getFactorBreakdown(inputs);

      // Assert
      if (breakdown == null) {
        fail('breakdown should not be null');
      }
      expect(breakdown.items.length, 3);
      expect(breakdown.items[0].label, 'Mild');
      expect(breakdown.items[0].factor, 1);
      expect(breakdown.items[1].label, 'Mixed');
      expect(breakdown.items[1].factor, 0.9);
      expect(breakdown.items[2].label, 'Off');
      expect(breakdown.items[2].factor, 1);
      expect(breakdown.total, 0.9);
    });

    test('三重折扣叠加：0.65 × 0.75 × 0.92 = 0.45（两位小数）', () {
      // Arrange
      const inputs = RangeEstimateInputs(
        temperature: 'freezing',
        road: 'highway',
        ac: 'on',
      );

      // Act
      final breakdown = getFactorBreakdown(inputs);

      // Assert
      if (breakdown == null) {
        fail('breakdown should not be null');
      }
      expect(breakdown.items.length, 3);
      expect(breakdown.items[0].label, 'Freezing ≤14°F');
      expect(breakdown.items[0].factor, 0.65);
      expect(breakdown.items[1].label, 'Highway');
      expect(breakdown.items[1].factor, 0.75);
      expect(breakdown.items[2].label, 'On');
      expect(breakdown.items[2].factor, 0.92);
      expect(breakdown.total, 0.45);
    });

    test('任一输入非法（数值或选项）时返回 null', () {
      // Arrange & Act
      final badOption = getFactorBreakdown(
        const RangeEstimateInputs(road: 'offroad'),
      );
      final badNumber = getFactorBreakdown(
        const RangeEstimateInputs(efficiency: ''),
      );
      final missingInput = getFactorBreakdown(null);

      // Assert
      expect(badOption, isNull);
      expect(badNumber, isNull);
      expect(missingInput, isNull);
    });
  });
}
