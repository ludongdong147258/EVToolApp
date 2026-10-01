import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:ev_tool_app/core/domain/ocr_receipt.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/utils/logger.dart';
import 'package:ev_tool_app/core/widgets/app_toast.dart';
import 'package:ev_tool_app/features/ocr/data/ocr_repository.dart';

/// 拍照识别小票入口卡（供 record-add 表单页嵌入）。
///
/// - 相机 / 相册两个入口（image_picker），识别中禁用并显示 spinner
/// - 成功：toast「识别成功 N 项」并回调 [onResult]（页面据此回填表单）
/// - 失败：error toast 中文文案
/// - 智谱 Key 未配置（[ocrAvailableProvider] false）时整体隐藏
class OcrEntryCard extends ConsumerStatefulWidget {
  const OcrEntryCard({super.key, this.onResult});

  /// 识别成功回调（仅在有有效字段时触发）
  final void Function(ReceiptResult result)? onResult;

  @override
  ConsumerState<OcrEntryCard> createState() => _OcrEntryCardState();
}

class _OcrEntryCardState extends ConsumerState<OcrEntryCard> {
  final ImagePicker _picker = ImagePicker();
  bool _isRecognizing = false;

  @override
  Widget build(BuildContext context) {
    final available = ref.watch(ocrAvailableProvider);
    if (!available) {
      return const SizedBox.shrink();
    }
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_outlined, color: palette.primary),
              const SizedBox(width: 8),
              Text('拍照识别小票', style: context.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '拍摄充电小票，自动识别费用、电量、时长等信息',
            style: context.textTheme.bodySmall?.copyWith(
              color: palette.textHint,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PickButton(
                  icon: Icons.camera_alt_outlined,
                  label: '拍照识别',
                  loading: _isRecognizing,
                  onTap: () => unawaited(_pick(ImageSource.camera)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PickButton(
                  icon: Icons.photo_library_outlined,
                  label: '相册识别',
                  loading: _isRecognizing,
                  onTap: () => unawaited(_pick(ImageSource.gallery)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
      appLogger.w('选择识别图片失败：$e');
      if (mounted) {
        showAppToast(context, '图片选择失败，请重试');
      }
    }
  }

  Future<void> _recognize(String imagePath) async {
    setState(() => _isRecognizing = true);
    try {
      final result = await ref
          .read(ocrRepositoryProvider)
          .recognizeReceipt(imagePath);
      if (!mounted) {
        return;
      }
      if (result == null || result.filledFields.isEmpty) {
        showAppToast(context, '未能识别出有效信息，请换一张更清晰的照片');
        return;
      }
      showAppToast(context, '识别成功 ${result.filledFields.length} 项');
      widget.onResult?.call(result);
    } on OcrException catch (e) {
      appLogger.w('小票识别失败：${e.message}');
      if (mounted) {
        showErrorToast(context, e.message);
      }
    } on Exception catch (e) {
      appLogger.w('小票识别异常：$e');
      if (mounted) {
        showErrorToast(context, '识别失败，请重试');
      }
    } finally {
      if (mounted) {
        setState(() => _isRecognizing = false);
      }
    }
  }
}

class _PickButton extends StatelessWidget {
  const _PickButton({
    required this.icon,
    required this.label,
    required this.loading,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return OutlinedButton.icon(
      onPressed: loading ? null : onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        side: BorderSide(color: palette.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
        ),
      ),
      icon: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 18, color: palette.primary),
      label: Text(loading ? '识别中…' : label),
    );
  }
}
