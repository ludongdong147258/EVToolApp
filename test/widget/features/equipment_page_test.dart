import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ev_tool_app/core/storage/key_value_store.dart';
import 'package:ev_tool_app/core/storage/local_storage.dart';
import 'package:ev_tool_app/features/equipment/data/goods_repository.dart';
import 'package:ev_tool_app/features/equipment/presentation/pages/equipment_page.dart';

class FakeGoodsRepository implements GoodsRepository {
  FakeGoodsRepository({this.items = const [], this.error});

  final List<GoodsItem> items;
  final GoodsException? error;
  final List<String> keywords = [];
  int callCount = 0;

  @override
  Future<List<GoodsItem>> searchGoods(String keyword, {int page = 1}) async =>
      searchGoodsWithPromo(keyword, page: page);

  @override
  Future<List<GoodsItem>> searchGoodsWithPromo(
    String keyword, {
    int page = 1,
  }) async {
    callCount++;
    keywords.add(keyword);
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return items;
  }

  @override
  bool isTipDismissed() => true;

  @override
  Future<void> markTipDismissed() async {}
}

Future<ProviderContainer> _bootstrap(GoodsRepository repo) async {
  SharedPreferences.setMockInitialValues(const {});
  final prefs = await SharedPreferences.getInstance();
  final kv = SharedPrefsKeyValueStore(prefs);
  await kv.setJson(equipmentTipStorageKey, true);
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      goodsRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _pumpPage(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: EquipmentPage()),
    ),
  );
  // 让首帧骨架屏后的假仓储 Future 完成并触发重建
  await tester.pump();
}

void main() {
  final tabTitles = ['充电枪', '随车充', '家充桩', '车载配件', '充电线材', '应急电源'];

  testWidgets('空数据时渲染 6 个分类 Tab 与空态', (tester) async {
    final container = await _bootstrap(FakeGoodsRepository());
    await _pumpPage(tester, container);
    await tester.pumpAndSettle();

    for (final title in tabTitles) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('暂无商品'), findsOneWidget);
    expect(find.text('重新加载'), findsOneWidget);
  });

  testWidgets('加载失败时 toast 提示并保留空态', (tester) async {
    final container = await _bootstrap(
      FakeGoodsRepository(error: const GoodsException('商品加载失败')),
    );
    await _pumpPage(tester, container);
    await tester.pump(); // 构建 toast 弹层

    // toast 弹层出现后随 2s 定时器关闭
    expect(find.text('加载失败'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('加载失败'), findsNothing);
    expect(find.text('暂无商品'), findsOneWidget);
  });

  testWidgets('点击其他分类 Tab 触发对应关键词加载', (tester) async {
    final fake = FakeGoodsRepository();
    final container = await _bootstrap(fake);
    await _pumpPage(tester, container);
    await tester.pumpAndSettle();
    expect(fake.callCount, 1);

    await tester.tap(find.text('应急电源'));
    await tester.pumpAndSettle();

    expect(fake.callCount, 2);
    expect(fake.keywords, contains('应急电源'));
  });
}
