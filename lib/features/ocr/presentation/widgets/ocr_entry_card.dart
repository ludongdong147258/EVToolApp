import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:ev_tool_app/core/domain/ocr_receipt.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/utils/logger.dart';
import 'package:ev_tool_app/core/widgets/app_toast.dart';
import 'package:ev_tool_app/features/ocr/data/ocr_repository.dart';
import 'package:ev_tool_app/features/ocr/data/ocr_usage_repository.dart';
import 'package:ev_tool_app/features/pro/data/pro_repository.dart';
import 'package:ev_tool_app/features/pro/presentation/paywall_sheet.dart';

/// 秒数计时 ≥2s 才显示（快请求不闪烁数字），对齐小程序 ELAPSED_VISIBLE_DELAY。
const int _elapsedVisibleDelaySeconds = 2;

/// 拍照识别小票入口（虚线拍照区块，样式对齐小程序 .ocr-zone）。
///
/// - 单击拉起「拍照 / 从相册选择」，识别中整块半透明禁用，标题变「正在识别小票…Ns」
/// - 成功：回调 [onResult]（页面负责覆盖确认、回填与 toast）
/// - 失败：[onError] 上抛中文文案（页面渲染行内错误 + 重试）；空串表示清除错误
/// - 智谱 Key 未配置（[ocrAvailableProvider] false）时整体隐藏
class OcrEntryCard extends ConsumerStatefulWidget {
  const OcrEntryCard({super.key, this.onResult, this.onError});

  /// 识别成功回调（仅在有有效字段时触发）。
  final void Function(ReceiptResult result)? onResult;

  /// 错误文案回调（开始新识别时以空串清除）。
  final ValueChanged<String>? onError;

  @override
  ConsumerState<OcrEntryCard> createState() => OcrEntryCardState();
}

class OcrEntryCardState extends ConsumerState<OcrEntryCard> {
  final ImagePicker _picker = ImagePicker();
  bool _isRecognizing = false;
  int _elapsedSeconds = 0;
  Timer? _elapsedTimer;

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final available = ref.watch(ocrAvailableProvider);
    if (!available) {
      return const SizedBox.shrink();
    }
    final palette = context.palette;
    final isPro = ref.watch(proStatusProvider);
    final subtitle = isPro
        ? 'Take or pick a charging receipt photo to '
              'auto-fill cost, energy, and duration'
        : 'Take or pick a charging receipt photo to '
              'auto-fill cost, energy, and duration\n'
              '${ref.read(ocrUsageRepositoryProvider).remaining()} free scans left this month';
    final title = _isRecognizing
        ? 'Recognizing receipt…'
              '${_elapsedSeconds >= _elapsedVisibleDelaySeconds ? ' $_elapsedSeconds s' : ''}'
        : 'Scan charging receipt';

    return IgnorePointer(
      ignoring: _isRecognizing,
      child: Opacity(
        opacity: _isRecognizing ? 0.6 : 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          child: Material(
            color: palette.inputBg,
            child: InkWell(
              onTap: () => unawaited(openPicker()),
              child: CustomPaint(
                foregroundPainter: _DashedBorderPainter(
                  color: palette.primaryContainer,
                  radius: AppColors.radiusMd,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.photo_camera_outlined,
                        size: 26,
                        color: palette.primaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: palette.primaryContainer,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.textHint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 拉起来源选择（对齐小程序 chooseMedia 的 album/camera 双来源）。
  ///
  /// 公开给宿主页面：行内错误的「重试」按钮经 GlobalKey 重新调用。
  Future<void> openPicker() async {
    // Pro 门控：免费档每月 [AppConstants.freeOcrMonthlyQuota] 次，用尽弹付费墙
    if (!ref.read(proStatusProvider) &&
        !ref.read(ocrUsageRepositoryProvider).hasQuota()) {
      showAppToast(context, 'No free scans left this month');
      await showPaywallSheet(context);
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) {
      return; // 用户取消不算错误
    }
    await _pick(source);
  }

  Future<void> _pick(ImageSource source) async {
    if (_isRecognizing) {
      return;
    }
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        imageQuality: 90,
      );
      if (picked == null) {
        return;
      }
      await _recognize(picked.path);
    } on Exception catch (e) {
      appLogger.w('Failed to pick receipt image: $e');
      if (mounted) {
        showAppToast(context, 'Failed to pick an image — try again');
      }
    }
  }

  Future<void> _recognize(String imagePath) async {
    widget.onError?.call(''); // 开始新识别，清除行内错误
    setState(() {
      _isRecognizing = true;
      _elapsedSeconds = 0;
    });
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _elapsedSeconds++);
      }
    });
    try {
      final result = await ref
          .read(ocrRepositoryProvider)
          .recognizeReceipt(imagePath);
      if (!mounted) {
        return;
      }
      if (result == null || result.filledFields.isEmpty) {
        widget.onError?.call(
          'No valid details recognized — try again or fill in manually',
        );
        return;
      }
      // 成功才计数（Pro 不计数）
      if (!ref.read(proStatusProvider)) {
        unawaited(ref.read(ocrUsageRepositoryProvider).increment());
        if (mounted) setState(() {}); // 刷新剩余次数
      }
      widget.onResult?.call(result);
    } on OcrException catch (e) {
      appLogger.w('Receipt recognition failed: ${e.message}');
      if (mounted) {
        widget.onError?.call(e.message);
      }
    } on Exception catch (e) {
      appLogger.w('Receipt recognition error: $e');
      if (mounted) {
        widget.onError?.call('Recognition failed — try again');
      }
    } finally {
      _elapsedTimer?.cancel();
      _elapsedTimer = null;
      if (mounted) {
        setState(() => _isRecognizing = false);
      }
    }
  }
}

/// 圆角矩形虚线边框（Flutter 无原生 dashed border，用 path 度量逐段绘制）。
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  static const double _strokeWidth = 1.5;
  static const double _dashLength = 4;
  static const double _gap = 4;

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + _dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color || radius != oldDelegate.radius;
}
