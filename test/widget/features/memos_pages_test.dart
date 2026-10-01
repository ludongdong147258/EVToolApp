import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ev_tool_app/core/storage/key_value_store.dart';
import 'package:ev_tool_app/core/storage/local_storage.dart';
import 'package:ev_tool_app/features/handbooks/presentation/pages/modification_compliance_page.dart';
import 'package:ev_tool_app/features/handbooks/presentation/pages/warranty_handbook_page.dart';
import 'package:ev_tool_app/features/memos/presentation/pages/inspection_memo_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> bootstrap({
    Map<String, Object> store = const {},
  }) async {
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    final localStorage = LocalStorage(prefs);
    final kv = SharedPrefsKeyValueStore(prefs);
    for (final entry in store.entries) {
      await kv.setJson(entry.key, entry.value);
    }
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localStorageProvider.overrideWithValue(localStorage),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  // 静态长列表：放大画布让 ListView 一次性构建全部子项
  Future<void> pumpTall(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(400, 9000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(child);
    await tester.pumpAndSettle();
  }

  group('inspection_memo_page', () {
    testWidgets('有车辆与备忘时展示计算结果各分区', (tester) async {
      final container = await bootstrap(
        store: {
          'vehicles': [
            {
              'id': 'v1',
              'name': '我的小车',
              'battery': 60,
              'note': '',
              'photoPath': '',
              'isDefault': true,
              'createdAt': 1,
              'updatedAt': 1,
            },
          ],
          'inspectionMemos': [
            {
              'id': 'm1',
              'vehicleId': 'v1',
              'vehicleName': '我的小车',
              'registrationDate': '2021-06-15',
              'mileageKm': 25000,
              'insuranceExpiryDate': null,
              'createdAt': 1,
              'updatedAt': 1,
            },
          ],
        },
      );

      await pumpTall(
        tester,
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: InspectionMemoPage()),
        ),
      );

      // 表单回填
      expect(find.text('备忘信息'), findsOneWidget);
      expect(find.text('我的小车'), findsWidgets);
      expect(find.text('2021-06-15'), findsOneWidget);
      expect(find.text('保存备忘'), findsOneWidget);

      // 年检 hero + 时间轴 + 维保节点
      expect(find.text('距下次年检 · 上线检测'), findsOneWidget);
      expect(find.text('年检时间轴'), findsOneWidget);
      expect(find.text('新能源维保节点'), findsOneWidget);
      expect(find.text('三电系统检查'), findsOneWidget);
      expect(find.text('冷却液检查更换'), findsOneWidget);
      expect(find.text('已保存备忘 · 1 条'), findsOneWidget);
    });

    testWidgets('无车辆时展示去添加车辆空态', (tester) async {
      final container = await bootstrap();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: InspectionMemoPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('先添加车辆后即可建立备忘录'), findsOneWidget);
      expect(find.text('去添加车辆'), findsOneWidget);
      expect(find.text('保存备忘'), findsNothing);
    });

    testWidgets('车辆选择弹层支持已删车辆的孤儿备忘', (tester) async {
      final container = await bootstrap(
        store: {
          'vehicles': [
            {
              'id': 'v1',
              'name': '现役车',
              'battery': 60,
              'note': '',
              'photoPath': '',
              'isDefault': true,
              'createdAt': 1,
              'updatedAt': 1,
            },
          ],
          'inspectionMemos': [
            {
              'id': 'm2',
              'vehicleId': 'v-gone',
              'vehicleName': '幽灵车',
              'registrationDate': '2021-06-15',
              'mileageKm': 25000,
              'insuranceExpiryDate': null,
              'createdAt': 1,
              'updatedAt': 2,
            },
          ],
        },
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: InspectionMemoPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('现役车'));
      await tester.pumpAndSettle();

      expect(find.text('幽灵车 · 已删除'), findsOneWidget);
      expect(find.text('现役车'), findsWidgets);
    });
  });

  group('modification_compliance_page', () {
    testWidgets('渲染全部 10 个改装项目与三类分区', (tester) async {
      await pumpTall(
        tester,
        const MaterialApp(home: ModificationCompliancePage()),
      );

      expect(find.text('常见改装项目速查'), findsOneWidget);
      expect(find.text('合法改装'), findsOneWidget);
      expect(find.text('合法但需备案'), findsOneWidget);
      expect(find.text('违法改装'), findsOneWidget);
      for (final name in [
        '内饰改装',
        '小型外观装饰',
        '同规格轮毂替换',
        '车身改色（贴膜/喷漆）',
        '外观套件（包围/侧裙/尾翼）',
        '改变轮毂规格尺寸',
        '改动电池/电机/电控',
        '悬架改装（升高/降低）',
        '非法灯光（爆闪/加装射灯）',
        '加宽轮距/加装垫片',
      ]) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      expect(find.text('交警查处风险'), findsNWidgets(10));
    });
  });

  group('warranty_handbook_page', () {
    testWidgets('渲染全部 11 个品牌卡与国标基线', (tester) async {
      await pumpTall(tester, const MaterialApp(home: WarrantyHandbookPage()));

      expect(find.text('主流车企三电质保速查'), findsOneWidget);
      expect(find.text('国家规定基线'), findsOneWidget);
      expect(find.text('整车质保'), findsNWidgets(11));
      for (final name in [
        '比亚迪',
        '小鹏',
        '小米汽车',
        '极氪',
        '蔚来',
        '特斯拉',
        '吉利',
        '问界',
        '理想',
        '零跑',
        '埃安',
      ]) {
        // 视口外的横向跳转 chip 不构建，只断言品牌卡名称至少出现一次
        expect(find.text(name), findsWidgets, reason: name);
      }
    });
  });
}
