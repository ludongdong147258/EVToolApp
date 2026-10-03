import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/utils/logger.dart';
import 'package:ev_tool_app/core/widgets/app_sheet.dart';
import 'package:ev_tool_app/core/widgets/app_toast.dart';
import 'package:ev_tool_app/core/widgets/empty_state.dart';
import 'package:ev_tool_app/features/equipment/data/goods_repository.dart';
import 'package:ev_tool_app/features/equipment/presentation/equipment_categories.dart';
import 'package:ev_tool_app/features/equipment/presentation/widgets/goods_card.dart';
import 'package:ev_tool_app/features/equipment/presentation/widgets/goods_detail_sheet.dart';

/// 触底加载阈值（px）
const double _loadMoreThreshold = 200;

/// 瀑布流双列间距
const double _columnGap = 8;

/// 装备导购页（充电装备，拼多多带券商品瀑布流）。
///
/// 移植小程序 equipment 页（去微信小程序专属逻辑）：
/// 6 分类 Tab + 双列瀑布流 + 首屏骨架屏 + 下拉刷新 + 触底分页 +
/// 首次进入免责声明（不再提示，持久化 equipment_tip_dismissed）。
class EquipmentPage extends ConsumerStatefulWidget {
  const EquipmentPage({super.key});

  @override
  ConsumerState<EquipmentPage> createState() => _EquipmentPageState();
}

