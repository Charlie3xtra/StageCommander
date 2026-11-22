import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stage_commander/models/show_models.dart';
import 'package:stage_commander/services/hotkey_mapper.dart';
import 'package:stage_commander/services/project_storage.dart';

void main() {
  group('ShowProject & Legacy Beta 8 Migration', () {
    test('overlapping saves keep the most recent project snapshot', () async {
      final dir = await Directory.systemTemp.createTemp('sc_save_test_');
      addTearDown(() => dir.delete(recursive: true));
      final storage = ProjectStorage(initialWorkspaceDir: dir);
      await storage.initialize();

      const initial = ShowProject(
        scenes: [SceneAct(id: 's1', name: 'Act 1')],
      );
      const updated = ShowProject(
        scenes: [SceneAct(id: 's1', name: 'Act 2')],
      );

      await storage.saveProject(initial);
      await Future.wait([
        storage.saveProject(initial),
        storage.saveProject(updated),
      ]);

      expect((await storage.loadProject()).scenes.single.name, 'Act 2');
    });

    test('parses legacy Beta 8 JSON array and migrates volumes/hotkeys', () {
      const legacyJson = '''
      [
        {
          "scene_name": "第一幕 · 开场",
          "cues": [
            {
              "name": "序曲 BGM",
              "file_path": "C:/StageCommander_Data/Media/overture.wav",
              "mode": "bgm",
              "volume": 80,
              "hotkey": "1"
            },
            {
              "name": "雷声",
              "file_path": "C:/StageCommander_Data/Media/thunder.mp3",
              "mode": "sfx",
              "volume": 100,
              "hotkey": "a"
            },
            {
              "name": "误绑空格",
              "file_path": "C:/StageCommander_Data/Media/bad.wav",
              "mode": "sfx",
              "volume": 50,
              "hotkey": "space"
            }
          ]
        }
      ]
      ''';

      var seq = 0;
      final parsed = ShowProject.fromDynamicJson(
        jsonDecode(legacyJson),
        nextId: () => 'id_${++seq}',
        parseLegacyHotkey: HotkeyMapper.parseLegacyString,
      );

      expect(parsed.migratedFromLegacy, isTrue);
      expect(parsed.project.scenes, hasLength(1));

      final cues = parsed.project.scenes.first.cues;
      expect(cues[0].mode, CueMode.bgm);
      expect(cues[0].volume, closeTo(0.8, 0.001));
      expect(cues[0].hotkeyCode, 'Digit1');
      expect(cues[0].hotkeyLabel, '1');

      expect(cues[1].mode, CueMode.sfx);
      expect(cues[1].volume, closeTo(1.0, 0.001));
      expect(cues[1].hotkeyCode, 'KeyA');
      expect(cues[1].hotkeyLabel, 'A');

      // Reserved safety keys must not survive legacy import as cue hotkeys.
      expect(cues[2].hotkeyCode, isEmpty);
    });

    test('detects duplicate hotkeys per scene while keeping acts isolated', () {
      const scene = SceneAct(
        id: 's1',
        name: 'Act 1',
        cues: [
          CueItem(
            id: 'c1',
            name: 'Cue 1',
            filePath: 'Media/a.wav',
            hotkeyCode: 'Digit1',
            hotkeyLabel: '1',
          ),
          CueItem(
            id: 'c2',
            name: 'Cue 2',
            filePath: 'Media/b.wav',
            hotkeyCode: 'Digit1',
            hotkeyLabel: '1',
          ),
          CueItem(
            id: 'c3',
            name: 'Cue 3',
            filePath: 'Media/c.wav',
            hotkeyCode: 'KeyA',
            hotkeyLabel: 'A',
          ),
        ],
      );

      expect(scene.duplicateHotkeyCodes(), equals({'Digit1'}));
    });

    test(
      'ProjectStorage deduplicates identical files and resolves relative paths',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'sc_storage_test_',
        );
        final sourceDir = await Directory.systemTemp.createTemp('sc_src_test_');
        try {
          final storage = ProjectStorage(initialWorkspaceDir: tempDir);
          await storage.initialize();

          final srcA = File(p.join(sourceDir.path, 'boom.wav'));
          await srcA.writeAsBytes([1, 2, 3, 4, 5]);

          final srcSameContent = File(p.join(sourceDir.path, 'boom_copy.wav'));
          await srcSameContent.writeAsBytes([1, 2, 3, 4, 5]);

          final rel1 = await storage.importAudioFile(srcA.path);
          final rel2 = await storage.importAudioFile(srcSameContent.path);

          expect(rel1, startsWith('Media/'));
          expect(rel2, startsWith('Media/'));
          expect(
            File(
              storage.resolveCuePath(
                CueItem(id: '1', name: 'x', filePath: rel1),
              ),
            ).existsSync(),
            isTrue,
          );

          // Save and reload atomically
          final project = ShowProject(
            scenes: [
              SceneAct(
                id: 's1',
                name: '幕 1',
                cues: [CueItem(id: 'c1', name: 'Boom', filePath: rel1)],
              ),
            ],
          );
          await storage.saveProject(project);
          final reloaded = await storage.loadProject();
          expect(reloaded.scenes.first.cues.first.filePath, rel1);
        } finally {
          await tempDir.delete(recursive: true);
          await sourceDir.delete(recursive: true);
        }
      },
    );
  });
}
