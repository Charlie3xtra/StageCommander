import 'package:material_ui/material_ui.dart';

import '../../app/theme/md3_theme.dart';
import '../../controllers/stage_controller.dart';
import 'waveform_scrubber.dart';

/// Persistent Material Design 3 bottom BGM deck with interactive waveform scrubber,
/// transport buttons, loop toggle, independent fader, and smooth 30% ducking.
class BgmControlDeck extends StatelessWidget {
  const BgmControlDeck({super.key, required this.controller});

  final StageController controller;

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
    final bgm = controller.bgmState;
    final duckPercent = (controller.settings.duckRatio * 100).round();

    return Card(
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Left: Title + Loop Chip + Timecode + Interactive Waveform
            Expanded(
              flex: 13,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: semantics.bgmContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'BGM 独占总线',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: semantics.onBgmContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          bgm.hasTrack ? bgm.title : '等待播放背景音乐...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: bgm.hasTrack
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        selected: bgm.isLooping,
                        onSelected: bgm.hasTrack
                            ? (_) {
                                FocusManager.instance.primaryFocus?.unfocus();
                                controller.toggleBgmLoop();
                              }
                            : null,
                        avatar: const Icon(Icons.repeat_rounded, size: 16),
                        label: const Text('循环'),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${_formatDuration(bgm.position)} / ${_formatDuration(bgm.duration)}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  WaveformScrubber(
                    peaks: controller.activeWaveformPeaks,
                    position: bgm.position,
                    duration: bgm.duration,
                    hasTrack: bgm.hasTrack,
                    isLoading: controller.isLoadingWaveform,
                    onSeek: controller.seekBgm,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),
            SizedBox(
              height: 92,
              child: VerticalDivider(
                width: 1,
                thickness: 1,
                color: scheme.outlineVariant,
              ),
            ),
            const SizedBox(width: 16),

            // Right: Transport + Volume Fader + Ducking Toggle
            Expanded(
              flex: 7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton.filledTonal(
                        tooltip: bgm.isPlaying ? '暂停 BGM' : '继续播放 BGM',
                        visualDensity: VisualDensity.compact,
                        onPressed: bgm.hasTrack
                            ? () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                controller.toggleBgmPlayPause();
                              }
                            : null,
                        icon: Icon(
                          bgm.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton.outlined(
                        tooltip: '淡出停止 BGM',
                        visualDensity: VisualDensity.compact,
                        onPressed: bgm.hasTrack
                            ? () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                controller.stopActiveBgm();
                              }
                            : null,
                        icon: const Icon(Icons.stop_rounded),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '音量 ${(bgm.volume * 100).round()}%',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: bgm.volume.clamp(0.0, 1.0),
                    onChanged: (val) => controller.setBgmVolume(val),
                    onChangeEnd: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      controller.toggleDucking();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: bgm.isDucking
                          ? semantics.duckingContainer
                          : scheme.secondaryContainer,
                      foregroundColor: bgm.isDucking
                          ? semantics.onDuckingContainer
                          : scheme.onSecondaryContainer,
                      minimumSize: const Size.fromHeight(38),
                    ),
                    icon: Icon(
                      bgm.isDucking
                          ? Icons.record_voice_over_rounded
                          : Icons.spatial_audio_off_rounded,
                      size: 18,
                    ),
                    label: Text(
                      bgm.isDucking
                          ? '恢复音量 (闪避中 $duckPercent%)'
                          : '台词闪避 (降至 $duckPercent%)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
