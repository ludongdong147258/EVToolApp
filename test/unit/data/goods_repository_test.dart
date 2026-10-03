import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ev_tool_app/features/equipment/data/goods_repository.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/fake_key_value_store.dart';

typedef _Responder = ResponseBody Function(RequestOptions options);

Dio _buildDio(_Responder responder, List<RequestOptions> calls) {
  final dio = Dio(BaseOptions(baseUrl: 'https://goods.example.com'));
  dio.httpClientAdapter = FakeDioAdapter((options) {
    calls.add(options);
    return responder(options);
  });
  return dio;
}

/// 按 path 分发的响应：search 返回商品列表，promotion-url 返回推广短链。
_Responder _goodsResponder({
  Map<String, dynamic> searchBody = const {},
  Map<String, dynamic> promoBody = const {},
  int searchStatus = 200,
}) {
  return (options) {
    if (options.uri.path.contains('/api/Pinduoduo/search')) {
      return jsonResponseBody(searchBody, status: searchStatus);
    }
    return jsonResponseBody(promoBody);
  };
}

void main() {
  group('GoodsRepository（移植 goodsService.test.js 核心）', () {
    test('解析商品列表并按 goods_sign 下标对位推广短链', () async {
      final calls = <RequestOptions>[];
      final repo = GoodsRepository(
        _buildDio(
          _goodsResponder(
            searchBody: {
              'data': {
                'total_count': 2,
                'goods_list': [
                  {
                    'goods_sign': 'sign-a',
                    'goods_name': '便携充电枪 32A',
                    'goods_thumbnail_url': 'https://img/a.jpg',
                    'min_group_price': 129900,
                    'coupon_discount': 20000,
                    'sales': 120000,
                  },
                  {
                    'goods_sign': 'sign-b',
                    'goods_name': '随车充 16A',
                    'goods_thumbnail_url': 'https://img/b.jpg',
                    'min_group_price': 45900,
                    'coupon_discount': 0,
                    'sales': 8000,
                  },
                ],
              },
            },
            promoBody: {
              'data': {
                'goods_promotion_url_list': [
                  {
                    'goods_sign': 'sign-a',
                    'short_url': 'https://pdd.example/a',
                  },
                  {
                    'goods_sign': 'sign-b',
                    'short_url': 'https://pdd.example/b',
                  },
                ],
              },
            },
          ),
          calls,
        ),
        FakeKeyValueStore(),
      );

      final items = await repo.searchGoodsWithPromo('充电枪');

      // 请求次序与参数
      expect(calls.length, 2);
      final searchCall = calls[0];
      expect(searchCall.uri.path, '/api/Pinduoduo/search');
      expect(searchCall.queryParameters['keyword'], '充电枪');
      expect(searchCall.queryParameters['page'], 1);
      expect(searchCall.queryParameters['pageSize'], goodsPageSize);
      expect(searchCall.queryParameters['sortType'], 0);
      expect(searchCall.queryParameters['withCoupon'], true);
      final promoCall = calls[1];
      expect(promoCall.uri.path, '/api/Pinduoduo/promotion-url');
      expect(promoCall.data, isA<Map>());
      final promoData = promoCall.data as Map<dynamic, dynamic>;
      expect(promoData['goodsSignList'], ['sign-a', 'sign-b']);
      expect(promoData['generateWeApp'], false);
      expect(promoData['generateShortUrl'], true);

      // 解析 + 对位
      expect(items.length, 2);
      final a = items[0];
      expect(a.id, 'sign-a');
      expect(a.title, '便携充电枪 32A');
      expect(a.thumbUrl, 'https://img/a.jpg');
      expect(a.originalPrice, 129900);
      expect(a.couponAmount, 20000);
      expect(a.hasCoupon, true);
      expect(a.couponPrice, 109900);
      expect(a.shortUrl, 'https://pdd.example/a');
      expect(a.salesTip, '120k+ sold');
      final b = items[1];
      expect(b.hasCoupon, false);
      expect(b.couponPrice, 45900);
      expect(b.shortUrl, 'https://pdd.example/b');
      expect(b.salesTip, '8k sold');
    });

    test('接口响应缺字段时兜底为空列表', () async {
      final calls = <RequestOptions>[];
      final repo = GoodsRepository(
        _buildDio(_goodsResponder(searchBody: {}), calls),
        FakeKeyValueStore(),
      );

      final items = await repo.searchGoodsWithPromo('充电枪');

      expect(items, isEmpty);
      // 空列表不发起推广链接请求
      expect(calls.length, 1);
    });

    test('goods_sign 缺失的商品被过滤出推广请求但仍返回', () async {
      final calls = <RequestOptions>[];
      final repo = GoodsRepository(
        _buildDio(
          _goodsResponder(
            searchBody: {
              'data': {
                'total_count': 2,
                'goods_list': [
                  {'goods_sign': '', 'goods_name': '无签名商品'},
                  {'goods_name': '缺签名字段'},
                ],
              },
            },
          ),
          calls,
        ),
        FakeKeyValueStore(),
      );

      final items = await repo.searchGoodsWithPromo('充电枪');

      expect(items.length, 2);
      expect(calls.length, 1);
    });

    test('推广链接比商品少时按序对齐不越界', () async {
      final calls = <RequestOptions>[];
      final repo = GoodsRepository(
        _buildDio(
          _goodsResponder(
            searchBody: {
              'data': {
                'goods_list': [
                  {'goods_sign': 'sign-a', 'goods_name': 'A'},
                  {'goods_sign': 'sign-b', 'goods_name': 'B'},
                ],
              },
            },
            promoBody: {
              'data': {
                'goods_promotion_url_list': [
                  {'short_url': 'https://pdd.example/a'},
                ],
              },
            },
          ),
          calls,
        ),
        FakeKeyValueStore(),
      );

      final items = await repo.searchGoodsWithPromo('充电枪');

      expect(items[0].shortUrl, 'https://pdd.example/a');
      expect(items[1].shortUrl, '');
    });

    test('salesTip 解析中文 sales_tip 并折 k 展示', () {
      GoodsItem mk(String salesTip, [int sales = 0]) => GoodsItem(
        id: 's',
        title: 't',
        thumbUrl: '',
        originalPrice: 0,
        couponAmount: 0,
        sales: sales,
        salesTipRaw: salesTip,
      );

      expect(mk('10万+').salesTip, '100k+ sold');
      expect(mk('1.2万').salesTip, '12k sold');
      expect(mk('8500').salesTip, '8.5k sold');
      expect(mk('999').salesTip, '999 sold');
      // 带中文尾缀的销量文案（前缀匹配）
      expect(mk('1.2万人已拼').salesTip, '12k sold');
      expect(mk('10万+件').salesTip, '100k+ sold');
      // 无法解析的文案回退到数值 sales；0 销量不显示（避免虚构 "0 sold"）
      expect(mk('n/a', 3000).salesTip, '3k sold');
      expect(mk('n/a').salesTip, '');
      expect(mk('10万+', 0).salesTip, '100k+ sold');
    });

    test('非 2xx 抛中文 GoodsException', () async {
      final calls = <RequestOptions>[];
      final repo = GoodsRepository(
        _buildDio(_goodsResponder(searchStatus: 500), calls),
        FakeKeyValueStore(),
      );

      await expectLater(
        repo.searchGoodsWithPromo('充电枪'),
        throwsA(
          isA<GoodsException>().having(
            (e) => e.message,
            'message',
            'Failed to load products, please try again later',
          ),
        ),
      );
    });

    test('免责提示标记读写（equipment_tip_dismissed）', () async {
      final kv = FakeKeyValueStore();
      final repo = GoodsRepository(_buildDio(_goodsResponder(), []), kv);

      expect(repo.isTipDismissed(), false);
      await repo.markTipDismissed();
      expect(kv.getJson(equipmentTipStorageKey), true);
      expect(repo.isTipDismissed(), true);
    });
  });
}
