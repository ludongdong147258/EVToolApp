import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/constants/env.dart';
import 'package:ev_tool_app/core/storage/key_value_store.dart';
import 'package:ev_tool_app/core/utils/logger.dart';

/// 装备导购商品仓储（移植小程序 src/services/goodsService.js）。
///
/// 封装第三方「拼多多商品搜索 + 推广链接」接口（GOODS_API_BASE，无需鉴权），
/// 并维护免责弹窗「不再提示」的本机标记。不复用dioProvider：该第三方接口
/// 无需鉴权，挂 Bearer token 会把本站用户 token 发给第三方域，且 401 会触发
/// 本站刷新链路，纯展示型请求不应有此副作用，故自建无鉴权专用 Dio。
class GoodsException implements Exception {
  const GoodsException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 免责弹窗「不再提示」标记在本机 storage 的 key
const String equipmentTipStorageKey = 'equipment_tip_dismissed';

/// 搜索分页大小（与小程序 PAGE_SIZE 一致）
const int goodsPageSize = 10;

/// 单件商品（价格字段单位为分，展示时经 formatPrice 转元）
class GoodsItem {
  const GoodsItem({
    required this.id,
    required this.title,
    required this.thumbUrl,
    required this.originalPrice,
    required this.couponAmount,
    required this.sales,
    this.salesTipRaw = '',
    this.shortUrl = '',
  });

  factory GoodsItem.fromSearchJson(Map<String, dynamic> json) => GoodsItem(
    id: json['goods_sign'] is String ? json['goods_sign'] as String : '',
    title: json['goods_name'] is String ? json['goods_name'] as String : '',
    thumbUrl: json['goods_thumbnail_url'] is String
        ? json['goods_thumbnail_url'] as String
        : '',
    originalPrice: (json['min_group_price'] as num?)?.toInt() ?? 0,
    couponAmount: (json['coupon_discount'] as num?)?.toInt() ?? 0,
    sales: (json['sales'] as num?)?.toInt() ?? 0,
    // 拼多多接口只回 sales_tip 文案（如 "10万+"），数值 sales 常缺失
    salesTipRaw: json['sales_tip'] is String ? json['sales_tip'] as String : '',
  );

  /// goods_sign（拼多多商品签名）
  final String id;
  final String title;
  final String thumbUrl;

  /// 最低拼团价（分）
  final int originalPrice;

  /// 优惠券金额（分）；> 0 表示带券
  final int couponAmount;

  /// 销量（件）
  final int sales;

  /// 接口返回的销量文案（如 "10万+"；小程序同款直接展示）
  final String salesTipRaw;

  /// 推广短链（promotion-url 对位回填）
  final String shortUrl;

  GoodsItem withShortUrl(String url) => GoodsItem(
    id: id,
    title: title,
    thumbUrl: thumbUrl,
    originalPrice: originalPrice,
    couponAmount: couponAmount,
    sales: sales,
    salesTipRaw: salesTipRaw,
    shortUrl: url,
  );

  bool get hasCoupon => couponAmount > 0;

  /// 券后价（分）＝ 最低拼团价 − 优惠券金额
  int get couponPrice =>
      hasCoupon ? originalPrice - couponAmount : originalPrice;

  /// 销量文案：优先接口 sales_tip（中文 "10万+" / "1.2万人已拼" 折 k）；
  /// 数值兜底，0 销量不显示（避免虚构 "0 sold"）
  String get salesTip {
    if (salesTipRaw.isNotEmpty) {
      final count = parseSalesTipCount(salesTipRaw);
      if (count != null) {
        final plus = salesTipRaw.contains('+') ? '+' : '';
        return '${formatSalesCount(count)}$plus sold';
      }
    }
    if (sales > 0) {
      final plus = sales >= 10000 ? '+' : '';
      return '${formatSalesCount(sales)}$plus sold';
    }
    return '';
  }
}

/// 中文销量文案（"10万+" / "1.2万人已拼" / "8500"）→ 数值（万 = ×10,000）。
/// 前缀匹配，忽略中文尾缀；无法解析时返回 null。
int? parseSalesTipCount(String raw) {
  final match = RegExp(r'^(\d+(?:\.\d+)?)(万)?').firstMatch(raw.trim());
  if (match == null) {
    return null;
  }
  final value = double.parse(match.group(1)!);
  return (match.group(2) != null ? value * 10000 : value).round();
}

/// 数值 → 英文缩写："8500"→"8.5k"、"120000"→"120k"、"800"→"800"。
String formatSalesCount(num value) {
  if (value >= 1000) {
    final k = value / 1000;
    final kText = k == k.roundToDouble()
        ? k.toInt().toString()
        : k.toStringAsFixed(1);
    return '${kText}k';
  }
  return value.round().toString();
}

class GoodsRepository {
  GoodsRepository(this._dio, this._kv);

