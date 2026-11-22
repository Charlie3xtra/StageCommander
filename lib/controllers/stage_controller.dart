import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../models/show_models.dart';
import '../services/audio_engine.dart';
import '../services/hotkey_mapper.dart';
import '../services/project_storage.dart';

/// Supported audio extensions for file pickers and drag-and-drop imports.
const List<String> kSupportedAudioExtensions = [
  'mp3',
  'wav',
  'ogg',
  'flac',
  'opus',
  'm4a',
  'aac',
];

/// Primary MVC/ChangeNotifier controller coordinating project persistence,
/// safety locking (`Armed` / `Disarmed`), scene management, and audio playback.
class StageController extends ChangeNotifier {
  StageController({
    required this._storage,
    required this._audio,
  }) {
    _audio.bgmState.addListener(_onAudioChanged);
    _audio.playingCueIds.addListener(_onAudioChanged);
  }

  final ProjectStorage _storage;
  final StageAudioEngine _audio;

  ShowProject _project = const ShowProject();
  int _activeSceneIndex = 0;
  bool _systemArmed = false;
  String _searchQuery = '';
  String _statusMessage = '⛔ 系统已锁定 · 按 Space 或点击 GO 激活热键';
  int _modalOpenCount = 0;
  List<double> _activeWaveformPeaks = const [];
  String _waveformForPath = '';
  bool _isLoadingWaveform = false;

  ShowProject get project => _project;
  ShowSettings get settings => _project.settings;
  List<SceneAct> get scenes => _project.scenes;
  int get activeSceneIndex =>
      _project.scenes.isEmpty ? 0 : _activeSceneIndex.clamp(0, _project.scenes.length - 1);
  SceneAct? get activeScene =>
      _project.scenes.isEmpty ? null : _project.scenes[activeSceneIndex];

  bool get systemArmed => _systemArmed;
  String get searchQuery => _searchQuery;
  String get statusMessage => _statusMessage;
  bool get isAudioReady => _audio.isReady;
  String? get audioInitError => _audio.initError;
  String get workspacePath => _storage.workspaceDir.path;

  BgmPlaybackState get bgmState => _audio.bgmState.value;
  Set<String> get playingCueIds => _audio.playingCueIds.value;
  List<double> get activeWaveformPeaks => _activeWaveformPeaks;
  bool get isLoadingWaveform => _isLoadingWaveform;

  Future<void> initialize() async {
    await _storage.initialize();
    _project = await _storage.loadProject();
    _activeSceneIndex = 0;
    await _audio.initialize();
    if (_audio.initError != null) {
      _statusMessage = '⚠ 音频设备初始化失败: ${_audio.initError}';
    }
    notifyListeners();
  }

  void _onAudioChanged() {
    final trackPath = _audio.bgmState.value.filePath;
    if (trackPath.isEmpty && _waveformForPath.isNotEmpty) {
      _waveformForPath = '';
      _activeWaveformPeaks = const [];
    } else if (trackPath.isNotEmpty && trackPath != _waveformForPath) {
      _loadWaveformForTrack(trackPath);
    }
    notifyListeners();
  }

  Future<void> _loadWaveformForTrack(String resolvedPath) async {
    _waveformForPath = resolvedPath;
    _isLoadingWaveform = true;
    _activeWaveformPeaks = const [];
    notifyListeners();

    final peaks = await _audio.extractWaveformPeaks(resolvedPath, bins: 160);
    if (_waveformForPath == resolvedPath) {
      _activeWaveformPeaks = peaks;
      _isLoadingWaveform = false;
      notifyListeners();
    }
  }

  void pushModalGuard() {
    _modalOpenCount++;
  }

  void popModalGuard() {
    if (_modalOpenCount > 0) _modalOpenCount--;
  }

  // --------------------------------------------------------------------------
  // Safety & Global Keyboard Dispatch
  // --------------------------------------------------------------------------

  void armSystem() {
    if (_systemArmed) return;
    _systemArmed = true;
    _statusMessage = '✅ 系统已激活 (ARMED) · 当前幕键盘热键已上线';
    notifyListeners();
  }

  /// Disarms keyboard triggers cleanly without cutting live BGM/SFX.
  void disarmSystemSafely() {
    if (!_systemArmed) return;
    _systemArmed = false;
    _statusMessage = '🔒 已安全上锁 · 热键已禁用 (音频继续播放)';
    notifyListeners();
  }

  /// Emergency stop: kills all audio instantly and locks the firing switch.
  Future<void> panicStopAll() async {
    await _audio.panicStopAll();
    _systemArmed = false;
    _statusMessage = '⛔ 紧急全部停止 (PANIC) · 系统已强制锁定';
    notifyListeners();
  }

