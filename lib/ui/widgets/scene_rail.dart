import 'package:material_ui/material_ui.dart';

import '../../app/theme/md3_theme.dart';
import '../../controllers/stage_controller.dart';
import '../../models/show_models.dart';

enum _SceneMenuAction { rename, duplicate, delete }

/// Left Material Design 3 navigation rail for switching, reordering, renaming,
/// duplicating, and creating isolated stage acts/scenes.
class SceneRail extends StatelessWidget {
  const SceneRail({
    super.key,
    required this.controller,
    required this.onAddScene,
    required this.onRenameScene,
    required this.onDeleteScene,
  });

  final StageController controller;
  final VoidCallback onAddScene;
  final void Function(int index, SceneAct scene) onRenameScene;
  final void Function(int index, SceneAct scene) onDeleteScene;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantics = theme.extension<StageSemanticColors>()!;
    final scenes = controller.scenes;
    final playingIds = controller.playingCueIds;

    return Card(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.theaters_rounded,
                    size: 20,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '剧幕列表',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${scenes.length} 幕',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: scenes.length,
                onReorderItem: (oldIndex, newIndex) {
                  controller.moveScene(oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  final scene = scenes[index];
                  final selected = index == controller.activeSceneIndex;
                  final hasPlaying = scene.cues.any(
                    (cue) => playingIds.contains(cue.id),
                  );

                  return _SceneTile(
                    key: ValueKey(scene.id),
                    index: index,
                    scene: scene,
                    selected: selected,
                    hasPlaying: hasPlaying,
                    armedAccent: semantics.armedAccent,
                    onTap: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      controller.selectScene(index);
                    },
                    onMenuAction: (action) {
                      FocusManager.instance.primaryFocus?.unfocus();
                      switch (action) {
                        case _SceneMenuAction.rename:
                          onRenameScene(index, scene);
                        case _SceneMenuAction.duplicate:
                          controller.duplicateScene(index);
                        case _SceneMenuAction.delete:
                          onDeleteScene(index, scene);
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                onAddScene();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('新建一幕'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SceneTile extends StatelessWidget {
  const _SceneTile({
    super.key,
    required this.index,
    required this.scene,
    required this.selected,
    required this.hasPlaying,
    required this.armedAccent,
    required this.onTap,
    required this.onMenuAction,
  });

  final int index;
  final SceneAct scene;
  final bool selected;
  final bool hasPlaying;
  final Color armedAccent;
  final VoidCallback onTap;
  final ValueChanged<_SceneMenuAction> onMenuAction;

  Future<void> _showContextMenu(BuildContext context, Offset globalPos) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final picked = await showMenu<_SceneMenuAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPos.dx, globalPos.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: _buildMenuItems(),
    );
    if (picked != null) onMenuAction(picked);
  }

  List<PopupMenuEntry<_SceneMenuAction>> _buildMenuItems() => const [
        PopupMenuItem(
          value: _SceneMenuAction.rename,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.edit_rounded),
            title: Text('重命名'),
          ),
        ),
        PopupMenuItem(
          value: _SceneMenuAction.duplicate,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.copy_rounded),
            title: Text('复制此幕'),
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: _SceneMenuAction.delete,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.delete_outline_rounded),
            title: Text('删除此幕'),
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = selected ? scheme.onSecondaryContainer : scheme.onSurface;
    final subFg =
        selected ? scheme.onSecondaryContainer.withValues(alpha: 0.78) : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GestureDetector(
        onSecondaryTapUp: (details) =>
            _showContextMenu(context, details.globalPosition),
        child: Material(
          color: selected ? scheme.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        size: 16,
                        color: subFg.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (hasPlaying)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: armedAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scene.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: fg,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${scene.cues.length} 条音效',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: subFg,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<_SceneMenuAction>(
                    tooltip: '剧幕操作',
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 18,
                      color: subFg,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onSelected: onMenuAction,
                    itemBuilder: (_) => _buildMenuItems(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
