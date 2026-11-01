// lib/shared/widgets/app_image.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'app_skeleton.dart';

class AppImage extends StatelessWidget {
  final String? url;
  final String? cacheKey; // dùng khi đổi ảnh để bust cache
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const AppImage({
    super.key,
    this.url,
    this.cacheKey,
    this.width,
    this.height,
    this.borderRadius = 0,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = url == null || url!.isEmpty;

    Widget image = isEmpty
        ? _buildError()
        : CachedNetworkImage(
            imageUrl: url!,
            cacheKey: cacheKey ?? url,
            width: width,
            height: height,
            fit: fit,
            maxWidthDiskCache: 800,
            maxHeightDiskCache: 800,
            placeholder: (_, __) =>
                placeholder ??
                AppSkeleton(
                  width: width ?? double.infinity,
                  height: height ?? double.infinity,
                  borderRadius: borderRadius,
                ),
            errorWidget: (_, __, ___) => _buildError(),
          );

    if (borderRadius > 0) {
      image = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: image,
      );
    }

    return image;
  }

  Widget _buildError() {
    return errorWidget ??
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: const Icon(
            Icons.image_not_supported_rounded,
            color: Color(0xFF4B5563),
            size: 24,
          ),
        );
  }
}
