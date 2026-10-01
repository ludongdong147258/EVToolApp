import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/domain/vehicles.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/features/vehicles/data/photo_store.dart';

/// 车辆头像：photoPath 经 [PhotoStore] 解析后以文件图渲染；
/// 无照片 / 文件缺失 / 存储未就绪时回退车图标圆形底。
///
/// 记录页的 _VehicleAvatar 后续可切换到本组件（见 record_card.dart）。
class VehicleAvatar extends ConsumerWidget {
  const VehicleAvatar({super.key, required this.vehicle, this.size = 44});

  final Vehicle vehicle;

  /// 头像直径（px）。
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = vehicle.photoPath;
    if (photo.isEmpty) {
      return _fallback(context);
    }
    final store = ref.watch(photoStoreProvider);
    return store.when(
      data: (s) {
        final file = File(s.resolvePath(photo));
        if (!file.existsSync()) {
          return _fallback(context);
        }
        return ClipOval(
          child: Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallback(context),
          ),
        );
      },
      loading: () => _fallback(context),
      error: (_, _) => _fallback(context),
    );
  }

  Widget _fallback(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.secondaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.directions_car_rounded,
        size: size * 0.55,
        color: palette.onSecondaryContainer,
      ),
    );
  }
}