  /// Handles top-level hardware key events without widget focus stealing.
  bool handleGlobalKeyEvent(KeyEvent event, {required bool hasEditableFocus}) {
    if (event is! KeyDownEvent) return false;
    if (_modalOpenCount > 0 || hasEditableFocus) return false;

    if (event.physicalKey == PhysicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.escape) {
      panicStopAll();
      return true;
    }

    if (event.physicalKey == PhysicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.space) {
      if (!_systemArmed) {
        armSystem();
      }
      return true;
    }

    if (!_systemArmed) return false;

    final scene = activeScene;
    if (scene == null) return false;

    for (final cue in scene.cues) {
      if (cue.hotkeyCode.isNotEmpty &&
          HotkeyMapper.matchesEvent(cue.hotkeyCode, event)) {
        triggerCue(cue, bypassArmCheck: true);
        return true;
      }
    }
    return false;
  }

  // --------------------------------------------------------------------------
  // Playback Controls
  // --------------------------------------------------------------------------

  Future<bool> triggerCue(CueItem cue, {bool bypassArmCheck = false}) async {
    if (!_systemArmed && !bypassArmCheck) return false;
    final resolved = _storage.resolveCuePath(cue);
    if (resolved.isEmpty || !File(resolved).existsSync()) {
      _statusMessage = '⚠ 找不到音频文件: ${cue.name}';
      notifyListeners();
      return false;
    }

    final ok = await _audio.playCue(
      cue,
      resolved,
      bgmCrossfadeMs: settings.bgmCrossfadeMs,
      duckRatio: settings.duckRatio,
    );
    if (ok) {
      _statusMessage = bypassArmCheck && !_systemArmed
          ? '🎧 试听: ${cue.name}'
          : '🔊 触发播放: ${cue.name}';
      notifyListeners();
    }
    return ok;
  }

  Future<void> stopCue(CueItem cue) async {
    await _audio.stopCue(cue.id, fadeOutMs: cue.fadeOutMs);
    _statusMessage = '⏹ 已停止: ${cue.name}';
    notifyListeners();
  }

  Future<void> toggleBgmPlayPause() async {
    if (bgmState.isPlaying) {
      await _audio.pauseBgm();
    } else if (bgmState.isPaused) {
      await _audio.resumeBgm();
    }
  }

  Future<void> stopActiveBgm() async {
    final cueId = bgmState.cueId;
    if (cueId != null) {
      await _audio.stopCue(cueId, fadeOutMs: settings.bgmCrossfadeMs);
    }
  }

  Future<void> seekBgm(Duration target) => _audio.seekBgm(target);

  void setBgmVolume(double vol) {
    _audio.setBgmVolume(vol, duckRatio: settings.duckRatio);
  }

  void toggleDucking() {
    _audio.setDucking(!bgmState.isDucking, duckRatio: settings.duckRatio);
  }

  void toggleBgmLoop() {
    _audio.setBgmLoop(!bgmState.isLooping);
  }

  // --------------------------------------------------------------------------
  // Scene Management
  // --------------------------------------------------------------------------

  void selectScene(int index) {
    if (index < 0 || index >= _project.scenes.length) return;
    _activeSceneIndex = index;
    _searchQuery = '';
    notifyListeners();
  }

  Future<void> addScene(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final updated = [
      ..._project.scenes,
      SceneAct(id: _storage.nextId('scene'), name: trimmed),
    ];
    _project = _project.copyWith(scenes: updated);
    _activeSceneIndex = updated.length - 1;
    await _save();
    notifyListeners();
  }

