// lib/shared/widgets/app_skeleton.dart

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../app/theme/app_colors.dart';

class AppSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const AppSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  /// Full width skeleton
  const AppSkeleton.full({
    super.key,
    required this.height,
    this.borderRadius = 8,
  }) : width = double.infinity;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base  = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);
    final shine = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF3F4F6);

    return Shimmer.fromColors(
      baseColor:  base,
      highlightColor: shine,
      child: Container(
        width:  width,
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Skeleton cho card dạng list item
class AppSkeletonListItem extends StatelessWidget {
  const AppSkeletonListItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          AppSkeleton(width: 48, height: 48, borderRadius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSkeleton.full(height: 14),
                const SizedBox(height: 8),
                AppSkeleton(width: 120, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton cho card dạng grid
class AppSkeletonCard extends StatelessWidget {
  const AppSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkBorder
              : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSkeleton.full(height: 100, borderRadius: 8),
          const SizedBox(height: 10),
          const AppSkeleton.full(height: 14),
          const SizedBox(height: 6),
          AppSkeleton(width: 80, height: 12),
        ],
      ),
    );
  }
}
