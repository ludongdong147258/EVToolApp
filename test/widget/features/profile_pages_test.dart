import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ev_tool_app/core/storage/key_value_store.dart';
import 'package:ev_tool_app/core/storage/local_storage.dart';
import 'package:ev_tool_app/features/profile/presentation/pages/about_page.dart';
import 'package:ev_tool_app/features/profile/presentation/pages/agreement_page.dart';
import 'package:ev_tool_app/features/profile/presentation/pages/backup_restore_page.dart';
import 'package:ev_tool_app/features/profile/presentation/pages/privacy_page.dart';
import 'package:ev_tool_app/features/profile/presentation/pages/profile_page.dart';
import 'package:ev_tool_app/features/vehicles/presentation/pages/vehicles_page.dart';

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

  /// 内容较长的页面：放大画布让 ListView 一次性构建全部子项。
  Future<void> pumpTall(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(child);
    await tester.pumpAndSettle();
  }

  /// 两条充电记录 + 一辆默认车的本地数据。
  Map<String, Object> seedStore() {
    return <String, Object>{
      'chargeRecords': [
        {
          'id': 'r1',
          'type': 'fast',
          'date': '2026-09-01',
          'cost': 30,
          'energy': 40,
          'createdAt': 1,
        },
        {
          'id': 'r2',
          'type': 'home',
          'date': '2026-09-15',
          'cost': 15,
          'energy': 25,
          'createdAt': 2,
        },
      ],
      'vehicles': [
        {
          'id': 'v1',
          'name': '小白',
          'battery': 60,
          'note': '白色 Model 3',
          'photoPath': '',
          'isDefault': true,
          'createdAt': 1,
          'updatedAt': 1,
        },
      ],
      'userProfile': {'nickname': '阿明', 'avatarUrl': ''},
    };
  }

  group('profile_page', () {
    testWidgets('渲染用户卡（昵称/徽标/记录天数/统计）与全部菜单', (tester) async {
      final container = await bootstrap(store: seedStore());

      await pumpTall(
        tester,
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProfilePage()),
        ),
      );

      // 用户卡：昵称 + 等级徽标 + 记录天数 + 累计花费
      expect(find.text('阿明'), findsOneWidget);
      expect(find.text('见习车主'), findsOneWidget);
      expect(find.text('记录 2 天'), findsOneWidget);
      expect(find.text('累计花费 ¥45.00'), findsOneWidget);

      // 三列统计
      expect(find.text('充电记录'), findsOneWidget);
      expect(find.text('本月充电'), findsOneWidget);
      expect(find.text('累计电量'), findsOneWidget);

      // 菜单
      expect(find.text('我的服务'), findsOneWidget);
      expect(find.text('我的车辆'), findsOneWidget);
      expect(find.text('充电统计'), findsOneWidget);
      expect(find.text('充电点位地图'), findsOneWidget);
      expect(find.text('数据备份'), findsOneWidget);
      expect(find.text('关于应用'), findsOneWidget);
      expect(find.text('主题配色'), findsOneWidget);
      expect(find.text('设置'), findsNothing);
      expect(find.text('关于'), findsOneWidget);
    });

    testWidgets('主题配色菜单打开 6 套配色弹层', (tester) async {
      final container = await bootstrap(store: seedStore());

      await pumpTall(
        tester,
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProfilePage()),
        ),
      );

      await tester.tap(find.text('主题配色'));
      await tester.pumpAndSettle();

      expect(find.text('极光绿'), findsOneWidget);
      expect(find.text('深海蓝'), findsOneWidget);
      expect(find.text('落日橙'), findsOneWidget);
      expect(find.text('星辰紫'), findsOneWidget);
      expect(find.text('樱花粉'), findsOneWidget);
      expect(find.text('赛博青'), findsOneWidget);
    });
  });

  group('backup_restore_page', () {
    testWidgets('渲染导出/导入分区与数据概要', (tester) async {
      final container = await bootstrap(store: seedStore());

      await pumpTall(
        tester,
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: BackupRestorePage()),
        ),
      );

      // 分区标题与按钮同名，各出现两次
      expect(find.text('导出数据'), findsNWidgets(2));
      expect(find.text('复制备份文本'), findsNothing);
      expect(find.text('导入恢复'), findsNWidgets(2));
      expect(find.textContaining('2 条充电记录'), findsOneWidget);
      expect(find.textContaining('1 辆车'), findsOneWidget);
      expect(find.textContaining('0 笔养车支出'), findsOneWidget);
      expect(find.textContaining('0 条年检备忘'), findsOneWidget);
    });
  });

  group('vehicles_page', () {
    testWidgets('渲染车库卡片并打开添加车辆弹层', (tester) async {
      final container = await bootstrap(store: seedStore());

      await pumpTall(
        tester,
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: VehiclesPage()),
        ),
      );

      // 车库卡片：昵称 + 默认徽标 + 容量 + 备注 + 添加入口
      expect(find.text('小白'), findsOneWidget);
      expect(find.text('默认'), findsOneWidget);
      expect(find.text('60'), findsOneWidget);
      expect(find.text('白色 Model 3'), findsOneWidget);
      expect(find.text('添加车辆'), findsOneWidget);

      // 打开添加弹层：表单字段齐全
      await tester.tap(find.text('添加车辆'));
      await tester.pumpAndSettle();

      expect(find.text('昵称'), findsOneWidget);
      expect(find.text('电池容量（kWh）'), findsOneWidget);
      expect(find.text('备注（选填）'), findsOneWidget);
      expect(find.text('车辆照片（选填）'), findsOneWidget);
      expect(find.text('拍照'), findsOneWidget);
      expect(find.text('从相册选择'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
    });

    testWidgets('空车库展示空态与 CTA', (tester) async {
      final container = await bootstrap();

      await pumpTall(
        tester,
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: VehiclesPage()),
        ),
      );

      expect(find.text('暂无车辆'), findsOneWidget);
      expect(find.text('添加车辆信息，方便后续计算充电花费'), findsOneWidget);
    });
  });

  group('about_page', () {
    testWidgets('渲染品牌区/简介/信息列表', (tester) async {
      await pumpTall(tester, const MaterialApp(home: AboutPage()));

      expect(find.text('EV Tool 电车工具'), findsOneWidget);
      expect(find.text('联系邮箱'), findsNothing);
      expect(find.text('用户协议'), findsOneWidget);
      expect(find.text('隐私政策'), findsOneWidget);
      expect(find.text('版本'), findsOneWidget);
      expect(find.text('1.0.0'), findsOneWidget);
    });
  });

  group('legal_pages', () {
    testWidgets('用户协议页渲染更新日期与首章节', (tester) async {
      await pumpTall(tester, const MaterialApp(home: AgreementPage()));

      expect(find.text('更新日期：2026-08-23'), findsOneWidget);
      expect(find.text('一、协议的接受'), findsOneWidget);
    });

    testWidgets('隐私政策页渲染更新日期与首章节', (tester) async {
      await pumpTall(tester, const MaterialApp(home: PrivacyPage()));

      expect(find.text('更新日期：2026-08-23'), findsOneWidget);
      expect(find.text('一、引言'), findsOneWidget);
    });
  });
}
