import 'package:material_ui/material_ui.dart';

import '../../app/theme/md3_theme.dart';

/// Interactive Material Design 3 symmetrical amplitude waveform & timeline scrubber.
///
/// Renders native SoLoud multi-format waveform envelopes (WAV, MP3, OGG, FLAC, Opus)
/// and gracefully degrades to a sleek M3 progress bar when no peaks are available.
class WaveformScrubber extends StatefulWidget {
  const WaveformScrubber({
    super.key,
    required this.peaks,
    required this.position,
    required this.duration,
    required this.hasTrack,
    required this.isLoading,
    required this.onSeek,
  });

  final List<double> peaks;
  final Duration position;
  final Duration duration;
  final bool hasTrack;
  final bool isLoading;
  final ValueChanged<Duration> onSeek;

  @override
  State<WaveformScrubber> createState() => _WaveformScrubberState();
}

class _WaveformScrubberState extends State<WaveformScrubber> {
  double? _dragRatio;
  double? _hoverRatio;

  double get _currentRatio {
    if (_dragRatio != null) return _dragRatio!.clamp(0.0, 1.0);
    final totalMs = widget.duration.inMilliseconds;
    if (totalMs <= 0) return 0.0;
    return (widget.position.inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  double _ratioForDx(double dx, double width) {
    if (width <= 0) return 0.0;
    return (dx / width).clamp(0.0, 1.0);
  }

  String _formatDuration(Duration d) {
    final totalSeconds = d.inSeconds.clamp(0, 359999);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantics = theme.extension<StageSemanticColors>()!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final ratio = _currentRatio;
        final hoverRatio = _hoverRatio;
        final hoverTime = hoverRatio != null && widget.duration > Duration.zero
            ? Duration(
                milliseconds:
                    (widget.duration.inMilliseconds * hoverRatio).round(),
              )
            : null;

        return MouseRegion(
          cursor: widget.hasTrack
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onHover: widget.hasTrack
              ? (event) => setState(
                    () => _hoverRatio = _ratioForDx(event.localPosition.dx, width),
                  )
              : null,
          onExit: (_) => setState(() => _hoverRatio = null),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: widget.hasTrack
                ? (details) {
                    final r = _ratioForDx(details.localPosition.dx, width);
                    final target = Duration(
                      milliseconds:
                          (widget.duration.inMilliseconds * r).round(),
                    );
                    widget.onSeek(target);
                  }
                : null,
            onHorizontalDragStart: widget.hasTrack
                ? (details) => setState(
                      () => _dragRatio = _ratioForDx(details.localPosition.dx, width),
                    )
                : null,
            onHorizontalDragUpdate: widget.hasTrack
                ? (details) => setState(
                      () => _dragRatio = _ratioForDx(details.localPosition.dx, width),
                    )
                : null,
            onHorizontalDragEnd: widget.hasTrack
                ? (_) {
                    final r = _dragRatio;
                    setState(() => _dragRatio = null);
                    if (r != null && widget.duration > Duration.zero) {
                      widget.onSeek(
                        Duration(
                          milliseconds:
                              (widget.duration.inMilliseconds * r).round(),
                        ),
                      );
                    }
                  }
                : null,
            child: Container(
              height: 62,
              decoration: BoxDecoration(
                color: semantics.waveformTrack,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _WaveformPainter(
                      peaks: widget.peaks,
                      progress: ratio,
                      hoverProgress: hoverRatio,
                      hasTrack: widget.hasTrack,
                      playedColor: semantics.waveformPlayed,
                      unplayedColor: semantics.waveformUnplayed,
                      playheadColor: semantics.waveformPlayhead,
                      hoverLineColor: scheme.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
                  if (!widget.hasTrack)
                    Center(
                      child: Text(
                        '待命 · 触发任意 BGM 后自动绘制全格式音频波形',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else if (widget.isLoading)
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ),
                  if (hoverTime != null && hoverRatio != null)
                    Positioned(
                      left: (hoverRatio * width - 22).clamp(4.0, width - 48.0),
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.inverseSurface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _formatDuration(hoverTime),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onInverseSurface,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.peaks,
    required this.progress,
    required this.hoverProgress,
    required this.hasTrack,
    required this.playedColor,
    required this.unplayedColor,
    required this.playheadColor,
    required this.hoverLineColor,
  });

  final List<double> peaks;
  final double progress;
  final double? hoverProgress;
  final bool hasTrack;
  final Color playedColor;
  final Color unplayedColor;
  final Color playheadColor;
  final Color hoverLineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (!hasTrack) return;

    final centerY = size.height / 2;
    final horizontalPad = 10.0;
    final drawWidth = (size.width - horizontalPad * 2).clamp(1.0, size.width);

    if (peaks.isEmpty) {
      // Sleek fallback linear track when peaks are loading or unavailable.
      final trackPaint = Paint()
        ..color = unplayedColor
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 4;
      canvas.drawLine(
        Offset(horizontalPad, centerY),
        Offset(horizontalPad + drawWidth, centerY),
        trackPaint,
      );
      final activePaint = Paint()
        ..color = playedColor
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 4;
      canvas.drawLine(
        Offset(horizontalPad, centerY),
        Offset(horizontalPad + drawWidth * progress, centerY),
        activePaint,
      );
    } else {
      final count = peaks.length;
      final slotWidth = drawWidth / count;
      final barWidth = (slotWidth * 0.64).clamp(1.5, 4.5);
      final maxHalfH = (size.height * 0.42).clamp(4.0, size.height / 2);

      final playedPaint = Paint()..color = playedColor;
      final unplayedPaint = Paint()..color = unplayedColor;

      for (var i = 0; i < count; i++) {
        final x = horizontalPad + i * slotWidth + slotWidth / 2;
        final barRatio = (i + 0.5) / count;
        final amp = peaks[i].clamp(0.05, 1.0);
        final halfH = (amp * maxHalfH).clamp(2.0, maxHalfH);
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, centerY),
            width: barWidth,
            height: halfH * 2,
          ),
          const Radius.circular(2),
        );
        canvas.drawRRect(
          rect,
          barRatio <= progress ? playedPaint : unplayedPaint,
        );
      }
    }

    if (hoverProgress != null) {
      final hx = horizontalPad + drawWidth * hoverProgress!;
      canvas.drawLine(
        Offset(hx, 4),
        Offset(hx, size.height - 4),
        Paint()
          ..color = hoverLineColor
          ..strokeWidth = 1.2,
      );
    }

    final px = horizontalPad + drawWidth * progress;
    canvas.drawLine(
      Offset(px, 2),
      Offset(px, size.height - 2),
      Paint()
        ..color = playheadColor
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.peaks != peaks ||
        oldDelegate.progress != progress ||
        oldDelegate.hoverProgress != hoverProgress ||
        oldDelegate.hasTrack != hasTrack ||
        oldDelegate.playedColor != playedColor ||
        oldDelegate.unplayedColor != unplayedColor;
  }
}