  final Dio _dio;
  final KeyValueStore _kv;

  /// 一次性获取「搜索结果 + 对应推广短链」组合，供页面直接渲染。
  ///
  /// 推广信息按 goods_sign 下标对位（promotion-url 返回顺序与传入一致）。
  Future<List<GoodsItem>> searchGoodsWithPromo(
    String keyword, {
    int page = 1,
  }) async {
    final list = await searchGoods(keyword, page: page);
    final signs = [
      for (final item in list)
        if (item.id.isNotEmpty) item.id,
    ];
    if (signs.isEmpty) {
      return list;
    }
    final promoList = await _fetchPromotionUrls(signs);
    final urlBySign = <String, String>{};
    for (var i = 0; i < promoList.length && i < signs.length; i++) {
      final promo = promoList[i];
      final shortUrl = promo is Map && promo['short_url'] is String
          ? promo['short_url'] as String
          : '';
      if (shortUrl.isNotEmpty) {
        urlBySign[signs[i]] = shortUrl;
      }
    }
    return [
      for (final item in list)
        urlBySign.containsKey(item.id)
            ? item.withShortUrl(urlBySign[item.id] ?? '')
            : item,
    ];
  }

  /// 搜索拼多多商品（GET /api/Pinduoduo/search）。
  Future<List<GoodsItem>> searchGoods(String keyword, {int page = 1}) async {
    final body = await _requestJson(
      () => _dio.get<dynamic>(
        '/api/Pinduoduo/search',
        queryParameters: <String, dynamic>{
          'keyword': keyword,
          'page': page,
          'pageSize': goodsPageSize,
          'sortType': 0,
          'withCoupon': true,
        },
      ),
    );
    return [
      for (final item in _innerList(body, 'goods_list') ?? const <dynamic>[])
        if (item is Map<String, dynamic>) GoodsItem.fromSearchJson(item),
    ];
  }

  /// 批量获取推广链接（POST /api/Pinduoduo/promotion-url）。
  ///
  /// iOS 端微信小程序 weapp 链接无用，只请求短链
  /// （generateWeApp: false + generateShortUrl: true）。
  Future<List<dynamic>> _fetchPromotionUrls(List<String> goodsSignList) async {
    final body = await _requestJson(
      () => _dio.post<dynamic>(
        '/api/Pinduoduo/promotion-url',
        data: <String, dynamic>{
          'goodsSignList': goodsSignList,
          'generateWeApp': false,
          'generateShortUrl': true,
        },
      ),
    );
    final list = _innerList(body, 'goods_promotion_url_list');
    return list ?? const <dynamic>[];
  }

  /// 统一请求：Dio JSON transformer 负责解码，失败统一抛中文 [GoodsException]。
  Future<dynamic> _requestJson(
    Future<Response<dynamic>> Function() call,
  ) async {
    try {
      final response = await call();
      return response.data;
    } on DioException catch (e) {
      appLogger.w('Goods request failed: ${e.message}');
      throw const GoodsException(
        'Failed to load products, please try again later',
      );
    }
  }

  /// 免责弹窗是否已被用户标记「不再提示」（读取异常按未标记处理）
  bool isTipDismissed() => _kv.getJson(equipmentTipStorageKey) == true;

  /// 标记免责弹窗「不再提示」
  Future<void> markTipDismissed() => _kv.setJson(equipmentTipStorageKey, true);
}

/// 取响应 body 中 `data` 键下指定键的数组；缺失返回 null。
List<dynamic>? _innerList(dynamic body, String key) {
  if (body is! Map) {
    return null;
  }
  final data = body['data'];
  if (data is! Map) {
    return null;
  }
  return data[key] is List ? data[key] as List : null;
}

/// 装备导购专用无鉴权 Dio（15s 超时，不挂用户 token / 拦截器）。
final goodsDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.goodsApiBase,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      responseType: ResponseType.json,
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});

final goodsRepositoryProvider = Provider<GoodsRepository>(
  (ref) => GoodsRepository(
    ref.watch(goodsDioProvider),
    ref.watch(keyValueStoreProvider),
  ),
);
