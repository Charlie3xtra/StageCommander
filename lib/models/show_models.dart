import 'dart:convert';

/// Audio playback mode for a stage cue.
enum CueMode {
  /// Exclusive background music channel (only one BGM plays at a time).
  bgm,

  /// Retrigger singleton sound effect (restarts itself on repeat trigger;
  /// distinct SFX cues can overlap polyphonically).
  sfx,
}

/// Global user preferences persisted inside `project.json`.
class ShowSettings {
  const ShowSettings({
    this.duckRatio = 0.30,
    this.bgmCrossfadeMs = 200,
    this.darkMode = true,
    this.seedColorValue = 0xFF1A73E8,
    this.sidebarRatio = 0.27,
  });

  final double duckRatio;
  final int bgmCrossfadeMs;
  final bool darkMode;
  final int seedColorValue;
  final double sidebarRatio;

  ShowSettings copyWith({
    double? duckRatio,
    int? bgmCrossfadeMs,
    bool? darkMode,
    int? seedColorValue,
    double? sidebarRatio,
  }) {
    return ShowSettings(
      duckRatio: duckRatio ?? this.duckRatio,
      bgmCrossfadeMs: bgmCrossfadeMs ?? this.bgmCrossfadeMs,
      darkMode: darkMode ?? this.darkMode,
      seedColorValue: seedColorValue ?? this.seedColorValue,
      sidebarRatio: sidebarRatio ?? this.sidebarRatio,
    );
  }

  Map<String, dynamic> toJson() => {
        'duck_ratio': duckRatio,
        'bgm_crossfade_ms': bgmCrossfadeMs,
        'dark_mode': darkMode,
        'seed_color_value': seedColorValue,
        'sidebar_ratio': sidebarRatio,
      };

  factory ShowSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ShowSettings();
    return ShowSettings(
      duckRatio: ((json['duck_ratio'] as num?)?.toDouble() ?? 0.30)
          .clamp(0.05, 0.90),
      bgmCrossfadeMs:
          ((json['bgm_crossfade_ms'] as num?)?.toInt() ?? 200).clamp(0, 3000),
      darkMode: json['dark_mode'] as bool? ?? true,
      seedColorValue:
          (json['seed_color_value'] as num?)?.toInt() ?? 0xFF1A73E8,
      sidebarRatio: ((json['sidebar_ratio'] as num?)?.toDouble() ?? 0.27)
          .clamp(0.18, 0.45),
    );
  }
}

/// A single playable audio cue belonging to a [SceneAct].
class CueItem {
  const CueItem({
    required this.id,
    required this.name,
    required this.filePath,
    this.mode = CueMode.sfx,
    this.volume = 1.0,
    this.hotkeyCode = '',
    this.hotkeyLabel = '',
    this.loop = false,
    this.fadeOutMs = 120,
    this.notes = '',
  });

  final String id;
  final String name;

  /// Portable relative path (e.g. `Media/abc_intro.mp3`) or legacy absolute path.
  final String filePath;
  final CueMode mode;

  /// Normalized preset volume from `0.0` to `1.0`.
  final double volume;

  /// Canonical physical/logical hotkey identifier (e.g. `Digit1`, `KeyA`, `F1`).
  final String hotkeyCode;

  /// Human-readable keycap text (e.g. `1`, `A`, `F1`).
  final String hotkeyLabel;
  final bool loop;
  final int fadeOutMs;
  final String notes;

  int get volumePercent => (volume * 100).round().clamp(0, 100);

  bool get hasHotkey => hotkeyCode.isNotEmpty;

  CueItem copyWith({
    String? id,
    String? name,
    String? filePath,
    CueMode? mode,
    double? volume,
    String? hotkeyCode,
    String? hotkeyLabel,
    bool? loop,
    int? fadeOutMs,
    String? notes,
  }) {
    return CueItem(
      id: id ?? this.id,
      name: name ?? this.name,
      filePath: filePath ?? this.filePath,
      mode: mode ?? this.mode,
      volume: volume ?? this.volume,
      hotkeyCode: hotkeyCode ?? this.hotkeyCode,
      hotkeyLabel: hotkeyLabel ?? this.hotkeyLabel,
      loop: loop ?? this.loop,
      fadeOutMs: fadeOutMs ?? this.fadeOutMs,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'file_path': filePath.replaceAll('\\', '/'),
        'mode': mode.name,
        'volume': volume,
        'hotkey_code': hotkeyCode,
        'hotkey_label': hotkeyLabel,
        'loop': loop,
        'fade_out_ms': fadeOutMs,
        'notes': notes,
      };

  /// Parses both v2 cues and legacy StageCommander Beta 8 cue dictionaries.
  factory CueItem.fromJson(
    Map<String, dynamic> json, {
    required String fallbackId,
    required ({String code, String label}) Function(String raw) parseLegacyHotkey,
  }) {
    final rawMode = (json['mode'] as String? ?? 'sfx').toLowerCase();
    final mode = rawMode == 'bgm' ? CueMode.bgm : CueMode.sfx;

    // Beta 8 stored integer 0..100; v2 stores normalized 0.0..1.0.
    final rawVol = (json['volume'] as num?)?.toDouble() ?? 1.0;
    final normalizedVol =
        rawVol > 1.0 ? (rawVol / 100.0).clamp(0.0, 1.0) : rawVol.clamp(0.0, 1.0);

    var hkCode = (json['hotkey_code'] as String? ?? '').trim();
    var hkLabel = (json['hotkey_label'] as String? ?? '').trim();
    if (hkCode.isEmpty) {
      final legacyHk = (json['hotkey'] as String? ?? '').trim();
      if (legacyHk.isNotEmpty) {
        final parsed = parseLegacyHotkey(legacyHk);
        hkCode = parsed.code;
        hkLabel = parsed.label;
      }
    }

    return CueItem(
      id: (json['id'] as String?)?.trim().isNotEmpty == true
          ? json['id'] as String
          : fallbackId,
      name: (json['name'] as String? ?? '未命名音效').trim(),
      filePath: (json['file_path'] as String? ?? '').trim(),
      mode: mode,
      volume: normalizedVol,
      hotkeyCode: hkCode,
      hotkeyLabel: hkLabel.isEmpty ? hkCode : hkLabel,
      loop: json['loop'] as bool? ?? false,
      fadeOutMs: ((json['fade_out_ms'] as num?)?.toInt() ??
              (mode == CueMode.bgm ? 200 : 0))
          .clamp(0, 3000),
      notes: (json['notes'] as String? ?? '').trim(),
    );
  }
}

/// A stage act / scene containing an isolated set of cues and hotkeys.
class SceneAct {
  const SceneAct({
    required this.id,
    required this.name,
    this.cues = const [],
  });

