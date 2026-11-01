// lib/core/speed_test/speed_test_controller.dart

import 'dart:async';
import 'package:flutter_internet_speed_test_pro/flutter_internet_speed_test_pro.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SpeedTestPhase { idle, findingServer, downloading, uploading, done, error }

class SpeedTestState {
  final SpeedTestPhase phase;
  final double downloadSpeed;   // Mbps
  final double uploadSpeed;     // Mbps
  final double progress;        // 0-100
  final String serverName;
  final String? error;
  final String? triggerReason;
  final bool visible;
  final DateTime? lastTestTime;

  const SpeedTestState({
    this.phase         = SpeedTestPhase.idle,
    this.downloadSpeed = 0,
    this.uploadSpeed   = 0,
    this.progress      = 0,
    this.serverName    = '',
    this.error,
    this.triggerReason,
    this.visible       = false,
    this.lastTestTime,
  });

  SpeedTestState copyWith({
    SpeedTestPhase? phase,
    double? downloadSpeed,
    double? uploadSpeed,
    double? progress,
    String? serverName,
    String? error,
    String? triggerReason,
    bool? visible,
    DateTime? lastTestTime,
  }) => SpeedTestState(
    phase:         phase         ?? this.phase,
    downloadSpeed: downloadSpeed ?? this.downloadSpeed,
    uploadSpeed:   uploadSpeed   ?? this.uploadSpeed,
    progress:      progress      ?? this.progress,
    serverName:    serverName    ?? this.serverName,
    error:         error         ?? this.error,
    triggerReason: triggerReason  ?? this.triggerReason,
    visible:       visible       ?? this.visible,
    lastTestTime:  lastTestTime  ?? this.lastTestTime,
  );
}

final speedTestControllerProvider =
NotifierProvider<SpeedTestController, SpeedTestState>(
    SpeedTestController.new);

class SpeedTestController extends Notifier<SpeedTestState> {
  final _speedTest = FlutterInternetSpeedTest();
  bool _running = false;

  /// Cooldown: không test lại trong 60 giây
  static const _cooldownSeconds = 60;

  @override
  SpeedTestState build() => const SpeedTestState();

  /// Trigger từ interceptor hoặc manual
  void triggerTest({String? reason}) {
    if (_running) return;

    // Cooldown check
    final last = state.lastTestTime;
    if (last != null &&
        DateTime.now().difference(last).inSeconds < _cooldownSeconds) {
      return;
    }

    _running = true;
    state = state.copyWith(
      visible: true,
      phase: SpeedTestPhase.findingServer,
      downloadSpeed: 0,
      uploadSpeed: 0,
      progress: 0,
      error: null,
      triggerReason: reason,
    );

    _speedTest.startTesting(
      useFastApi: true,

      onDefaultServerSelectionInProgress: () {
        state = state.copyWith(phase: SpeedTestPhase.findingServer);
      },

      onDefaultServerSelectionDone: (client) {
        String server = 'Unknown';
        if (client != null) {
          // Thử các field phổ biến — check IDE autocomplete cho chính xác
          try { server = client.isp ?? client.ip ?? client.toString(); }
          catch (_) { server = client.toString(); }
        }
        state = state.copyWith(serverName: server);
      },

      onStarted: () {
        state = state.copyWith(phase: SpeedTestPhase.downloading);
      },

      onProgress: (double percent, TestResult data) {
        if (state.phase == SpeedTestPhase.downloading ||
            state.phase == SpeedTestPhase.findingServer) {
          state = state.copyWith(
            phase: SpeedTestPhase.downloading,
            progress: percent,
            downloadSpeed: data.transferRate,
          );
        } else {
          state = state.copyWith(
            progress: percent,
            uploadSpeed: data.transferRate,
          );
        }
      },

      onDownloadComplete: (TestResult data) {
        state = state.copyWith(
          downloadSpeed: data.transferRate,
          phase: SpeedTestPhase.uploading,
          progress: 0,
        );
      },

      onUploadComplete: (TestResult data) {
        state = state.copyWith(uploadSpeed: data.transferRate);
      },

      onCompleted: (TestResult download, TestResult upload) {
        _running = false;
        state = state.copyWith(
          phase: SpeedTestPhase.done,
          downloadSpeed: download.transferRate,
          uploadSpeed: upload.transferRate,
          progress: 100,
          lastTestTime: DateTime.now(),
        );
        // Tự ẩn sau 15 giây
        Future.delayed(const Duration(seconds: 15), () {
          if (state.phase == SpeedTestPhase.done) {
            state = state.copyWith(visible: false, phase: SpeedTestPhase.idle);
          }
        });
      },

      onError: (String errorMessage, String speedTestError) {
        _running = false;
        state = state.copyWith(
          phase: SpeedTestPhase.error,
          error: errorMessage,
          lastTestTime: DateTime.now(),
        );
        Future.delayed(const Duration(seconds: 10), () {
          if (state.phase == SpeedTestPhase.error) {
            state = state.copyWith(visible: false, phase: SpeedTestPhase.idle);
          }
        });
      },

      onCancel: () {
        _running = false;
        state = state.copyWith(visible: false, phase: SpeedTestPhase.idle);
      },
    );
  }

  void dismiss() {
    state = state.copyWith(visible: false);
  }

  void cancel() {
    _speedTest.cancelTest();
    _running = false;
    state = state.copyWith(visible: false, phase: SpeedTestPhase.idle);
  }
}