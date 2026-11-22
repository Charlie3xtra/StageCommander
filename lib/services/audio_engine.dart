import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../models/show_models.dart';

/// Live snapshot of the exclusive BGM playback deck.
@immutable
class BgmPlaybackState {
  const BgmPlaybackState({
    this.cueId,
    this.title = '',
    this.filePath = '',
    this.isPlaying = false,
    this.isPaused = false,
    this.isLooping = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.isDucking = false,
  });

  final String? cueId;
  final String title;
  final String filePath;
  final bool isPlaying;
  final bool isPaused;
  final bool isLooping;
  final Duration position;
  final Duration duration;
  final double volume;
  final bool isDucking;

  bool get hasTrack => cueId != null && filePath.isNotEmpty;

  BgmPlaybackState copyWith({
    String? cueId,
    bool clearTrack = false,
    String? title,
    String? filePath,
    bool? isPlaying,
    bool? isPaused,
    bool? isLooping,
    Duration? position,
    Duration? duration,
    double? volume,
    bool? isDucking,
  }) {
    if (clearTrack) {
      return BgmPlaybackState(
        volume: volume ?? this.volume,
        isDucking: isDucking ?? this.isDucking,
      );
    }
    return BgmPlaybackState(
      cueId: cueId ?? this.cueId,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      isPlaying: isPlaying ?? this.isPlaying,
      isPaused: isPaused ?? this.isPaused,
      isLooping: isLooping ?? this.isLooping,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      isDucking: isDucking ?? this.isDucking,
    );
  }
}

/// Abstract audio engine interface enabling deterministic headless tests.
abstract class StageAudioEngine {
  ValueListenable<BgmPlaybackState> get bgmState;
  ValueListenable<Set<String>> get playingCueIds;
  bool get isReady;
  String? get initError;

  Future<void> initialize();
  Future<bool> playCue(
    CueItem cue,
    String resolvedPath, {
    int bgmCrossfadeMs = 200,
    double duckRatio = 0.30,
  });
  Future<void> stopCue(String cueId, {int fadeOutMs = 0});
  Future<void> panicStopAll();
  Future<void> pauseBgm();
  Future<void> resumeBgm();
  Future<void> seekBgm(Duration position);
  void setBgmVolume(double volume, {double duckRatio = 0.30});
  void setBgmLoop(bool loop);
  void setDucking(bool enabled, {double duckRatio = 0.30});
  Future<List<double>> extractWaveformPeaks(
    String resolvedPath, {
    int bins = 160,
  });
  Future<void> dispose();
}

/// Native C++ SoLoud audio engine supporting SFX triggers,
/// exclusive crossfaded BGM, smooth talkover ducking, and multi-format waveforms.
class SoLoudStageAudioEngine implements StageAudioEngine {
  SoLoudStageAudioEngine({SoLoud? soloud}) : _soloud = soloud ?? SoLoud.instance;

  static const int _memoryThresholdBytes = 64 * 1024 * 1024;

  final SoLoud _soloud;

  @override
  final ValueNotifier<BgmPlaybackState> bgmState =
      ValueNotifier(const BgmPlaybackState());

  @override
  final ValueNotifier<Set<String>> playingCueIds = ValueNotifier(<String>{});

  final Map<String, AudioSource> _sourceCache = {};
  final Map<String, StreamSubscription<StreamSoundEvent>> _sourceSubs = {};
  final Map<String, SoundHandle> _sfxHandlesByCue = {};
  final Map<SoundHandle, String> _cueByHandle = {};
  final Map<String, List<double>> _waveformCache = {};

  SoundHandle? _bgmHandle;
  AudioSource? _bgmSource;
  Timer? _bgmProgressTimer;
  bool _isReady = false;
  String? _initError;

  @override
  bool get isReady => _isReady;

  @override
  String? get initError => _initError;

  @override
  Future<void> initialize() async {
    if (_isReady) return;
    try {
      await _soloud.init(
        sampleRate: 44100,
        bufferSize: 1024,
        lowLatency: true,
      );
      _isReady = true;
      _initError = null;
    } catch (e) {
      _isReady = false;
      _initError = e.toString();
    }
  }

