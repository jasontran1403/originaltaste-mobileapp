// lib/core/speed_test/slow_api_interceptor.dart

import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../speed_test/speed_test_controller.dart';

class SlowApiInterceptor extends Interceptor {
  final ProviderContainer container;

  static const _thresholdMs = 5000;

  final Map<int, Timer> _pendingTimers = {};

  SlowApiInterceptor(this.container);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final requestId = options.hashCode;

    _pendingTimers[requestId] = Timer(
      const Duration(milliseconds: _thresholdMs),
          () {
        _pendingTimers.remove(requestId);
        container.read(speedTestControllerProvider.notifier).triggerTest(
          reason: '${options.path} chưa phản hồi sau ${_thresholdMs ~/ 1000}s',
        );
      },
    );

    options.extra['_slowApiRequestId'] = requestId;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _cancelTimer(response.requestOptions);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _cancelTimer(err.requestOptions);

    // ── THÊM: trigger speed test khi lỗi mạng ──────────────
    if (_isNetworkError(err)) {
      container.read(speedTestControllerProvider.notifier).triggerTest(
        reason: _errorReason(err),
      );
    }

    handler.next(err);
  }

  void _cancelTimer(RequestOptions options) {
    final requestId = options.extra['_slowApiRequestId'] as int?;
    if (requestId != null) {
      _pendingTimers.remove(requestId)?.cancel();
    }
  }

  bool _isNetworkError(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.connectionError ||
        err.error is SocketException;
  }

  String _errorReason(DioException err) {
    final path = err.requestOptions.path;
    return switch (err.type) {
      DioExceptionType.connectionTimeout => '$path: kết nối timeout',
      DioExceptionType.receiveTimeout    => '$path: nhận dữ liệu timeout',
      DioExceptionType.sendTimeout       => '$path: gửi dữ liệu timeout',
      DioExceptionType.connectionError   => '$path: không kết nối được server',
      _                                  => '$path: lỗi mạng',
    };
  }
}