  Future<void> renameScene(int index, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || index < 0 || index >= _project.scenes.length) return;
    final updated = [..._project.scenes];
    updated[index] = updated[index].copyWith(name: trimmed);
    _project = _project.copyWith(scenes: updated);
    await _save();
    notifyListeners();
  }

  Future<void> duplicateScene(int index) async {
    if (index < 0 || index >= _project.scenes.length) return;
    final source = _project.scenes[index];
    final clonedCues = source.cues
        .map((c) => c.copyWith(id: _storage.nextId('cue')))
        .toList();
    final copy = SceneAct(
      id: _storage.nextId('scene'),
      name: '${source.name} (副本)',
      cues: clonedCues,
    );
    final updated = [..._project.scenes]..insert(index + 1, copy);
    _project = _project.copyWith(scenes: updated);
    _activeSceneIndex = index + 1;
    await _save();
    notifyListeners();
  }

  Future<void> moveScene(int oldIndex, int newIndex) async {
    if (oldIndex < 0 ||
        oldIndex >= _project.scenes.length ||
        newIndex < 0 ||
        newIndex >= _project.scenes.length ||
        oldIndex == newIndex) {
      return;
    }
    final activeId = activeScene?.id;
    final updated = [..._project.scenes];
    final moved = updated.removeAt(oldIndex);
    updated.insert(newIndex, moved);
    _project = _project.copyWith(scenes: updated);
    if (activeId != null) {
      _activeSceneIndex = updated.indexWhere((s) => s.id == activeId);
    }
    await _save();
    notifyListeners();
  }

  Future<bool> deleteScene(int index) async {
    if (_project.scenes.length <= 1 ||
        index < 0 ||
        index >= _project.scenes.length) {
      return false;
    }
    final scene = _project.scenes[index];
    for (final cue in scene.cues) {
      if (playingCueIds.contains(cue.id)) {
        await _audio.stopCue(cue.id);
      }
    }
    final updated = [..._project.scenes]..removeAt(index);
    _project = _project.copyWith(scenes: updated);
    _activeSceneIndex = activeSceneIndex.clamp(0, updated.length - 1);
    await _save();
    notifyListeners();
    return true;
  }

  // --------------------------------------------------------------------------
  // Cue Management & Drag-Drop Import
  // --------------------------------------------------------------------------

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<CueItem> filteredCues() {
    final scene = activeScene;
    if (scene == null) return const [];
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return scene.cues;
    return scene.cues.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.hotkeyLabel.toLowerCase().contains(q) ||
          c.notes.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> addCue(CueItem draft) async {
    final scene = activeScene;
    if (scene == null) return;

    final importedPath = await _importIfNeeded(draft.filePath);
    final cue = draft.copyWith(
      id: draft.id.isEmpty ? _storage.nextId('cue') : draft.id,
      filePath: importedPath,
    );
    await _replaceActiveSceneCues([...scene.cues, cue]);
    _statusMessage = '已添加音效: ${cue.name}';
    notifyListeners();
  }

  /// Imports multiple audio files (e.g. via drag-and-drop) into the active scene.
  Future<int> importAudioFilesAsCues(List<String> filePaths) async {
    final scene = activeScene;
    if (scene == null) return 0;

    final added = <CueItem>[];
    for (final rawPath in filePaths) {
      final ext = p.extension(rawPath).replaceFirst('.', '').toLowerCase();
      if (!kSupportedAudioExtensions.contains(ext)) continue;
      if (!File(rawPath).existsSync()) continue;

      final portablePath = await _storage.importAudioFile(rawPath);
      added.add(
        CueItem(
          id: _storage.nextId('cue'),
          name: p.basenameWithoutExtension(rawPath),
          filePath: portablePath,
          mode: CueMode.sfx,
        ),
      );
    }
    if (added.isEmpty) return 0;

    await _replaceActiveSceneCues([...scene.cues, ...added]);
    _statusMessage = '已批量导入 ${added.length} 个音频到 ${scene.name}';
    notifyListeners();
    return added.length;
  }

  Future<void> updateCue(CueItem updatedCue) async {
    final scene = activeScene;
    if (scene == null) return;

    final idx = scene.cues.indexWhere((c) => c.id == updatedCue.id);
    if (idx == -1) return;

    final existing = scene.cues[idx];
    final newPath = existing.filePath == updatedCue.filePath
        ? updatedCue.filePath
        : await _importIfNeeded(updatedCue.filePath);

    final nextCues = [...scene.cues];
    nextCues[idx] = updatedCue.copyWith(filePath: newPath);
    await _replaceActiveSceneCues(nextCues);
    _statusMessage = '已更新音效: ${updatedCue.name}';
    notifyListeners();
  }

  Future<void> duplicateCue(CueItem cue) async {
    final scene = activeScene;
    if (scene == null) return;
    final idx = scene.cues.indexWhere((c) => c.id == cue.id);
    final copy = cue.copyWith(
      id: _storage.nextId('cue'),
      name: '${cue.name} (副本)',
      hotkeyCode: '',
      hotkeyLabel: '',
    );
    final nextCues = [...scene.cues];
    nextCues.insert(idx >= 0 ? idx + 1 : nextCues.length, copy);
    await _replaceActiveSceneCues(nextCues);
    notifyListeners();
  }

  Future<void> reorderCue(int oldIndex, int newIndex) async {
    final scene = activeScene;
    if (scene == null || _searchQuery.trim().isNotEmpty) return;
    final nextCues = [...scene.cues];
    if (oldIndex < 0 ||
        oldIndex >= nextCues.length ||
        newIndex < 0 ||
        newIndex >= nextCues.length ||
        oldIndex == newIndex) {
      return;
    }
    final item = nextCues.removeAt(oldIndex);
    nextCues.insert(newIndex, item);
    await _replaceActiveSceneCues(nextCues);
    notifyListeners();
  }

  Future<void> deleteCue(CueItem cue) async {
    final scene = activeScene;
    if (scene == null) return;
    await _audio.stopCue(cue.id);
    final nextCues = scene.cues.where((c) => c.id != cue.id).toList();
    await _replaceActiveSceneCues(nextCues);
    _statusMessage = '已删除音效: ${cue.name}';
    notifyListeners();
  }

  Future<String> _importIfNeeded(String pathStr) async {
    final trimmed = pathStr.trim();
    if (trimmed.isEmpty) return '';
    if (File(trimmed).existsSync()) {
      return _storage.importAudioFile(trimmed);
    }
    return trimmed;
  }

  Future<void> _replaceActiveSceneCues(List<CueItem> nextCues) async {
    final scene = activeScene;
    if (scene == null) return;
    final updatedScenes = [..._project.scenes];
    updatedScenes[activeSceneIndex] = scene.copyWith(cues: nextCues);
    _project = _project.copyWith(scenes: updatedScenes);
    await _save();
  }

  // --------------------------------------------------------------------------
  // Appearance, Settings & Show Packaging
  // --------------------------------------------------------------------------

  Future<void> toggleDarkMode() async {
    _project = _project.copyWith(
      settings: settings.copyWith(darkMode: !settings.darkMode),
    );
    await _save();
    notifyListeners();
  }

  Future<void> setSeedColor(Color color) async {
    _project = _project.copyWith(
      settings: settings.copyWith(seedColorValue: color.toARGB32()),
    );
    await _save();
    notifyListeners();
  }

  Future<void> updateSidebarRatio(double ratio, {bool persist = false}) async {
    final clamped = ratio.clamp(0.18, 0.45);
    _project = _project.copyWith(
      settings: settings.copyWith(sidebarRatio: clamped),
    );
    notifyListeners();
    if (persist) await _save();
  }

  Future<void> updateAudioSettings({
    double? duckRatio,
    int? bgmCrossfadeMs,
  }) async {
    _project = _project.copyWith(
      settings: settings.copyWith(
        duckRatio: duckRatio,
        bgmCrossfadeMs: bgmCrossfadeMs,
      ),
    );
    if (bgmState.isDucking) {
      _audio.setDucking(true, duckRatio: settings.duckRatio);
    }
    await _save();
    notifyListeners();
  }

  Future<void> switchWorkspace(Directory dir) async {
    await panicStopAll();
    await _storage.switchWorkspace(dir);
    _project = await _storage.loadProject();
    _activeSceneIndex = 0;
    _statusMessage = '已切换工程目录: ${dir.path}';
    notifyListeners();
  }

  Future<void> importLegacyProjectJson(File jsonFile) async {
    await panicStopAll();
    _project = await _storage.loadProjectFromFile(
      jsonFile,
      copyExternalMedia: true,
    );
    _activeSceneIndex = 0;
    await _save();
    _statusMessage = '已导入工程配置: ${p.basename(jsonFile.path)}';
    notifyListeners();
  }

  Future<void> exportShowBundle(String destinationZipPath) async {
    await _storage.exportShowBundle(_project, destinationZipPath);
    _statusMessage = '已导出演出工程包: ${p.basename(destinationZipPath)}';
    notifyListeners();
  }

  Future<void> importShowBundle(String zipPath) async {
    await panicStopAll();
    _project = await _storage.importShowBundle(zipPath);
    _activeSceneIndex = 0;
    _statusMessage = '已导入演出工程包: ${p.basename(zipPath)}';
    notifyListeners();
  }

  String resolveCueDisplayFileName(CueItem cue) {
    if (cue.filePath.isEmpty) return '未绑定文件';
    return p.basename(cue.filePath);
  }

  bool isCueFilePresent(CueItem cue) {
    final resolved = _storage.resolveCuePath(cue);
    return resolved.isNotEmpty && File(resolved).existsSync();
  }

  Future<void> _save() => _storage.saveProject(_project);

  @override
  void dispose() {
    _audio.bgmState.removeListener(_onAudioChanged);
    _audio.playingCueIds.removeListener(_onAudioChanged);
    super.dispose();
  }
}