  Future<AudioSource?> _getOrLoadSource(String resolvedPath) async {
    if (!_isReady) await initialize();
    if (!_isReady) return null;

    final file = File(resolvedPath);
    if (!await file.exists()) return null;

    final cached = _sourceCache[resolvedPath];
    if (cached != null) return cached;

    final size = await file.length();
    final mode =
        size <= _memoryThresholdBytes ? LoadMode.memory : LoadMode.disk;
    final source = await _soloud.loadFile(resolvedPath, mode: mode);
    _sourceCache[resolvedPath] = source;
    _sourceSubs[resolvedPath] = source.soundEvents.listen(_onSoundEvent);
    return source;
  }

  void _onSoundEvent(StreamSoundEvent event) {
    if (event.event != SoundEventType.handleIsNoMoreValid) return;

    if (_bgmHandle == event.handle) {
      _bgmHandle = null;
      _bgmSource = null;
      _stopProgressTimer();
      bgmState.value = bgmState.value.copyWith(clearTrack: true);
      _emitPlayingCues();
      return;
    }

    final cueId = _cueByHandle.remove(event.handle);
    if (cueId != null && _sfxHandlesByCue[cueId] == event.handle) {
      _sfxHandlesByCue.remove(cueId);
      _emitPlayingCues();
    }
  }

  void _emitPlayingCues() {
    final ids = <String>{..._sfxHandlesByCue.keys};
    final bgmCueId = bgmState.value.cueId;
    if (bgmCueId != null &&
        (bgmState.value.isPlaying || bgmState.value.isPaused)) {
      ids.add(bgmCueId);
    }
    playingCueIds.value = Set<String>.unmodifiable(ids);
  }

  @override
  Future<bool> playCue(
    CueItem cue,
    String resolvedPath, {
    int bgmCrossfadeMs = 200,
    double duckRatio = 0.30,
  }) async {
    final source = await _getOrLoadSource(resolvedPath);
    if (source == null) return false;

    if (cue.mode == CueMode.bgm) {
      return _playBgm(
        cue,
        resolvedPath,
        source,
        crossfadeMs: bgmCrossfadeMs,
        duckRatio: duckRatio,
      );
    }
    return _playSfxRetrigger(cue, source);
  }

  Future<bool> _playBgm(
    CueItem cue,
    String resolvedPath,
    AudioSource source, {
    required int crossfadeMs,
    required double duckRatio,
  }) async {
    final oldHandle = _bgmHandle;
    _bgmHandle = null;
    if (oldHandle != null && _soloud.getIsValidVoiceHandle(oldHandle)) {
      if (crossfadeMs > 0) {
        _soloud.fadeVolume(
          oldHandle,
          0.0,
          Duration(milliseconds: crossfadeMs),
        );
        _soloud.scheduleStop(
          oldHandle,
          Duration(milliseconds: crossfadeMs),
        );
      } else {
        await _soloud.stop(oldHandle);
      }
    }

    final baseVolume = cue.volume.clamp(0.0, 1.0);
    final effectiveVolume =
        bgmState.value.isDucking ? baseVolume * duckRatio : baseVolume;

    final newHandle = _soloud.play(
      source,
      volume: effectiveVolume,
      looping: cue.loop,
    );
    _bgmHandle = newHandle;
    _bgmSource = source;

    final totalDuration = _soloud.getLength(source);
    bgmState.value = bgmState.value.copyWith(
      cueId: cue.id,
      title: cue.name,
      filePath: resolvedPath,
      isPlaying: true,
      isPaused: false,
      isLooping: cue.loop,
      position: Duration.zero,
      duration: totalDuration,
      volume: baseVolume,
    );
    _startProgressTimer();
    _emitPlayingCues();
    return true;
  }

