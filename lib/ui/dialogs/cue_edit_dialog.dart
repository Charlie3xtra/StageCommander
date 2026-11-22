import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../../controllers/stage_controller.dart';
import '../../models/show_models.dart';
import '../../services/hotkey_mapper.dart';

/// Material Design 3 modal editor for creating or modifying a stage cue.
class CueEditDialog extends StatefulWidget {
  const CueEditDialog({
    super.key,
    this.initialCue,
    required this.existingCuesInScene,
  });

  final CueItem? initialCue;
  final List<CueItem> existingCuesInScene;

  @override
  State<CueEditDialog> createState() => _CueEditDialogState();
}

class _CueEditDialogState extends State<CueEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _pathController;
  late final TextEditingController _notesController;
  final FocusNode _recorderFocusNode = FocusNode();

  late CueMode _mode;
  late double _volume;
  late String _hotkeyCode;
  late String _hotkeyLabel;
  late bool _loop;
  late int _fadeOutMs;
  bool _isRecordingKey = false;
  String? _recorderFeedback;

  @override
  void initState() {
    super.initState();
    final cue = widget.initialCue;
    _nameController = TextEditingController(text: cue?.name ?? '');
    _pathController = TextEditingController(text: cue?.filePath ?? '');
    _notesController = TextEditingController(text: cue?.notes ?? '');
    _mode = cue?.mode ?? CueMode.sfx;
    _volume = cue?.volume ?? 1.0;
    _hotkeyCode = cue?.hotkeyCode ?? '';
    _hotkeyLabel = cue?.hotkeyLabel ?? '';
    _loop = cue?.loop ?? false;
    _fadeOutMs = cue?.fadeOutMs ?? (_mode == CueMode.bgm ? 200 : 0);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pathController.dispose();
    _notesController.dispose();
    _recorderFocusNode.dispose();
    super.dispose();
  }

  String? _findConflictingCueName() {
    if (_hotkeyCode.isEmpty) return null;
    for (final other in widget.existingCuesInScene) {
      if (other.id == widget.initialCue?.id) continue;
      if (other.hotkeyCode == _hotkeyCode) return other.name;
    }
    return null;
  }

  Future<void> _pickAudioFile() async {
    final picked = await FilePicker.pickFile(
      dialogTitle: '选择舞台音频文件',
      type: FileType.custom,
      allowedExtensions: kSupportedAudioExtensions,
    );
    if (picked?.path == null || !mounted) return;
    final pathStr = picked!.path!;
    setState(() {
      _pathController.text = pathStr;
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = p.basenameWithoutExtension(pathStr);
      }
    });
  }

  KeyEventResult _handleRecorderKey(FocusNode node, KeyEvent event) {
    if (!_isRecordingKey || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (HotkeyMapper.isReservedSafetyKey(event)) {
      setState(() {
        _isRecordingKey = false;
        _recorderFeedback = 'Space (激活) 与 Esc (紧急全停) 为系统保留安全键，不可绑定';
      });
      return KeyEventResult.handled;
    }

    final parsed = HotkeyMapper.fromKeyEvent(event);
    if (parsed == null) {
      return KeyEventResult.handled;
    }

    setState(() {
      _hotkeyCode = parsed.code;
      _hotkeyLabel = parsed.label;
      _isRecordingKey = false;
      _recorderFeedback = null;
    });
    return KeyEventResult.handled;
  }

  void _save() {
    final path = _pathController.text.trim();
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : (path.isNotEmpty ? p.basenameWithoutExtension(path) : '未命名音效');

    final result = CueItem(
      id: widget.initialCue?.id ?? '',
      name: name,
      filePath: path,
      mode: _mode,
      volume: _volume,
      hotkeyCode: _hotkeyCode,
      hotkeyLabel: _hotkeyLabel,
      loop: _loop,
      fadeOutMs: _fadeOutMs,
      notes: _notesController.text.trim(),
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final conflictName = _findConflictingCueName();
    final isEdit = widget.initialCue != null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isEdit ? Icons.tune_rounded : Icons.add_circle_outline_rounded,
            color: scheme.primary,
          ),
          const SizedBox(width: 10),
          Text(isEdit ? '编辑音效配置' : '添加新音效'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '音效标题',
                  hintText: '例如：演员入场 / 雷声 / 序曲',
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pathController,
                      decoration: const InputDecoration(
                        labelText: '音频文件',
                        hintText: '支持 MP3 / WAV / OGG / FLAC / Opus',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.tonalIcon(
                    onPressed: _pickAudioFile,
                    icon: const Icon(Icons.folder_open_rounded),
                    label: const Text('浏览'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Mode Selector (Strict MD3 SegmentedButton)
              Text(
                '播放模式',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<CueMode>(
                segments: const [
                  ButtonSegment<CueMode>(
                    value: CueMode.bgm,
                    icon: Icon(Icons.music_note_rounded),
                    label: Text('BGM · 独占背景'),
                  ),
                  ButtonSegment<CueMode>(
                    value: CueMode.sfx,
                    icon: Icon(Icons.bolt_rounded),
                    label: Text('SFX · 单例重触发'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (set) {
                  setState(() {
                    _mode = set.first;
                    if (_mode == CueMode.bgm && _fadeOutMs == 0) {
                      _fadeOutMs = 200;
                    }
                  });
                },
              ),
              const SizedBox(height: 16),

              // Interactive Hotkey Recorder
              Text(
                '当前幕热键 (无视中文输入法)',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Focus(
                focusNode: _recorderFocusNode,
                onKeyEvent: _handleRecorderKey,
                onFocusChange: (hasFocus) {
                  if (!hasFocus && _isRecordingKey) {
                    setState(() => _isRecordingKey = false);
                  }
                },
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() {
                            _isRecordingKey = true;
                            _recorderFeedback = null;
                          });
                          _recorderFocusNode.requestFocus();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _isRecordingKey
                                ? scheme.primaryContainer
                                : scheme.surfaceContainerHighest.withValues(
                                    alpha: 0.55,
                                  ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isRecordingKey
                                  ? scheme.primary
                                  : (conflictName != null
                                      ? scheme.error
                                      : scheme.outlineVariant),
                              width: _isRecordingKey ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isRecordingKey
                                    ? Icons.keyboard_alt_rounded
                                    : Icons.keyboard_rounded,
                                size: 18,
                                color: _isRecordingKey
                                    ? scheme.onPrimaryContainer
                                    : scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _isRecordingKey
                                    ? '请按下目标按键 (如 1、A、F1)...'
                                    : (_hotkeyCode.isEmpty
                                        ? '点击此处录入快捷键'
                                        : '已绑定按键: $_hotkeyLabel'),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: _isRecordingKey
                                      ? scheme.onPrimaryContainer
                                      : scheme.onSurface,
                                  fontWeight: _hotkeyCode.isNotEmpty
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_hotkeyCode.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        tooltip: '清除热键',
                        onPressed: () {
                          setState(() {
                            _hotkeyCode = '';
                            _hotkeyLabel = '';
                            _recorderFeedback = null;
                          });
                        },
                        icon: const Icon(Icons.backspace_outlined, size: 18),
                      ),
                    ],
                  ],
                ),
              ),
              if (_recorderFeedback != null) ...[
                const SizedBox(height: 6),
                Text(
                  _recorderFeedback!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.error,
                  ),
                ),
              ] else if (conflictName != null) ...[
                const SizedBox(height: 6),
                Text(
                  '⚠ 提示：按键「$_hotkeyLabel」与本幕中的「$conflictName」重复',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Preset Volume
              Row(
                children: [
                  Text('预设音量', style: theme.textTheme.labelLarge),
                  const Spacer(),
                  Text(
                    '${(_volume * 100).round()}%',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              Slider(
                value: _volume,
                onChanged: (v) => setState(() => _volume = v),
              ),

              // Fade Out + Loop
              Row(
                children: [
                  Text('单条停止淡出', style: theme.textTheme.labelLarge),
                  const Spacer(),
                  Text(
                    _fadeOutMs == 0 ? '瞬断 (0ms)' : '${_fadeOutMs}ms',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              Slider(
                value: _fadeOutMs.toDouble(),
                min: 0,
                max: 2000,
                divisions: 20,
                onChanged: (v) => setState(() => _fadeOutMs = v.round()),
              ),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('循环播放 (Loop)'),
                subtitle: Text(
                  _mode == CueMode.bgm ? '适用于舞台持续氛围/垫乐' : '重复循环直至手动停止',
                  style: theme.textTheme.bodySmall,
                ),
                value: _loop,
                onChanged: (v) => setState(() => _loop = v),
              ),

              const SizedBox(height: 6),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: '场务卡点备注 (可选)',
                  hintText: '例如：主角说完“再见”后第2秒进',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _pathController.text.trim().isEmpty ? null : _save,
          icon: const Icon(Icons.check_rounded),
          label: const Text('确定保存'),
        ),
      ],
    );
  }
}
