import 'package:ev_tool_app/core/domain/range_estimate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calcRangeEstimate 续航静态估算', () {
    test('默认输入计算出基准续航（综合路况 0.9 折扣）', () {
      // Arrange
      const inputs = RangeEstimateInputs();

      // Act
      final result = calcRangeEstimate(inputs);

      // Assert
      // 可用电量：60 × 80% = 48 度
      // 基准续航：48 ÷ 14 × 100 = 342.857… → 342.9
      // 预估续航：342.857 × 0.9（综合路况）= 308.571… → 308.6
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.availableEnergy, 48);
      expect(result.baseRange, 342.9);
      expect(result.estimatedRange, 308.6);
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
      expect(result.estimatedRange, 342.9);
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
      // 预估：342.857 × 0.4485 = 153.771… → 153.8
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.totalFactor, 0.45);
      expect(result.estimatedRange, 153.8);
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
      // 低温：342.857 × 0.8 = 274.285… → 274.3；高温：342.857 × 0.9 = 308.571… → 308.6
      if (cold == null || hot == null) {
        fail('results should not be null');
      }
      expect(cold.estimatedRange, 274.3);
      expect(hot.estimatedRange, 308.6);
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
      // 最小电池满电：15 ÷ 14 × 100 = 107.142… → 107.1
      // 最大电池最低档：200 × 10% = 20 度 → 20 ÷ 14 × 100 = 142.857… → 142.9
      if (minBattery == null || maxBattery == null) {
        fail('results should not be null');
      }
      expect(minBattery.estimatedRange, 107.1);
      expect(maxBattery.estimatedRange, 142.9);
    });

    test('电耗边界值计算正确', () {
      // Arrange & Act
      final economic = calcRangeEstimate(
        const RangeEstimateInputs(consumption: consumptionMin, road: 'city'),
      );
      final thirsty = calcRangeEstimate(
        const RangeEstimateInputs(consumption: consumptionMax, road: 'city'),
      );

      // Assert
      // 省电：48 ÷ 8 × 100 = 600；费电：48 ÷ 30 × 100 = 160
      if (economic == null || thirsty == null) {
        fail('results should not be null');
      }
      expect(economic.estimatedRange, 600);
      expect(thirsty.estimatedRange, 160);
    });

    test('结果保留一位小数（浮点安全）', () {
      // Arrange
      const inputs = RangeEstimateInputs(
        battery: 33,
        soc: 55,
        consumption: 13,
        road: 'city',
      );

      // Act
      final result = calcRangeEstimate(inputs);

      // Assert
      // 可用电量：33 × 0.55 = 18.15；基准：18.15 ÷ 13 × 100 = 139.615… → 139.6
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.availableEnergy, 18.2);
      expect(result.baseRange, 139.6);
    });

    test('接受字符串形式的输入（来自输入框）', () {
      // Arrange
      const inputs = RangeEstimateInputs(
        battery: '60',
        soc: '80',
        consumption: '14',
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
      final zeroConsumption = calcRangeEstimate(
        const RangeEstimateInputs(consumption: 0),
      );

      // Assert
      expect(zeroSoc, isNull);
      expect(negativeBattery, isNull);
      expect(zeroConsumption, isNull);
    });

    test('任一数值越界或非数字时返回 null', () {
      // Arrange & Act
      final overBattery = calcRangeEstimate(
        const RangeEstimateInputs(battery: batteryMax + 1),
      );
      final overSoc = calcRangeEstimate(
        const RangeEstimateInputs(soc: socMax + 1),
      );
      final underConsumption = calcRangeEstimate(
        const RangeEstimateInputs(consumption: consumptionMin - 1),
      );
      final emptyConsumption = calcRangeEstimate(
        const RangeEstimateInputs(consumption: ''),
      );
      final nanSoc = calcRangeEstimate(const RangeEstimateInputs(soc: 'abc'));
      final undefinedBattery = calcRangeEstimate(
        const RangeEstimateInputs(battery: null),
      );

      // Assert
      expect(overBattery, isNull);
      expect(overSoc, isNull);
      expect(underConsumption, isNull);
      expect(emptyConsumption, isNull);
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
      expect(breakdown.items[0].label, 'Freezing ≤-10°C');
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
        const RangeEstimateInputs(consumption: ''),
      );
      final missingInput = getFactorBreakdown(null);

      // Assert
      expect(badOption, isNull);
      expect(badNumber, isNull);
      expect(missingInput, isNull);
    });
  });
}
