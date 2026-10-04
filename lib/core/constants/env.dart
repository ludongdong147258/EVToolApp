import 'package:flutter_dotenv/flutter_dotenv.dart';

/// .env 访问层：集中管理第三方服务配置，缺失时返回空串由调用方降级。
///
/// 对应小程序 src/services/apiConfig.js。
abstract final class Env {
  static const String _zhipuKey = 'ZHIPU_API_KEY';
  static const String _goodsBase = 'GOODS_API_BASE';

  static String _get(String name) =>
      dotenv.isInitialized ? (dotenv.env[name] ?? '') : '';

  /// 智谱 AI key（GLM-4V 小票 OCR）；空串表示未配置。
  static String get zhipuKey => _get(_zhipuKey);

  /// 是否配置了智谱 key（决定 OCR 入口是否展示）。
  static bool get hasZhipuKey => zhipuKey.isNotEmpty;

  /// 装备导购商品 API 基础地址。
  static String get goodsApiBase {
    final base = _get(_goodsBase);
    return base.isNotEmpty ? base : 'https://www.fishspotradar.cn';
  }
}
