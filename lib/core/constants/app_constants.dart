class AppConstants {
  AppConstants._();

  static const String appName = 'EV Tool';
  static const String appVersion = '1.0.0';
  // 首次发表年份（版权声明起始年）；跨年后可改为区间，如 2026-${当前年}
  static const int copyrightStartYear = 2026;
  static const Duration networkTimeout = Duration(seconds: 30);
  // multipart 上传单独放宽超时(发送 + 等待服务端处理)。
  static const Duration uploadTimeout = Duration(seconds: 60);
  static const int maxRetryCount = 3;

  /// API 基础地址：编译期注入，运行时不可变。
  /// flutter run --dart-define=API_BASE_URL=https://api.example.com/
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.example.com/',
  );

  /// Returns a full URL for a relative path from the API.
  /// If [path] is already absolute (starts with http), returns it as-is.
  static String resolveUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final base = apiBaseUrl.endsWith('/')
        ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
        : apiBaseUrl;
    return '$base$path';
  }
}
