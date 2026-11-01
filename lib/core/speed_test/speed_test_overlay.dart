// lib/core/speed_test/speed_test_overlay.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'speed_test_controller.dart';

class SpeedTestOverlay extends ConsumerWidget {
  final Widget child;
  const SpeedTestOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(speedTestControllerProvider);

    return Stack(
      children: [
        child,
        if (st.visible)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: _SpeedTestCard(state: st, ref: ref),
          ),
      ],
    );
  }
}

class _SpeedTestCard extends StatelessWidget {
  final SpeedTestState state;
  final WidgetRef ref;

  const _SpeedTestCard({required this.state, required this.ref});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(children: [
              Icon(_phaseIcon, size: 14, color: _phaseColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_phaseLabel,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: _phaseColor)),
              ),
              GestureDetector(
                onTap: () => ref
                    .read(speedTestControllerProvider.notifier)
                    .cancel(),
                child: Icon(Icons.close_rounded, size: 14,
                    color: Colors.grey.withOpacity(0.6)),
              ),
            ]),

            if (state.serverName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Server: ${state.serverName}',
                  style: TextStyle(fontSize: 9,
                      color: Colors.grey.withOpacity(0.7)),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],

            const SizedBox(height: 8),

            // Download
            _SpeedRow(
              icon: Icons.download_rounded,
              label: 'Download',
              speed: state.downloadSpeed,
              color: const Color(0xFF2563EB),
              active: state.phase == SpeedTestPhase.downloading,
              progress: state.phase == SpeedTestPhase.downloading
                  ? state.progress : null,
            ),

            const SizedBox(height: 6),

            // Upload
            _SpeedRow(
              icon: Icons.upload_rounded,
              label: 'Upload',
              speed: state.uploadSpeed,
              color: const Color(0xFF059669),
              active: state.phase == SpeedTestPhase.uploading,
              progress: state.phase == SpeedTestPhase.uploading
                  ? state.progress : null,
            ),

            if (state.error != null) ...[
              const SizedBox(height: 6),
              Text(state.error!,
                  style: const TextStyle(fontSize: 9, color: Colors.red),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }

  IconData get _phaseIcon => switch (state.phase) {
    SpeedTestPhase.findingServer => Icons.dns_rounded,
    SpeedTestPhase.downloading   => Icons.download_rounded,
    SpeedTestPhase.uploading     => Icons.upload_rounded,
    SpeedTestPhase.done          => Icons.check_circle_rounded,
    SpeedTestPhase.error         => Icons.error_outline_rounded,
    _                            => Icons.speed_rounded,
  };

  Color get _phaseColor => switch (state.phase) {
    SpeedTestPhase.findingServer => Colors.orange,
    SpeedTestPhase.downloading   => const Color(0xFF2563EB),
    SpeedTestPhase.uploading     => const Color(0xFF059669),
    SpeedTestPhase.done          => const Color(0xFF059669),
    SpeedTestPhase.error         => Colors.red,
    _                            => Colors.grey,
  };

  String get _phaseLabel => switch (state.phase) {
    SpeedTestPhase.findingServer => 'Đang tìm server...',
    SpeedTestPhase.downloading   => 'Đang đo download...',
    SpeedTestPhase.uploading     => 'Đang đo upload...',
    SpeedTestPhase.done          => 'Hoàn tất',
    SpeedTestPhase.error         => 'Lỗi',
    _                            => 'Speed Test',
  };
}

class _SpeedRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double speed;
  final Color color;
  final bool active;
  final double? progress;

  const _SpeedRow({
    required this.icon, required this.label, required this.speed,
    required this.color, this.active = false, this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 10,
                  color: isDark ? Colors.white70 : Colors.black54)),
          const Spacer(),
          Text(
            speed > 0 ? '${speed.toStringAsFixed(1)} Mbps' : '—',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active ? color : (isDark ? Colors.white : Colors.black87),
            ),
          ),
        ]),
        if (progress != null) ...[
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress! / 100,
              minHeight: 3,
              backgroundColor: color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ],
    );
  }
}