class _EquipmentPageState extends ConsumerState<EquipmentPage> {
  int _currentTab = 0;
  final Map<int, List<GoodsItem>> _goodsMap = {};
  final Map<int, int> _pageMap = {};
  final Map<int, bool> _hasMoreMap = {};
  final Map<int, bool> _loadingMap = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTip());
    unawaited(_fetchGoods(0));
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  GoodsRepository get _repo => ref.read(goodsRepositoryProvider);

  /// 首次进入免责声明（标记过「不再提示」则跳过）。
  Future<void> _maybeShowTip() async {
    if (!mounted || _repo.isTipDismissed()) {
      return;
    }
    var dontShowAgain = false;
    await showAppSheet(
      context: context,
      title: 'Friendly reminder',
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              equipmentTipText,
              style: Theme.of(
                sheetContext,
              ).textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
            InkWell(
              onTap: () => setSheetState(() => dontShowAgain = !dontShowAgain),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: dontShowAgain,
                        onChanged: (checked) => setSheetState(
                          () => dontShowAgain = checked ?? false,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text("Don't show again"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () {
                if (dontShowAgain) {
                  unawaited(_markTipDismissed());
                }
                Navigator.of(sheetContext).pop();
              },
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markTipDismissed() async {
    try {
      await _repo.markTipDismissed();
    } on Exception catch (e) {
      appLogger.w('Failed to persist equipment tip dismissed flag: $e');
    }
  }

  /// 拉取商品列表（isLoadMore 为 true 时追加下一页）。
  Future<void> _fetchGoods(int tabIndex, {bool isLoadMore = false}) async {
    if (_loadingMap[tabIndex] == true ||
        tabIndex < 0 ||
        tabIndex >= equipmentCategories.length) {
      return;
    }
    final category = equipmentCategories[tabIndex];
    final page = isLoadMore ? (_pageMap[tabIndex] ?? 1) + 1 : 1;
    setState(() => _loadingMap[tabIndex] = true);
    try {
      final list = await _repo.searchGoodsWithPromo(
        category.keyword,
        page: page,
      );
      if (!mounted) {
        return;
      }
      final prev = isLoadMore
          ? (_goodsMap[tabIndex] ?? const <GoodsItem>[])
          : const <GoodsItem>[];
      final all = [...prev, ...list];
      setState(() {
        _goodsMap[tabIndex] = all;
        _pageMap[tabIndex] = page;
        _hasMoreMap[tabIndex] = list.length >= goodsPageSize;
        _loadingMap[tabIndex] = false;
      });
    } on GoodsException catch (e) {
      appLogger.w('Failed to load goods: $e');
      if (!mounted) {
        return;
      }
      setState(() => _loadingMap[tabIndex] = false);
      showAppToast(context, 'Failed to load');
    }
  }

  void _handleTabClick(int index) {
    if (index == _currentTab) {
      return;
    }
    setState(() => _currentTab = index);
    unawaited(_fetchGoods(index));
  }

  /// 下拉刷新当前分类（重拉第 1 页并整体替换）。
  Future<void> _handleRefresh() async {
    final category = equipmentCategories[_currentTab];
    try {
      final list = await _repo.searchGoodsWithPromo(category.keyword, page: 1);
      if (!mounted) {
        return;
      }
      setState(() {
        _goodsMap[_currentTab] = list;
        _pageMap[_currentTab] = 1;
        _hasMoreMap[_currentTab] = list.length >= goodsPageSize;
      });
    } on GoodsException catch (e) {
      appLogger.w('Failed to refresh goods: $e');
      if (mounted) {
        showAppToast(context, 'Refresh failed — check your network');
      }
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      if ((_hasMoreMap[_currentTab] ?? false) &&
          _loadingMap[_currentTab] != true) {
        unawaited(_fetchGoods(_currentTab, isLoadMore: true));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final goods = _goodsMap[_currentTab];
    final isLoading = _loadingMap[_currentTab] == true;
    final isFirstLoading = isLoading && (goods == null);
    final isEmpty = !isLoading && (goods == null || goods.isEmpty);

    return Scaffold(
      appBar: AppBar(title: const Text('Charging Gear'), centerTitle: true),
      body: Column(
        children: [
          _buildTabs(context),
          Expanded(
            child: isFirstLoading
                ? _buildSkeletonList()
                : (isEmpty
                      ? _buildEmpty()
                      : _buildGoodsList(goods ?? const <GoodsItem>[])),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        border: Border(bottom: BorderSide(color: palette.divider, width: 0.5)),
      ),
      // 英文标题较长，6 等分会全部截断——改为横向滚动，tab 宽度随内容
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < equipmentCategories.length; i++)
              _buildTab(context, equipmentCategories[i], i),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(
    BuildContext context,
    EquipmentCategory category,
    int index,
  ) {
    final palette = context.palette;
    final isActive = index == _currentTab;
    return InkWell(
      onTap: () => _handleTabClick(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            child: Text(
              category.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodyMedium?.copyWith(
                color: isActive ? palette.primary : palette.textHint,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          Container(
            height: 2,
            color: isActive ? palette.primary : Colors.transparent,
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonList() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildSkeletonColumn()),
          const SizedBox(width: _columnGap),
          Expanded(child: _buildSkeletonColumn()),
        ],
      ),
    );
  }

  Widget _buildSkeletonColumn() {
    return Column(
      children: List.generate(
        equipmentSkeletonCount ~/ 2,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: _columnGap),
          child: GoodsSkeletonCard(),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: EmptyState(
        compact: true,
        icon: Icons.shopping_bag_outlined,
        title: 'No products yet',
        subtitle: 'Pull down to refresh, or tap to retry',
        ctaText: 'Reload',
        onCta: () => unawaited(_fetchGoods(_currentTab)),
      ),
    );
  }

  Widget _buildGoodsList(List<GoodsItem> goods) {
    final (left, right) = _splitColumns(goods);
    final isLoading = _loadingMap[_currentTab] == true;
    final hasMore = _hasMoreMap[_currentTab] ?? false;
    final palette = context.palette;

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildColumn(left)),
                const SizedBox(width: _columnGap),
                Expanded(child: _buildColumn(right)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                isLoading ? 'Loading...' : (hasMore ? '' : 'No more items'),
                style: context.textTheme.bodySmall?.copyWith(
                  color: palette.textHint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColumn(List<GoodsItem> items) {
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: _columnGap),
            child: GoodsCard(
              item: item,
              onTap: () => unawaited(showGoodsDetailSheet(context, item)),
            ),
          ),
      ],
    );
  }

  /// 双列瀑布流分桶：按「标题行数估算高度」往较矮列追加，近似视觉均衡。
  (List<GoodsItem>, List<GoodsItem>) _splitColumns(List<GoodsItem> goods) {
    const charsPerLine = 10;
    const titleLineHeight = 18.0;
    const bottomBlockHeight = 56.0;
    final left = <GoodsItem>[];
    final right = <GoodsItem>[];
    var leftHeight = 0.0;
    var rightHeight = 0.0;
    for (final item in goods) {
      final titleLines = ((item.title.length) / charsPerLine).ceil().clamp(
        1,
        3,
      );
      final estimated =
          goodsCardImageHeight +
          titleLines * titleLineHeight +
          bottomBlockHeight;
      if (leftHeight <= rightHeight) {
        left.add(item);
        leftHeight += estimated;
      } else {
        right.add(item);
        rightHeight += estimated;
      }
    }
    return (left, right);
  }
}
