import 'package:desktop_drop/desktop_drop.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/md3_theme.dart';
import '../../controllers/stage_controller.dart';
import '../../models/show_models.dart';

/// Center Stage Cue Console with drag-and-drop import, search filtering,
/// duplicate-hotkey detection, reordering, and MD3 state-layered rows.
class CueListView extends StatefulWidget {
  const CueListView({
    super.key,
    required this.controller,
    required this.onAddCue,
    required this.onEditCue,
    required this.onDeleteCue,
  });

  final StageController controller;
  final VoidCallback onAddCue;
  final ValueChanged<CueItem> onEditCue;
  final ValueChanged<CueItem> onDeleteCue;

  @override
  State<CueListView> createState() => _CueListViewState();
}

class _CueListViewState extends State<CueListView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isDragOver = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final scene = controller.activeScene;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (_searchController.text != controller.searchQuery) {
      _searchController.value = TextEditingValue(
        text: controller.searchQuery,
        selection: TextSelection.collapsed(
          offset: controller.searchQuery.length,
        ),
      );
    }

    final cues = controller.filteredCues();
    final duplicates = scene?.duplicateHotkeyCodes() ?? const <String>{};
    final canReorder = controller.searchQuery.trim().isEmpty;

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragOver = true),
      onDragExited: (_) => setState(() => _isDragOver = false),
      onDragDone: (details) async {
        setState(() => _isDragOver = false);
        final paths = details.files.map((f) => f.path).toList();
        final added = await controller.importAudioFilesAsCues(paths);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              added > 0
                  ? '已导入 $added 个音频文件到「${scene?.name ?? ''}」'
                  : '未检测到支持的音频文件 (${kSupportedAudioExtensions.join(', ')})',
            ),
          ),
        );
      },
      child: Card(
        color: scheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildToolbar(context, scene, duplicates),
                const Divider(height: 1),
                _buildColumnHeader(context),
                const Divider(height: 1),
                Expanded(
                  child: cues.isEmpty
                      ? _buildEmptyState(context, scene)
                      : _buildCueList(
                          context,
                          cues: cues,
                          duplicates: duplicates,
                          canReorder: canReorder,
                        ),
                ),
              ],
            ),
            if (_isDragOver)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: scheme.primary, width: 2),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.audio_file_rounded,
                            size: 48,
                            color: scheme.onPrimaryContainer,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '松开鼠标即可导入音频到「${scene?.name ?? ''}」',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '支持 MP3 / WAV / OGG / FLAC / Opus',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    SceneAct? scene,
    Set<String> duplicates,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        scene?.name ?? '剧幕控制台',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${scene?.cues.length ?? 0} 条 Cue',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (duplicates.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message: '当前幕存在重复热键，请点击对应音效调整以避免同时误触发',
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 14,
                                color: scheme.onErrorContainer,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '热键冲突',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onErrorContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '双击行编辑配置 · 拖拽排序 · 支持从文件夹直接拖入音频',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 0,
            child: SizedBox(
              width: 210,
              child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: widget.controller.setSearchQuery,
              onSubmitted: (_) => _searchFocusNode.unfocus(),
              style: theme.textTheme.bodySmall,
              decoration: InputDecoration(
                isDense: true,
                hintText: '筛选名称 / 热键 / 备注...',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: widget.controller.searchQuery.isNotEmpty
                    ? IconButton(
                        tooltip: '清除筛选',
                        icon: const Icon(Icons.close_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          widget.controller.setSearchQuery('');
                          _searchFocusNode.unfocus();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: scheme.outlineVariant),
                ),
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnHeader(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );

    return Container(
      color: theme.colorScheme.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          const SizedBox(width: 24),
          SizedBox(width: 32, child: Text('#', style: style)),
          Expanded(flex: 5, child: Text('音效名称与源文件', style: style)),
          SizedBox(width: 76, child: Text('模式', style: style)),
          SizedBox(width: 72, child: Center(child: Text('热键', style: style))),
          SizedBox(width: 50, child: Center(child: Text('音量', style: style))),
          SizedBox(width: 84, child: Center(child: Text('状态', style: style))),
          SizedBox(width: 136, child: Center(child: Text('控制与操作', style: style))),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, SceneAct? scene) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasQuery = widget.controller.searchQuery.trim().isNotEmpty;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                hasQuery
                    ? Icons.search_off_rounded
                    : Icons.library_music_rounded,
                size: 32,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              hasQuery
                  ? '没有匹配 “${widget.controller.searchQuery}” 的音效'
                  : '「${scene?.name ?? '当前幕'}」暂无音效',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasQuery
                  ? '清空筛选词即可恢复全部剧目列表'
                  : '点击下方“添加音效”或直接拖入音频文件即可自动归档至 Media 目录',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (hasQuery)
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  widget.controller.setSearchQuery('');
                  _searchFocusNode.unfocus();
                },
                icon: const Icon(Icons.clear_rounded),
                label: const Text('清空筛选'),
              )
            else
              FilledButton.tonalIcon(
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  widget.onAddCue();
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('添加首条音效'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCueList(
    BuildContext context, {
    required List<CueItem> cues,
    required Set<String> duplicates,
    required bool canReorder,
  }) {
    if (canReorder) {
      return ReorderableListView.builder(
        buildDefaultDragHandles: false,
        itemCount: cues.length,
        onReorderItem: widget.controller.reorderCue,
        itemBuilder: (context, index) => _CueRow(
          key: ValueKey(cues[index].id),
          index: index,
          cue: cues[index],
          canReorder: true,
          hasConflict: duplicates.contains(cues[index].hotkeyCode),
          controller: widget.controller,
          onEdit: () => widget.onEditCue(cues[index]),
          onDelete: () => widget.onDeleteCue(cues[index]),
        ),
      );
    }

    return ListView.builder(
      itemCount: cues.length,
      itemBuilder: (context, index) => _CueRow(
        key: ValueKey(cues[index].id),
        index: index,
        cue: cues[index],
        canReorder: false,
        hasConflict: duplicates.contains(cues[index].hotkeyCode),
        controller: widget.controller,
        onEdit: () => widget.onEditCue(cues[index]),
        onDelete: () => widget.onDeleteCue(cues[index]),
      ),
    );
  }
}

class _CueRow extends StatelessWidget {
  const _CueRow({
    super.key,
    required this.index,
    required this.cue,
    required this.canReorder,
    required this.hasConflict,
    required this.controller,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final CueItem cue;
  final bool canReorder;
  final bool hasConflict;
  final StageController controller;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantics = theme.extension<StageSemanticColors>()!;

    final bgm = controller.bgmState;
    final isBgmTrack = cue.mode == CueMode.bgm && bgm.cueId == cue.id;
    final isPlaying = isBgmTrack
        ? bgm.isPlaying
        : controller.playingCueIds.contains(cue.id);
    final isPaused = isBgmTrack && bgm.isPaused;
    final fileExists = controller.isCueFilePresent(cue);

    final rowBg = isPlaying
        ? semantics.armedContainer.withValues(alpha: 0.24)
        : (index.isOdd
            ? scheme.surfaceContainer.withValues(alpha: 0.45)
            : Colors.transparent);

    return Material(
      color: rowBg,
      child: InkWell(
        onDoubleTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
          onEdit();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.45),
                width: 0.8,
              ),
            ),
          ),
          child: Row(
            children: [
              if (canReorder)
                ReorderableDragStartListener(
                  index: index,
                  child: SizedBox(
                    width: 24,
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      size: 18,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                )
              else
                const SizedBox(width: 24),

              // Index
              SizedBox(
                width: 32,
                child: Text(
                  '${index + 1}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),

              // Title & Source Filename
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              cue.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (cue.loop) ...[
                            const SizedBox(width: 6),
                            Tooltip(
                              message: '循环播放',
                              child: Icon(
                                Icons.repeat_rounded,
                                size: 15,
                                color: scheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (!fileExists)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.error_outline_rounded,
                                size: 13,
                                color: scheme.error,
                              ),
                            ),
                          Flexible(
                            child: Text(
                              fileExists
                                  ? (cue.notes.isNotEmpty
                                      ? '${controller.resolveCueDisplayFileName(cue)} · ${cue.notes}'
                                      : controller.resolveCueDisplayFileName(cue))
                                  : '缺失文件: ${controller.resolveCueDisplayFileName(cue)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: fileExists
                                    ? scheme.onSurfaceVariant
                                    : scheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Mode Badge
              SizedBox(
                width: 76,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cue.mode == CueMode.bgm
                          ? semantics.bgmContainer
                          : semantics.sfxContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          cue.mode == CueMode.bgm
                              ? Icons.music_note_rounded
                              : Icons.bolt_rounded,
                          size: 13,
                          color: cue.mode == CueMode.bgm
                              ? semantics.onBgmContainer
                              : semantics.onSfxContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          cue.mode == CueMode.bgm ? 'BGM' : 'SFX',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cue.mode == CueMode.bgm
                                ? semantics.onBgmContainer
                                : semantics.onSfxContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Hotkey Keycap
              SizedBox(
                width: 72,
                child: Center(
                  child: cue.hasHotkey
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: hasConflict
                                ? scheme.errorContainer
                                : scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: hasConflict
                                  ? scheme.error
                                  : scheme.outlineVariant,
                            ),
                          ),
                          child: Text(
                            cue.hotkeyLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: hasConflict
                                  ? scheme.onErrorContainer
                                  : scheme.primary,
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        )
                      : Text(
                          '—',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                ),
              ),

              // Volume %
              SizedBox(
                width: 50,
                child: Center(
                  child: Text(
                    '${cue.volumePercent}%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),

              // Live Status Pill
              SizedBox(
                width: 84,
                child: Center(
                  child: _StatusChip(
                    isPlaying: isPlaying,
                    isPaused: isPaused,
                  ),
                ),
              ),

              // Controls
              SizedBox(
                width: 136,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: controller.systemArmed ? '立即触发' : '试听 (未解锁预览)',
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: const Size(32, 32),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: fileExists
                          ? () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              controller.triggerCue(cue, bypassArmCheck: true);
                            }
                          : null,
                      icon: Icon(
                        Icons.play_arrow_rounded,
                        size: 20,
                        color: fileExists ? scheme.primary : null,
                      ),
                    ),
                    IconButton(
                      tooltip: '停止此音效',
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: const Size(32, 32),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: (isPlaying || isPaused)
                          ? () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              controller.stopCue(cue);
                            }
                          : null,
                      icon: Icon(
                        Icons.stop_rounded,
                        size: 20,
                        color: (isPlaying || isPaused) ? scheme.error : null,
                      ),
                    ),
                    IconButton(
                      tooltip: '编辑音效配置',
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: const Size(32, 32),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        onEdit();
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                    ),
                    IconButton(
                      tooltip: '删除此音效',
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: const Size(32, 32),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        onDelete();
                      },
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isPlaying, required this.isPaused});

  final bool isPlaying;
  final bool isPaused;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantics = theme.extension<StageSemanticColors>()!;

    if (isPlaying) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: semantics.armedContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.graphic_eq_rounded,
              size: 14,
              color: semantics.onArmedContainer,
            ),
            const SizedBox(width: 4),
            Text(
              '播放中',
              style: theme.textTheme.labelSmall?.copyWith(
                color: semantics.onArmedContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    if (isPaused) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: semantics.duckingContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '已暂停',
          style: theme.textTheme.labelSmall?.copyWith(
            color: semantics.onDuckingContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Text(
      '待命',
      style: theme.textTheme.labelSmall?.copyWith(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
      ),
    );
  }
}
