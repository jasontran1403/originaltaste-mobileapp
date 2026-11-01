// lib/shared/widgets/tab_transition.dart

import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import 'app_skeleton.dart';

enum _TabState { loading, skeleton, done }

/// Widget xử lý loading khi chuyển tab:
/// 1. Hiện loading spinner 1s (đồng thời fetch data)
/// 2. Nếu fetch xong < 1s → đợi đủ 1s → hiện content
/// 3. Nếu fetch > 1s → hiện skeleton (min 600ms) → hiện content
///
/// Usage:
/// ```dart
/// TabTransitionWidget(
///   future: controller.fetchData(),
///   skeletonBuilder: () => MySkeletonWidget(),
///   builder: (data) => MyContentWidget(data: data),
/// )
/// ```
class TabTransitionWidget<T> extends StatefulWidget {
  final Future<T> Function() futureBuilder;
  final Widget Function(T data) builder;
  final Widget Function()? skeletonBuilder;
  final Widget? loadingWidget;

  const TabTransitionWidget({
    super.key,
    required this.futureBuilder,
    required this.builder,
    this.skeletonBuilder,
    this.loadingWidget,
  });

  @override
  State<TabTransitionWidget<T>> createState() => _TabTransitionWidgetState<T>();
}

class _TabTransitionWidgetState<T> extends State<TabTransitionWidget<T>> {
  _TabState _state = _TabState.loading;
  T? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final fetchStart = DateTime.now();
    T? result;
    String? err;

    // Fetch data + 1s loading đồng thời
    await Future.wait([
      widget.futureBuilder().then((v) => result = v).catchError((e) {
        err = e.toString();
      }),
      Future.delayed(AppConstants.tabLoadingDuration),
    ]);

    if (!mounted) return;

    _data  = result;
    _error = err;

    final elapsed = DateTime.now().difference(fetchStart);

    if (elapsed <= AppConstants.tabLoadingDuration) {
      // Fetch xong trong 1s → hiện content ngay
      setState(() => _state = _TabState.done);
    } else {
      // Fetch > 1s → hiện skeleton thêm tối thiểu 600ms
      setState(() => _state = _TabState.skeleton);

      final skeletonStart = DateTime.now();
      // Đợi tối thiểu 600ms tính từ lúc hiện skeleton
      await Future.delayed(AppConstants.skeletonMinDuration);

      if (!mounted) return;
      setState(() => _state = _TabState.done);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: switch (_state) {
        _TabState.loading  => _buildLoading(),
        _TabState.skeleton => _buildSkeleton(),
        _TabState.done     => _buildContent(),
      },
    );
  }

  Widget _buildLoading() {
    return widget.loadingWidget ??
        const Center(
          key: ValueKey('loading'),
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(Color(0xFF4ADE80)),
            ),
          ),
        );
  }

  Widget _buildSkeleton() {
    return widget.skeletonBuilder != null
        ? KeyedSubtree(
            key: const ValueKey('skeleton'),
            child: widget.skeletonBuilder!(),
          )
        : _DefaultSkeleton(key: const ValueKey('skeleton'));
  }

  Widget _buildContent() {
    if (_error != null) {
      return _ErrorWidget(
        key: const ValueKey('error'),
        message: _error!,
        onRetry: () {
          setState(() {
            _state = _TabState.loading;
            _data  = null;
            _error = null;
          });
          _start();
        },
      );
    }
    if (_data == null) return const SizedBox(key: ValueKey('empty'));
    return KeyedSubtree(
      key: const ValueKey('content'),
      child: widget.builder(_data as T),
    );
  }
}

class _DefaultSkeleton extends StatelessWidget {
  const _DefaultSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      itemBuilder: (_, __) => const AppSkeletonListItem(),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorWidget({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFF6B7280)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 140,
              child: ElevatedButton(
                onPressed: onRetry,
                child: const Text('Thử lại'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
