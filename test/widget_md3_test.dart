import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:stage_commander/controllers/stage_controller.dart';
import 'package:stage_commander/main.dart';
import 'package:stage_commander/models/show_models.dart';
import 'package:stage_commander/services/project_storage.dart';

import 'stage_controller_test.dart';

class InMemoryProjectStorage extends ProjectStorage {
  InMemoryProjectStorage() : super(initialWorkspaceDir: Directory.current);

  ShowProject _saved = const ShowProject(
    scenes: [
      SceneAct(
        id: 'scene_1',
        name: '第一幕',
        cues: [
          CueItem(
            id: 'cue_1',
            name: '开场序曲',
            filePath: 'Media/overture.mp3',
            mode: CueMode.bgm,
            hotkeyCode: 'Digit1',
            hotkeyLabel: '1',
            loop: true,
          ),
        ],
      ),
    ],
  );

  @override
  Future<void> initialize() async {}

  @override
  Future<ShowProject> loadProject() async => _saved;

  @override
  Future<void> saveProject(ShowProject project) async {
    _saved = project;
  }
}

void main() {
  testWidgets(
    'StageCommanderApp renders MD3 layout, arms, toggles theme & panics cleanly',
    (tester) async {
      tester.view.physicalSize = const Size(1360, 860);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = InMemoryProjectStorage();
      final audio = FakeAudioEngine();
      final controller = StageController(storage: storage, audio: audio);
      await controller.initialize();

      addTearDown(() async {
        controller.dispose();
        await audio.dispose();
      });

      await tester.pumpWidget(StageCommanderApp(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('StageCommander'), findsOneWidget);
      expect(find.text('剧幕列表'), findsOneWidget);
      expect(find.text('GO · 激活系统 (Space)'), findsOneWidget);
      expect(find.text('全部停止 (Esc)'), findsOneWidget);

      // Click GO button -> transitions to armed state
      await tester.tap(find.text('GO · 激活系统 (Space)'));
      await tester.pumpAndSettle();
      expect(controller.systemArmed, isTrue);
      expect(find.text('GO · 热键已激活'), findsOneWidget);

      // Safe lock without panic
      await tester.tap(find.text('仅锁定'));
      await tester.pumpAndSettle();
      expect(controller.systemArmed, isFalse);

      // Re-arm and press PANIC button -> stops & re-locks
      await tester.tap(find.text('GO · 激活系统 (Space)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('全部停止 (Esc)'));
      await tester.pumpAndSettle();
      expect(controller.systemArmed, isFalse);
      expect(audio.panicCount, 1);

      // Toggle ducking button
      await tester.tap(find.text('台词闪避 (降至 30%)'));
      await tester.pumpAndSettle();
      expect(controller.bgmState.isDucking, isTrue);
      expect(find.text('恢复音量 (闪避中 30%)'), findsOneWidget);

      // Toggle dark -> light MD3 theme cleanly
      await tester.tap(find.byIcon(Icons.light_mode_rounded));
      await tester.pumpAndSettle();
      expect(controller.settings.darkMode, isFalse);

      // Verify minimum supported desktop size renders without overflow
      tester.view.physicalSize = const Size(1020, 660);
      await tester.pumpAndSettle();
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
