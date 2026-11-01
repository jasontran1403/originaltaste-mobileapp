// lib/features/pos/screens/pos_screen.dart
import 'package:flutter/material.dart';
import 'package:originaltaste/features/pos/screens/pos_product_grid_screen.dart';
import 'package:originaltaste/features/pos/screens/pos_history_screen.dart';

/// /pos route — màn hình bán hàng chính
class PosScreen extends StatelessWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).orientation == Orientation.portrait) {
      return const _RotatePrompt();
    }
    return const PosProductGridScreen();
  }
}

/// /pos-history route
class PosHistoryRouteScreen extends StatelessWidget {
  const PosHistoryRouteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PosHistoryScreen();
  }
}

class _RotatePrompt extends StatelessWidget {
  const _RotatePrompt();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.screen_rotation_alt, size: 80, color: cs.primary),
          const SizedBox(height: 24),
          Text('Vui lòng xoay ngang thiết bị',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Ứng dụng POS được thiết kế tối ưu cho chế độ ngang',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: cs.onSurface.withOpacity(0.55),
              ),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}