  Future<bool> _playSfxRetrigger(CueItem cue, AudioSource source) async {
    final existing = _sfxHandlesByCue.remove(cue.id);
    if (existing != null) {
      _cueByHandle.remove(existing);
      if (_soloud.getIsValidVoiceHandle(existing)) {
        await _soloud.stop(existing);
      }
    }

    final handle = _soloud.play(
      source,
      volume: cue.volume.clamp(0.0, 1.0),
      looping: cue.loop,
    );
    _sfxHandlesByCue[cue.id] = handle;
    _cueByHandle[handle] = cue.id;
    _emitPlayingCues();
    return true;
  }

  @override
  Future<void> stopCue(String cueId, {int fadeOutMs = 0}) async {
    if (bgmState.value.cueId == cueId) {
      final handle = _bgmHandle;
      _bgmHandle = null;
      _bgmSource = null;
      _stopProgressTimer();
      bgmState.value = bgmState.value.copyWith(clearTrack: true);
      if (handle != null && _soloud.getIsValidVoiceHandle(handle)) {
        if (fadeOutMs > 0) {
          _soloud.fadeVolume(handle, 0.0, Duration(milliseconds: fadeOutMs));
          _soloud.scheduleStop(handle, Duration(milliseconds: fadeOutMs));
        } else {
          await _soloud.stop(handle);
        }
      }
      _emitPlayingCues();
      return;
    }

    final sfxHandle = _sfxHandlesByCue.remove(cueId);
    if (sfxHandle != null) {
      _cueByHandle.remove(sfxHandle);
      if (_soloud.getIsValidVoiceHandle(sfxHandle)) {
        if (fadeOutMs > 0) {
          _soloud.fadeVolume(
            sfxHandle,
            0.0,
            Duration(milliseconds: fadeOutMs),
          );
          _soloud.scheduleStop(sfxHandle, Duration(milliseconds: fadeOutMs));
        } else {
          await _soloud.stop(sfxHandle);
        }
      }
      _emitPlayingCues();
    }
  }

  @override
  Future<void> panicStopAll() async {
    _stopProgressTimer();
    final bgm = _bgmHandle;
    _bgmHandle = null;
    _bgmSource = null;
    bgmState.value = bgmState.value.copyWith(clearTrack: true);

    final activeHandles = <SoundHandle>[
      ?bgm,
      ..._sfxHandlesByCue.values,
    ];
    _sfxHandlesByCue.clear();
    _cueByHandle.clear();
    _emitPlayingCues();

    if (!_isReady) return;
    for (final handle in activeHandles) {
      if (_soloud.getIsValidVoiceHandle(handle)) {
        await _soloud.stop(handle);
      }
    }
  }

  @override
  Future<void> pauseBgm() async {
    final handle = _bgmHandle;
    if (!_isReady || handle == null || !_soloud.getIsValidVoiceHandle(handle)) {
      return;
    }
    _soloud.setPause(handle, true);
    _stopProgressTimer();
    bgmState.value = bgmState.value.copyWith(
      isPlaying: false,
      isPaused: true,
      position: _soloud.getPosition(handle),
    );
    _emitPlayingCues();
  }

  @override
  Future<void> resumeBgm() async {
    final handle = _bgmHandle;
    if (!_isReady || handle == null || !_soloud.getIsValidVoiceHandle(handle)) {
      return;
    }
    _soloud.setPause(handle, false);
    bgmState.value = bgmState.value.copyWith(
      isPlaying: true,
      isPaused: false,
    );
    _startProgressTimer();
    _emitPlayingCues();
  }

  @override
  Future<void> seekBgm(Duration position) async {
    final handle = _bgmHandle;
    if (!_isReady || handle == null || !_soloud.getIsValidVoiceHandle(handle)) {
      return;
    }
    final maxDur = bgmState.value.duration;
    final clamped = position < Duration.zero
        ? Duration.zero
        : (maxDur > Duration.zero && position > maxDur ? maxDur : position);
    _soloud.seek(handle, clamped);
    bgmState.value = bgmState.value.copyWith(position: clamped);
  }