  final String id;
  final String name;
  final List<CueItem> cues;

  /// Returns hotkey codes bound more than once within this scene.
  Set<String> duplicateHotkeyCodes() {
    final seen = <String>{};
    final duplicates = <String>{};
    for (final cue in cues) {
      if (cue.hotkeyCode.isEmpty) continue;
      if (!seen.add(cue.hotkeyCode)) {
        duplicates.add(cue.hotkeyCode);
      }
    }
    return duplicates;
  }

  SceneAct copyWith({
    String? id,
    String? name,
    List<CueItem>? cues,
  }) {
    return SceneAct(
      id: id ?? this.id,
      name: name ?? this.name,
      cues: cues ?? this.cues,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'scene_name': name,
        'cues': cues.map((c) => c.toJson()).toList(),
      };

  factory SceneAct.fromJson(
    Map<String, dynamic> json, {
    required String fallbackId,
    required String Function() nextCueId,
    required ({String code, String label}) Function(String raw) parseLegacyHotkey,
  }) {
    final rawCues = json['cues'] as List<dynamic>? ?? const [];
    final cues = <CueItem>[];
    for (final entry in rawCues) {
      if (entry is Map<String, dynamic>) {
        cues.add(
          CueItem.fromJson(
            entry,
            fallbackId: nextCueId(),
            parseLegacyHotkey: parseLegacyHotkey,
          ),
        );
      } else if (entry is Map) {
        cues.add(
          CueItem.fromJson(
            Map<String, dynamic>.from(entry),
            fallbackId: nextCueId(),
            parseLegacyHotkey: parseLegacyHotkey,
          ),
        );
      }
    }

    return SceneAct(
      id: (json['id'] as String?)?.trim().isNotEmpty == true
          ? json['id'] as String
          : fallbackId,
      name: (json['scene_name'] as String? ?? '未命名幕').trim(),
      cues: cues,
    );
  }
}

/// Top-level show project persisted in `project.json`.
class ShowProject {
  const ShowProject({
    this.version = 2,
    this.title = 'StageCommander Show',
    this.settings = const ShowSettings(),
    this.scenes = const [],
  });

  final int version;
  final String title;
  final ShowSettings settings;
  final List<SceneAct> scenes;

  ShowProject copyWith({
    int? version,
    String? title,
    ShowSettings? settings,
    List<SceneAct>? scenes,
  }) {
    return ShowProject(
      version: version ?? this.version,
      title: title ?? this.title,
      settings: settings ?? this.settings,
      scenes: scenes ?? this.scenes,
    );
  }

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  Map<String, dynamic> toJson() => {
        'version': version,
        'title': title,
        'updated_at': DateTime.now().toIso8601String(),
        'settings': settings.toJson(),
        'scenes': scenes.map((s) => s.toJson()).toList(),
      };

  /// Supports both v2 project objects and legacy Beta 8 top-level JSON lists.
  static ({ShowProject project, bool migratedFromLegacy}) fromDynamicJson(
    dynamic decoded, {
    required String Function() nextId,
    required ({String code, String label}) Function(String raw) parseLegacyHotkey,
  }) {
    List<dynamic> rawScenes = const [];
    var migrated = false;
    var title = 'StageCommander Show';
    var settings = const ShowSettings();

    if (decoded is List) {
      migrated = true;
      rawScenes = decoded;
    } else if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      title = (map['title'] as String?)?.trim().isNotEmpty == true
          ? (map['title'] as String).trim()
          : title;
      if (map['settings'] is Map) {
        settings = ShowSettings.fromJson(
          Map<String, dynamic>.from(map['settings'] as Map),
        );
      }
      rawScenes = map['scenes'] as List<dynamic>? ?? const [];
      if ((map['version'] as num?)?.toInt() != 2) {
        migrated = true;
      }
    }

    final scenes = <SceneAct>[];
    for (final rawScene in rawScenes) {
      if (rawScene is Map) {
        scenes.add(
          SceneAct.fromJson(
            Map<String, dynamic>.from(rawScene),
            fallbackId: nextId(),
            nextCueId: nextId,
            parseLegacyHotkey: parseLegacyHotkey,
          ),
        );
      }
    }

    if (scenes.isEmpty) {
      scenes.add(SceneAct(id: nextId(), name: '第一幕'));
    }

    return (
      project: ShowProject(
        version: 2,
        title: title,
        settings: settings,
        scenes: scenes,
      ),
      migratedFromLegacy: migrated,
    );
  }
}
