import 'package:material_ui/material_ui.dart';

/// Preset Material Design 3 seed colors offered in the Studio theme switcher.
class StageSeedPreset {
  const StageSeedPreset(this.name, this.color);

  final String name;
  final Color color;

  static const List<StageSeedPreset> presets = [
    StageSeedPreset('Google Blue', Color(0xFF1A73E8)),
    StageSeedPreset('Material Violet', Color(0xFF6750A4)),
    StageSeedPreset('Stage Teal', Color(0xFF006A6A)),
    StageSeedPreset('Theater Crimson', Color(0xFFA83246)),
  ];
}

/// Strictly harmonized Material 3 semantic color roles for live show cues.
@immutable
class StageSemanticColors extends ThemeExtension<StageSemanticColors> {
  const StageSemanticColors({
    required this.armedContainer,
    required this.onArmedContainer,
    required this.armedAccent,
    required this.duckingContainer,
    required this.onDuckingContainer,
    required this.duckingAccent,
    required this.bgmContainer,
    required this.onBgmContainer,
    required this.sfxContainer,
    required this.onSfxContainer,
    required this.waveformTrack,
    required this.waveformPlayed,
    required this.waveformUnplayed,
    required this.waveformPlayhead,
  });

  final Color armedContainer;
  final Color onArmedContainer;
  final Color armedAccent;
  final Color duckingContainer;
  final Color onDuckingContainer;
  final Color duckingAccent;
  final Color bgmContainer;
  final Color onBgmContainer;
  final Color sfxContainer;
  final Color onSfxContainer;
  final Color waveformTrack;
  final Color waveformPlayed;
  final Color waveformUnplayed;
  final Color waveformPlayhead;

  factory StageSemanticColors.fromScheme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    return StageSemanticColors(
      armedContainer:
          isDark ? const Color(0xFF0D3822) : const Color(0xFFD2F5DE),
      onArmedContainer:
          isDark ? const Color(0xFF8BE2AD) : const Color(0xFF064023),
      armedAccent: isDark ? const Color(0xFF5DD890) : const Color(0xFF146C3B),
      duckingContainer:
          isDark ? const Color(0xFF473100) : const Color(0xFFFFE5B0),
      onDuckingContainer:
          isDark ? const Color(0xFFFFD178) : const Color(0xFF452B00),
      duckingAccent:
          isDark ? const Color(0xFFFFB74D) : const Color(0xFF8F5400),
      bgmContainer: scheme.primaryContainer,
      onBgmContainer: scheme.onPrimaryContainer,
      sfxContainer: scheme.secondaryContainer,
      onSfxContainer: scheme.onSecondaryContainer,
      waveformTrack: scheme.surfaceContainerHighest,
      waveformPlayed: scheme.primary,
      waveformUnplayed: scheme.onSurfaceVariant.withValues(alpha: 0.28),
      waveformPlayhead: scheme.tertiary,
    );
  }

  @override
  StageSemanticColors copyWith({
    Color? armedContainer,
    Color? onArmedContainer,
    Color? armedAccent,
    Color? duckingContainer,
    Color? onDuckingContainer,
    Color? duckingAccent,
    Color? bgmContainer,
    Color? onBgmContainer,
    Color? sfxContainer,
    Color? onSfxContainer,
    Color? waveformTrack,
    Color? waveformPlayed,
    Color? waveformUnplayed,
    Color? waveformPlayhead,
  }) {
    return StageSemanticColors(
      armedContainer: armedContainer ?? this.armedContainer,
      onArmedContainer: onArmedContainer ?? this.onArmedContainer,
      armedAccent: armedAccent ?? this.armedAccent,
      duckingContainer: duckingContainer ?? this.duckingContainer,
      onDuckingContainer: onDuckingContainer ?? this.onDuckingContainer,
      duckingAccent: duckingAccent ?? this.duckingAccent,
      bgmContainer: bgmContainer ?? this.bgmContainer,
      onBgmContainer: onBgmContainer ?? this.onBgmContainer,
      sfxContainer: sfxContainer ?? this.sfxContainer,
      onSfxContainer: onSfxContainer ?? this.onSfxContainer,
      waveformTrack: waveformTrack ?? this.waveformTrack,
      waveformPlayed: waveformPlayed ?? this.waveformPlayed,
      waveformUnplayed: waveformUnplayed ?? this.waveformUnplayed,
      waveformPlayhead: waveformPlayhead ?? this.waveformPlayhead,
    );
  }

  @override
  StageSemanticColors lerp(ThemeExtension<StageSemanticColors>? other, double t) {
    if (other is! StageSemanticColors) return this;
    return StageSemanticColors(
      armedContainer: Color.lerp(armedContainer, other.armedContainer, t)!,
      onArmedContainer:
          Color.lerp(onArmedContainer, other.onArmedContainer, t)!,
      armedAccent: Color.lerp(armedAccent, other.armedAccent, t)!,
      duckingContainer:
          Color.lerp(duckingContainer, other.duckingContainer, t)!,
      onDuckingContainer:
          Color.lerp(onDuckingContainer, other.onDuckingContainer, t)!,
      duckingAccent: Color.lerp(duckingAccent, other.duckingAccent, t)!,
      bgmContainer: Color.lerp(bgmContainer, other.bgmContainer, t)!,
      onBgmContainer: Color.lerp(onBgmContainer, other.onBgmContainer, t)!,
      sfxContainer: Color.lerp(sfxContainer, other.sfxContainer, t)!,
      onSfxContainer: Color.lerp(onSfxContainer, other.onSfxContainer, t)!,
      waveformTrack: Color.lerp(waveformTrack, other.waveformTrack, t)!,
      waveformPlayed: Color.lerp(waveformPlayed, other.waveformPlayed, t)!,
      waveformUnplayed:
          Color.lerp(waveformUnplayed, other.waveformUnplayed, t)!,
      waveformPlayhead:
          Color.lerp(waveformPlayhead, other.waveformPlayhead, t)!,
    );
  }
}

/// Builds a strict Material Design 3 theme across light and dark theater modes.
ThemeData buildStageMd3Theme({
  required Brightness brightness,
  required Color seedColor,
}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );
  final semantics = StageSemanticColors.fromScheme(scheme);

  const fontFallback = [
    'Segoe UI',
    'Microsoft YaHei UI',
    'PingFang SC',
    'Noto Sans CJK SC',
    'Noto Sans',
    'Roboto',
    'sans-serif',
  ];

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    fontFamilyFallback: fontFallback,
    visualDensity: VisualDensity.standard,
  );

  final textTheme = base.textTheme.apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
    fontFamilyFallback: fontFallback,
  );

  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: scheme.surface,
    extensions: [semantics],
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    dialogTheme: DialogThemeData(
      elevation: 6,
      backgroundColor: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outline),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      inactiveTrackColor: scheme.surfaceContainerHighest,
      thumbColor: scheme.primary,
      overlayColor: scheme.primary.withValues(alpha: 0.12),
      trackHeight: 4,
      showValueIndicator: ShowValueIndicator.onlyForDiscrete,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: textTheme.labelMedium?.copyWith(color: scheme.onInverseSurface),
      waitDuration: const Duration(milliseconds: 350),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: scheme.inverseSurface,
      contentTextStyle:
          textTheme.bodyMedium?.copyWith(color: scheme.onInverseSurface),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
  );
}
