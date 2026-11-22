import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import 'app/theme/md3_theme.dart';
import 'controllers/stage_controller.dart';
import 'services/audio_engine.dart';
import 'services/project_storage.dart';
import 'ui/stage_commander_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Required for non-sandboxed macOS desktop builds so FilePicker does not fail
  // App Sandbox entitlement assertions.
  if (Platform.isMacOS) {
    await FilePicker.skipEntitlementsChecks();
  }

  final storage = ProjectStorage();
  final audio = SoLoudStageAudioEngine();
  final controller = StageController(storage: storage, audio: audio);
  await controller.initialize();

  runApp(StageCommanderApp(controller: controller));
}

/// Root Material Design 3 application wrapper supporting Light & Dark theater
/// themes and dynamic seed palette customization.
class StageCommanderApp extends StatelessWidget {
  const StageCommanderApp({super.key, required this.controller});

  final StageController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final seed = Color(controller.settings.seedColorValue);
        return MaterialApp(
          title: 'StageCommander',
          debugShowCheckedModeBanner: false,
          themeMode:
              controller.settings.darkMode ? ThemeMode.dark : ThemeMode.light,
          theme: buildStageMd3Theme(
            brightness: Brightness.light,
            seedColor: seed,
          ),
          darkTheme: buildStageMd3Theme(
            brightness: Brightness.dark,
            seedColor: seed,
          ),
          home: StageCommanderScreen(controller: controller),
        );
      },
    );
  }
}
