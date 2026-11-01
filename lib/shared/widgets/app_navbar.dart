// lib/shared/widgets/app_navbar.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/app_colors.dart';
import '../../core/enums/nav_item.dart';

class AppNavbar extends StatelessWidget {
  final List<NavItem> items;
  final NavItem selected;
  final void Function(NavItem) onTap;

  const AppNavbar({
    super.key,
    required this.items,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkNavbar : AppColors.lightNavbar;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    // Tính font size động theo width màn hình
    final screenWidth = MediaQuery.of(context).size.width;
    double fontSize = 13.0;
    if (screenWidth < 600) {
      fontSize = 13.0 * 0.7; // Mobile: nhỏ hơn
    } else if (screenWidth < 900) {
      fontSize = 13.0 * 0.9; // Tablet dọc
    }

    // Kiểm tra mobile để ẩn label hoàn toàn
    final isMobile = screenWidth < 600;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: 15,
      ),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: items.map((item) {
            final isSelected = item == selected;
            return Expanded(
              child: _NavItemWidget(
                item: item,
                isSelected: isSelected,
                isDark: isDark,
                fontSize: fontSize,
                isMobile: isMobile, // Truyền thêm flag mobile
                onTap: () {
                  if (!isSelected) {
                    HapticFeedback.lightImpact();
                    onTap(item);
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _NavItemWidget extends StatelessWidget {
  final NavItem item;
  final bool isSelected;
  final bool isDark;
  final double fontSize;
  final bool isMobile; // Flag mới: mobile thì ẩn label
  final VoidCallback onTap;

  const _NavItemWidget({
    required this.item,
    required this.isSelected,
    required this.isDark,
    required this.fontSize,
    required this.isMobile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? AppColors.darkIconActive : AppColors.lightIconActive;
    final inactiveColor = isDark ? AppColors.darkIcon : AppColors.lightIcon;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.all(6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.darkCard : AppColors.lightBorder)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center, // Căn giữa icon khi ẩn label
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected ? activeColor : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                item.icon,
                size: 24, // Tăng size icon một chút để nổi bật hơn khi ẩn label
                color: isSelected ? Colors.black : inactiveColor,
              ),
            ),

            // Label chỉ hiển thị nếu KHÔNG phải mobile
            if (!isMobile)
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: isSelected
                    ? Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                    : const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}