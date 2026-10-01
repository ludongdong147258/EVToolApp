import 'package:ev_tool_app/core/domain/data/modification_compliance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final categoryIds = modCategories.map((category) => category.id).toList();

  group('modificationCompliance 静态数据完整性', () {
    test('所有项目 id 唯一且必填字段完整', () {
      // Arrange
      final ids = modificationItems.map((item) => item.id).toList();
      // Act & Assert
      expect(ids.toSet().length, modificationItems.length);
      for (final item in modificationItems) {
        expect(item.id, isNotEmpty);
        expect(item.name, isNotEmpty);
        expect(item.needRegister, isNotEmpty);
        expect(item.note, isNotEmpty);
      }
    });

    test('所有项目 category 与风险等级取值合法', () {
      // Act & Assert
      for (final item in modificationItems) {
        expect(categoryIds, contains(item.category));
        expect(riskLevels, contains(item.inspectionRisk));
        expect(riskLevels, contains(item.policeRisk));
      }
    });

    test('modCategories 恰好三类且顺序为 合法 → 需备案 → 违法', () {
      // Act & Assert
      expect(modCategories.map((category) => category.id).toList(), [
        'legal',
        'register',
        'illegal',
      ]);
      for (final category in modCategories) {
        expect(category.icon, isNotEmpty);
        expect(category.title, isNotEmpty);
        expect(category.desc, isNotEmpty);
      }
    });

    test('免责声明非空', () {
      // Act & Assert
      expect(modComplianceDisclaimer.length, greaterThan(0));
    });
  });

  group('getItemsByCategory 按等级取项目', () {
    test('只返回对应等级的项目', () {
      // Arrange
      const category = 'illegal';
      // Act
      final items = getItemsByCategory(category);
      // Assert
      expect(items.length, greaterThan(0));
      for (final item in items) {
        expect(item.category, category);
      }
    });

    test('未知等级返回空数组', () {
      // Act & Assert
      expect(getItemsByCategory('unknown'), isEmpty);
    });

    test('三类并集覆盖全部项目且互不重叠', () {
      // Arrange
      final grouped = categoryIds.map(getItemsByCategory).toList();
      // Act
      final unionIds =
          grouped.expand((items) => items).map((item) => item.id).toList()
            ..sort();
      // Assert
      expect(
        unionIds,
        modificationItems.map((item) => item.id).toList()..sort(),
      );
    });
  });
}
