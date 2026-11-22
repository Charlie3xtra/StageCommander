import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stage_commander/controllers/stage_controller.dart';
import 'package:stage_commander/models/show_models.dart';
import 'package:stage_commander/services/audio_engine.dart';
import 'package:stage_commander/services/project_storage.dart';

class FakeAudioEngine implements StageAudioEngine {
  @override
  final ValueNotifier<BgmPlaybackState> bgmState =
      ValueNotifier(const BgmPlaybackState());

  @override
  final ValueNotifier<Set<String>> playingCueIds = ValueNotifier(<String>{});

  final List<String> playLog = [];
  int panicCount = 0;

  @override
  bool get isReady => true;

  @override
  String? get initError => null;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> playCue(
    CueItem cue,
    String resolvedPath, {
    int bgmCrossfadeMs = 200,
    double duckRatio = 0.30,
  }) async {
    playLog.add(cue.id);
    if (cue.mode == CueMode.bgm) {
      final next = <String>{...playingCueIds.value};
      if (bgmState.value.cueId != null) next.remove(bgmState.value.cueId);
      next.add(cue.id);
      playingCueIds.value = next;
      bgmState.value = bgmState.value.copyWith(
        cueId: cue.id,
        title: cue.name,
        filePath: resolvedPath,
        isPlaying: true,
        isPaused: false,
        duration: const Duration(minutes: 2),
        volume: cue.volume,
      );
    } else {
      playingCueIds.value = {...playingCueIds.value, cue.id};
    }
    return true;
  }

  @override
  Future<void> stopCue(String cueId, {int fadeOutMs = 0}) async {
    final next = {...playingCueIds.value}..remove(cueId);
    playingCueIds.value = next;
    if (bgmState.value.cueId == cueId) {
      bgmState.value = bgmState.value.copyWith(clearTrack: true);
    }
  }

  @override
  Future<void> panicStopAll() async {
    panicCount++;
    playingCueIds.value = <String>{};
    bgmState.value = bgmState.value.copyWith(clearTrack: true);
  }

  @override
  Future<void> pauseBgm() async {
    bgmState.value = bgmState.value.copyWith(isPlaying: false, isPaused: true);
  }

  @override
  Future<void> resumeBgm() async {
    bgmState.value = bgmState.value.copyWith(isPlaying: true, isPaused: false);
  }

  @override
  Future<void> seekBgm(Duration position) async {
    bgmState.value = bgmState.value.copyWith(position: position);
  }

  @override
  void setBgmVolume(double volume, {double duckRatio = 0.30}) {
    bgmState.value = bgmState.value.copyWith(volume: volume);
  }

  @override
  void setBgmLoop(bool loop) {
    bgmState.value = bgmState.value.copyWith(isLooping: loop);
  }

  @override
  void setDucking(bool enabled, {double duckRatio = 0.30}) {
    bgmState.value = bgmState.value.copyWith(isDucking: enabled);
  }

  @override
  Future<List<double>> extractWaveformPeaks(
    String resolvedPath, {
    int bins = 160,
  }) async =>
      List<double>.filled(bins, 0.5);

  @override
  Future<void> dispose() async {
    bgmState.dispose();
    playingCueIds.dispose();
  }
}

void main() {
  group('StageController Safety & Scene Isolation', () {
    late Directory tempDir;
    late FakeAudioEngine audio;
    late StageController controller;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sc_ctrl_test_');
      final storage = ProjectStorage(initialWorkspaceDir: tempDir);
      audio = FakeAudioEngine();
      controller = StageController(storage: storage, audio: audio);
      await controller.initialize();

      final mediaFile1 = File(p.join(tempDir.path, 'Media', 'one.wav'));
      final mediaFile2 = File(p.join(tempDir.path, 'Media', 'two.wav'));
      await mediaFile1.writeAsBytes([1, 2, 3]);
      await mediaFile2.writeAsBytes([4, 5, 6]);

      await controller.addCue(
        const CueItem(
          id: 'act1_bgm',
          name: 'Act1 BGM',
          filePath: 'Media/one.wav',
          mode: CueMode.bgm,
          hotkeyCode: 'Digit1',
          hotkeyLabel: '1',
        ),
      );

      await controller.addScene('第二幕');
      await controller.addCue(
        const CueItem(
          id: 'act2_sfx',
          name: 'Act2 Thunder',
          filePath: 'Media/two.wav',
          mode: CueMode.sfx,
          hotkeyCode: 'Digit1',
          hotkeyLabel: '1',
        ),
      );
      controller.selectScene(0);
    });

    tearDown(() async {
      controller.dispose();
      await audio.dispose();
      await tempDir.delete(recursive: true);
    });

    test('blocks hotkeys while disarmed, arms on Space, panics & locks on Esc', () async {
      const key1 = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.digit1,
        logicalKey: LogicalKeyboardKey.digit1,
        timeStamp: Duration.zero,
      );
      const space = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.space,
        logicalKey: LogicalKeyboardKey.space,
        timeStamp: Duration.zero,
      );
      const esc = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.escape,
        logicalKey: LogicalKeyboardKey.escape,
        timeStamp: Duration.zero,
      );

      // Disarmed by default
      expect(controller.systemArmed, isFalse);
      expect(
        controller.handleGlobalKeyEvent(key1, hasEditableFocus: false),
        isFalse,
      );
      expect(audio.playLog, isEmpty);

      // Space arms system
      expect(
        controller.handleGlobalKeyEvent(space, hasEditableFocus: false),
        isTrue,
      );
      expect(controller.systemArmed, isTrue);

      // Modal guard or editable text suppresses triggers
      controller.pushModalGuard();
      expect(
        controller.handleGlobalKeyEvent(key1, hasEditableFocus: false),
        isFalse,
      );
      controller.popModalGuard();
      expect(
        controller.handleGlobalKeyEvent(key1, hasEditableFocus: true),
        isFalse,
      );

      // Active scene 0 triggers act1_bgm on Digit1
      expect(
        controller.handleGlobalKeyEvent(key1, hasEditableFocus: false),
        isTrue,
      );
      await Future<void>.delayed(Duration.zero);
      expect(audio.playLog, equals(['act1_bgm']));

      // Switching to scene 1 triggers act2_sfx on same Digit1 (act isolation)
      controller.selectScene(1);
      expect(
        controller.handleGlobalKeyEvent(key1, hasEditableFocus: false),
        isTrue,
      );
      await Future<void>.delayed(Duration.zero);
      expect(audio.playLog, equals(['act1_bgm', 'act2_sfx']));

      // Escape panics & re-locks
      expect(
        controller.handleGlobalKeyEvent(esc, hasEditableFocus: false),
        isTrue,
      );
      await Future<void>.delayed(Duration.zero);
      expect(audio.panicCount, 1);
      expect(controller.systemArmed, isFalse);
      expect(controller.playingCueIds, isEmpty);
    });
  });
}