  @override
  void setBgmVolume(double volume, {double duckRatio = 0.30}) {
    final clamped = volume.clamp(0.0, 1.0);
    bgmState.value = bgmState.value.copyWith(volume: clamped);

    final handle = _bgmHandle;
    if (_isReady && handle != null && _soloud.getIsValidVoiceHandle(handle)) {
      final target = bgmState.value.isDucking ? clamped * duckRatio : clamped;
      _soloud.setVolume(handle, target);
    }
  }

  @override
  void setBgmLoop(bool loop) {
    bgmState.value = bgmState.value.copyWith(isLooping: loop);
    final handle = _bgmHandle;
    if (_isReady && handle != null && _soloud.getIsValidVoiceHandle(handle)) {
      _soloud.setLooping(handle, loop);
    }
  }

  @override
  void setDucking(bool enabled, {double duckRatio = 0.30}) {
    bgmState.value = bgmState.value.copyWith(isDucking: enabled);
    final handle = _bgmHandle;
    if (_isReady && handle != null && _soloud.getIsValidVoiceHandle(handle)) {
      final target =
          enabled ? bgmState.value.volume * duckRatio : bgmState.value.volume;
      _soloud.fadeVolume(
        handle,
        target.clamp(0.0, 1.0),
        const Duration(milliseconds: 200),
      );
    }
  }

  @override
  Future<List<double>> extractWaveformPeaks(
    String resolvedPath, {
    int bins = 160,
  }) async {
    if (resolvedPath.isEmpty || !File(resolvedPath).existsSync()) {
      return const [];
    }
    final cacheKey = '$resolvedPath|$bins';
    final cached = _waveformCache[cacheKey];
    if (cached != null) return cached;

    if (!_isReady) await initialize();
    if (!_isReady) return const [];

    try {
      final raw = await _soloud.readSamplesFromFile(
        resolvedPath,
        bins * 4,
        average: true,
      );
      if (raw.isEmpty) return const [];

      final peaks = List<double>.filled(bins, 0.0);
      final step = raw.length / bins;
      var maxPeak = 0.0;
      for (var i = 0; i < bins; i++) {
        final start = (i * step).floor();
        final end = math.max(start + 1, ((i + 1) * step).ceil());
        var bucketPeak = 0.0;
        for (var j = start; j < end && j < raw.length; j++) {
          final v = raw[j].abs();
          if (v > bucketPeak) bucketPeak = v;
        }
        peaks[i] = bucketPeak;
        if (bucketPeak > maxPeak) maxPeak = bucketPeak;
      }

      final scale = maxPeak > 0.0001 ? 1.0 / maxPeak : 1.0;
      final normalized = [
        for (final p in peaks) (p * scale).clamp(0.05, 1.0),
      ];
      _waveformCache[cacheKey] = normalized;
      return normalized;
    } catch (_) {
      return const [];
    }
  }

  void _startProgressTimer() {
    _stopProgressTimer();
    _bgmProgressTimer = Timer.periodic(
      const Duration(milliseconds: 33),
      (_) {
        final handle = _bgmHandle;
        if (!_isReady ||
            handle == null ||
            !_soloud.getIsValidVoiceHandle(handle)) {
          _stopProgressTimer();
          return;
        }
        final pos = _soloud.getPosition(handle);
        final dur = _bgmSource != null
            ? _soloud.getLength(_bgmSource!)
            : bgmState.value.duration;
        bgmState.value = bgmState.value.copyWith(
          position: pos,
          duration: dur > Duration.zero ? dur : bgmState.value.duration,
        );
      },
    );
  }

  void _stopProgressTimer() {
    _bgmProgressTimer?.cancel();
    _bgmProgressTimer = null;
  }

  @override
  Future<void> dispose() async {
    _stopProgressTimer();
    for (final sub in _sourceSubs.values) {
      await sub.cancel();
    }
    _sourceSubs.clear();
    _sourceCache.clear();
    _sfxHandlesByCue.clear();
    _cueByHandle.clear();
    if (_isReady) {
      await _soloud.disposeAllSources();
      await _soloud.deinitAsync();
      _isReady = false;
    }
    bgmState.dispose();
    playingCueIds.dispose();
  }
}
