import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../controllers/stage_controller.dart';
import '../models/show_models.dart';
import 'dialogs/cue_edit_dialog.dart';
import 'dialogs/stage_dialogs.dart';
import 'widgets/bgm_control_deck.dart';
import 'widgets/cue_list_view.dart';
import 'widgets/safety_status_banner.dart';
import 'widgets/scene_rail.dart';
import 'widgets/stage_action_deck.dart';

/// Root desktop workbench hosting the top safety bar, resizable 3:7 split
/// between [SceneRail] and Cue/BGM Console, and global keyboard handling.
class StageCommanderScreen extends StatefulWidget {
  const StageCommanderScreen({super.key, required this.controller});

  final StageController controller;

  @override
  State<StageCommanderScreen> createState() => _StageCommanderScreenState();
}

class _StageCommanderScreenState extends State<StageCommanderScreen> {
  bool _isDraggingSplitter = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onHardwareKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKeyEvent);
    super.dispose();
  }

  bool _hasEditableFocus() {
    final primary = FocusManager.instance.primaryFocus;
    final ctx = primary?.context;
    if (ctx == null) return false;
    if (ctx.widget is EditableText) return true;
    return ctx.findAncestorStateOfType<EditableTextState>() != null ||
        ctx.findAncestorWidgetOfExactType<TextField>() != null;
  }

  bool _onHardwareKeyEvent(KeyEvent event) {
    return widget.controller.handleGlobalKeyEvent(
      event,
      hasEditableFocus: _hasEditableFocus(),
    );
  }

  Future<T?> _runGuardedDialog<T>(Future<T?> Function() openDialog) async {
    widget.controller.pushModalGuard();
    try {
      return await openDialog();
    } finally {
      widget.controller.popModalGuard();
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  Future<void> _onAddScene() async {
    final nextNum = widget.controller.scenes.length + 1;
    final name = await _runGuardedDialog(
      () => showActNameDialog(
        context,
        title: '新建剧幕',
        initialName: '第 $nextNum 幕',
      ),
    );
    if (name != null) {
      await widget.controller.addScene(name);
    }
  }

  Future<void> _onRenameScene(int index, SceneAct scene) async {
    final name = await _runGuardedDialog(
      () => showActNameDialog(
        context,
        title: '重命名剧幕',
        initialName: scene.name,
      ),
    );
    if (name != null) {
      await widget.controller.renameScene(index, name);
    }
  }

  Future<void> _onDeleteScene(int index, SceneAct scene) async {
    if (widget.controller.scenes.length <= 1) {
      _showToast('至少需要保留一幕');
      return;
    }
    final ok = await _runGuardedDialog(
      () => showStageConfirmDialog(
        context,
        title: '删除剧幕',
        message: '确定删除「${scene.name}」及其内部 ${scene.cues.length} 条音效配置吗？',
      ),
    );
    if (ok == true) {
      await widget.controller.deleteScene(index);
    }
  }

  Future<void> _onAddCue() async {
    final scene = widget.controller.activeScene;
    if (scene == null) return;
    final created = await _runGuardedDialog(
      () => showDialog<CueItem>(
        context: context,
        builder: (_) => CueEditDialog(existingCuesInScene: scene.cues),
      ),
    );
    if (created != null) {
      await widget.controller.addCue(created);
    }
  }

  Future<void> _onEditCue(CueItem cue) async {
    final scene = widget.controller.activeScene;
    if (scene == null) return;
    final edited = await _runGuardedDialog(
      () => showDialog<CueItem>(
        context: context,
        builder: (_) => CueEditDialog(
          initialCue: cue,
          existingCuesInScene: scene.cues,
        ),
      ),
    );
    if (edited != null) {
      await widget.controller.updateCue(edited);
    }
  }

  Future<void> _onDeleteCue(CueItem cue) async {
    final ok = await _runGuardedDialog(
      () => showStageConfirmDialog(
        context,
        title: '删除音效',
        message: '确定从当前幕移除「${cue.name}」吗？（Media 媒体目录中的原文件会保留以免影响其他剧幕）',
      ),
    );
    if (ok == true) {
      await widget.controller.deleteCue(cue);
    }
  }

  Future<void> _onBatchImportAudio() async {
    final picked = await _runGuardedDialog(
      () => FilePicker.pickFiles(
        dialogTitle: '批量选择音频文件导入当前幕',
        type: FileType.custom,
        allowedExtensions: kSupportedAudioExtensions,
      ),
    );
    if (picked == null || picked.isEmpty) return;
    final paths = picked.map((e) => e.path).whereType<String>().toList();
    final count = await widget.controller.importAudioFilesAsCues(paths);
    if (count > 0) {
      _showToast('成功导入 $count 个音频文件');
    }
  }

  Future<void> _onWorkspaceAction(WorkspaceAction action) async {
    switch (action) {
      case WorkspaceAction.switchWorkspace:
        final dirPath = await _runGuardedDialog(
          () => FilePicker.getDirectoryPath(
            dialogTitle: '选择或新建 StageCommander_Data 工程目录',
          ),
        );
        if (dirPath != null && dirPath.trim().isNotEmpty) {
          await widget.controller.switchWorkspace(Directory(dirPath));
          _showToast('已切换工程目录');
        }
      case WorkspaceAction.importLegacyJson:
        final picked = await _runGuardedDialog(
          () => FilePicker.pickFile(
            dialogTitle: '选择 project.json (支持 Beta 8 自动迁移)',
            type: FileType.custom,
            allowedExtensions: ['json'],
          ),
        );
        if (picked?.path != null) {
          await widget.controller.importLegacyProjectJson(File(picked!.path!));
          _showToast('已导入工程配置');
        }
      case WorkspaceAction.exportBundle:
        final tempDir = await Directory.systemTemp.createTemp('sc_export_');
        final tempZip = p.join(tempDir.path, 'StageCommander_Show.zip');
        try {
          await widget.controller.exportShowBundle(tempZip);
          final bytes = await File(tempZip).readAsBytes();
          final savedUri = await _runGuardedDialog(
            () => FilePicker.saveFile(
              dialogTitle: '保存便携演出工程包 (.zip)',
              fileName: 'StageCommander_Show.zip',
              bytes: bytes,
              mimeType: 'application/zip',
            ),
          );
          if (savedUri != null) {
            _showToast('已导出便携演出包');
          }
        } finally {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        }
      case WorkspaceAction.importBundle:
        final picked = await _runGuardedDialog(
          () => FilePicker.pickFile(
            dialogTitle: '选择要导入的演出工程包 (.zip)',
            type: FileType.custom,
            allowedExtensions: ['zip'],
          ),
        );
        if (picked?.path != null) {
          await widget.controller.importShowBundle(picked!.path!);
          _showToast('已导入便携演出包');
        }
      case WorkspaceAction.audioSettings:
        final settings = widget.controller.settings;
        final updated = await _runGuardedDialog(
          () => showAudioSettingsDialog(
            context,
            initialDuckRatio: settings.duckRatio,
            initialCrossfadeMs: settings.bgmCrossfadeMs,
          ),
        );
        if (updated != null) {
          await widget.controller.updateAudioSettings(
            duckRatio: updated.duckRatio,
            bgmCrossfadeMs: updated.crossfadeMs,
          );
          _showToast('已保存播控参数');
        }
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final controller = widget.controller;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: scheme.surface,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SafetyStatusBanner(
                    controller: controller,
                    onWorkspaceAction: _onWorkspaceAction,
                    onShowHelp: () => _runGuardedDialog(
                      () => showShortcutsDialog(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const splitterWidth = 12.0;
                        final totalWidth = constraints.maxWidth;
                        final leftWidth = (totalWidth *
                                controller.settings.sidebarRatio)
                            .clamp(220.0, totalWidth * 0.45);

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: leftWidth,
                              child: SceneRail(
                                controller: controller,
                                onAddScene: _onAddScene,
                                onRenameScene: _onRenameScene,
                                onDeleteScene: _onDeleteScene,
                              ),
                            ),
                            MouseRegion(
                              cursor: SystemMouseCursors.resizeColumn,
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onHorizontalDragStart: (_) => setState(
                                  () => _isDraggingSplitter = true,
                                ),
                                onHorizontalDragUpdate: (details) {
                                  if (totalWidth <= 0) return;
                                  final nextRatio =
                                      (leftWidth + details.delta.dx) /
                                          totalWidth;
                                  controller.updateSidebarRatio(nextRatio);
                                },
                                onHorizontalDragEnd: (_) {
                                  setState(
                                    () => _isDraggingSplitter = false,
                                  );
                                  controller.updateSidebarRatio(
                                    controller.settings.sidebarRatio,
                                    persist: true,
                                  );
                                },
                                child: SizedBox(
                                  width: splitterWidth,
                                  child: Center(
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 140),
                                      width: _isDraggingSplitter ? 4 : 3,
                                      height: _isDraggingSplitter ? 72 : 44,
                                      decoration: BoxDecoration(
                                        color: _isDraggingSplitter
                                            ? scheme.primary
                                            : scheme.outlineVariant,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: CueListView(
                                      controller: controller,
                                      onAddCue: _onAddCue,
                                      onEditCue: _onEditCue,
                                      onDeleteCue: _onDeleteCue,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  BgmControlDeck(controller: controller),
                                  const SizedBox(height: 12),
                                  StageActionDeck(
                                    controller: controller,
                                    onAddCue: _onAddCue,
                                    onBatchImport: _onBatchImportAudio,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
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
