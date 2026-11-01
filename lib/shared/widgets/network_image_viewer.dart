// lib/shared/widgets/network_image_viewer.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/constants/api_constants.dart';

class NetworkImageViewer extends StatelessWidget {
  final String? imageUrl;
  final double? height;
  final double? width;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool forceRefresh;

  const NetworkImageViewer({
    super.key,
    this.imageUrl,
    this.height,
    this.width,
    this.fit = BoxFit.contain,
    this.placeholder,
    this.errorWidget,
    this.forceRefresh = false,
  });

  bool get _hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  String _getFullUrl() {
    if (!_hasImage) return '';

    String url = imageUrl!;

    if (!url.startsWith('http')) {
      // Normalize: bỏ leading slash nếu có
      final path = url.startsWith('/') ? url.substring(1) : url;

      // Nếu path đã có 'images/' ở đầu → dùng luôn
      // Nếu không → thêm 'images/' vào giữa
      // Kết quả: baseUrl/api/auth/images/pos-product/filename.png
      final normalizedPath =
      path.startsWith('images/') ? path : 'images/$path';

      url = '${ApiConstants.baseUrl}${ApiConstants.images}/$normalizedPath';
    }

    if (forceRefresh && !kDebugMode) {
      url = url.contains('?') ? '$url&t=${DateTime.now().millisecondsSinceEpoch}'
          : '$url?t=${DateTime.now().millisecondsSinceEpoch}';
    }

    return url;
  }

  Widget _defaultSkeleton(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerHighest,
      child: const ShimmerPlaceholder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasImage) return const SizedBox.shrink();

    final fullUrl = _getFullUrl();
    final primary = Theme.of(context).brightness == Brightness.dark
        ? AppColors.primary
        : AppColors.primaryDark;

    final effectivePlaceholder = placeholder ?? _defaultSkeleton(context);

    if (kDebugMode) {
      return Image.network(
        fullUrl,
        height: height,
        width:  width,
        fit:    fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return effectivePlaceholder;
        },
        errorBuilder: (context, error, stackTrace) =>
        errorWidget ?? _defaultError(context),
        headers: const {'ngrok-skip-browser-warning': 'true'},
      );
    } else {
      return CachedNetworkImage(
        imageUrl:    fullUrl,
        height:      height,
        width:       width,
        fit:         fit,
        httpHeaders: const {'ngrok-skip-browser-warning': 'true'},
        placeholder: (context, url) => effectivePlaceholder,
        errorWidget: (context, url, error) =>
        errorWidget ?? _defaultError(context),
        fadeInDuration:  const Duration(milliseconds: 300),
        fadeOutDuration: const Duration(milliseconds: 300),
      );
    }
  }

  Widget _defaultError(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.broken_image_rounded,
            size: 48, color: cs.error.withOpacity(0.7)),
        const SizedBox(height: 8),
        Text('Không tải được ảnh',
            style: TextStyle(fontSize: 12, color: cs.error.withOpacity(0.8))),
      ],
    );
  }
}

// ── Shimmer skeleton ──────────────────────────────────────────

class ShimmerPlaceholder extends StatefulWidget {
  const ShimmerPlaceholder({super.key});

  @override
  State<ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double>   _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(_animation.value - 1, 0),
            end:   Alignment(_animation.value + 1, 0),
            colors: [
              cs.surfaceContainerHighest.withOpacity(0.6),
              cs.surfaceContainerHighest.withOpacity(0.3),
              cs.surfaceContainerHighest.withOpacity(0.6),
            ],
          ),
        ),
      ),
    );
  }
}