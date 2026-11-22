import 'package:material_ui/material_ui.dart';

import '../../app/theme/md3_theme.dart';
import '../../controllers/stage_controller.dart';

/// Menu actions surfaced in the workspace/project overflow menu.
enum WorkspaceAction {
  switchWorkspace,
  importLegacyJson,
  exportBundle,
  importBundle,
  audioSettings,
}

/// Top Material Design 3 status bar featuring workspace actions, the prominent
/// Armed/Disarmed safety indicator pill, and theme controls.
class SafetyStatusBanner extends StatelessWidget {
  const SafetyStatusBanner({
    super.key,
    required this.controller,
    required this.onWorkspaceAction,
    required this.onShowHelp,
  });

  final StageController controller;
  final ValueChanged<WorkspaceAction> onWorkspaceAction;
  final VoidCallback onShowHelp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantics = theme.extension<StageSemanticColors>()!;
    final armed = controller.systemArmed;

    final bannerBg = armed ? semantics.armedContainer : scheme.errorContainer;
    final bannerFg =
        armed ? semantics.onArmedContainer : scheme.onErrorContainer;
    final bannerBorder =
        armed ? semantics.armedAccent : scheme.error.withValues(alpha: 0.65);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Brand & Workspace Pill
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.graphic_eq_rounded,
              color: scheme.onPrimaryContainer,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'StageCommander',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                'v2.0 · MD3 Show Control',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          PopupMenuButton<WorkspaceAction>(
            tooltip: '工程目录与导入导出 (${controller.workspacePath})',
            onSelected: (action) {
              FocusManager.instance.primaryFocus?.unfocus();
              onWorkspaceAction(action);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前工程目录',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      controller.workspacePath,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: WorkspaceAction.switchWorkspace,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.folder_open_rounded),
                  title: Text('切换 / 新建工程目录'),
                ),
              ),
              const PopupMenuItem(
                value: WorkspaceAction.importLegacyJson,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.history_rounded),
                  title: Text('导入旧版 project.json (Beta 8)'),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: WorkspaceAction.exportBundle,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.archive_rounded),
                  title: Text('导出便携演出包 (.zip)'),
                ),
              ),
              const PopupMenuItem(
                value: WorkspaceAction.importBundle,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.unarchive_rounded),
                  title: Text('导入演出包 (.zip)'),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: WorkspaceAction.audioSettings,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.tune_rounded),
                  title: Text('音频参数 (闪避比例 / 淡出时长)'),
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_rounded,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '工程与设置',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Prominent Center Safety Pill
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: bannerBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: bannerBorder, width: 1.2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    armed ? Icons.verified_user_rounded : Icons.lock_rounded,
                    color: bannerFg,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      controller.statusMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: bannerFg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Theme Seed Color Swatch Menu
          PopupMenuButton<Color>(
            tooltip: '切换 Material 3 主题色调',
            onSelected: (color) {
              FocusManager.instance.primaryFocus?.unfocus();
              controller.setSeedColor(color);
            },
            itemBuilder: (context) => [
              for (final preset in StageSeedPreset.presets)
                PopupMenuItem(
                  value: preset.color,
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: preset.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(preset.name),
                      if (controller.settings.seedColorValue ==
                          preset.color.toARGB32()) ...[
                        const Spacer(),
                        const Icon(Icons.check_rounded, size: 18),
                      ],
                    ],
                  ),
                ),
            ],
            icon: const Icon(Icons.palette_outlined),
          ),

          // Dark / Light Mode Toggle
          IconButton(
            tooltip:
                controller.settings.darkMode ? '切换至 MD3 亮色模式' : '切换至 MD3 暗场模式',
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              controller.toggleDarkMode();
            },
            icon: Icon(
              controller.settings.darkMode
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
          ),

          // Keyboard & Workflow Guide
          IconButton(
            tooltip: '快捷键与操作说明',
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              onShowHelp();
            },
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ],
      ),
    );
  }
}
