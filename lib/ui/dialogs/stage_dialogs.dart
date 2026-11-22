import 'package:material_ui/material_ui.dart';

/// Prompts for creating or renaming a stage act.
Future<String?> showActNameDialog(
  BuildContext context, {
  required String title,
  required String initialName,
}) async {
  final textController = TextEditingController(text: initialName);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '剧幕名称',
            hintText: '例如：第一幕 · 序曲',
          ),
          onSubmitted: (val) => Navigator.of(context).pop(val.trim()),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(textController.text.trim()),
          child: const Text('确定'),
        ),
      ],
    ),
  );
  textController.dispose();
  return (result != null && result.isNotEmpty) ? result : null;
}

/// Reusable Material Design 3 destructive confirmation dialog.
Future<bool> showStageConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '确认删除',
}) async {
  final scheme = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(width: 380, child: Text(message)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Audio settings dialog for ducking ratio and BGM crossfade duration.
Future<({double duckRatio, int crossfadeMs})?> showAudioSettingsDialog(
  BuildContext context, {
  required double initialDuckRatio,
  required int initialCrossfadeMs,
}) async {
  var duck = initialDuckRatio;
  var fade = initialCrossfadeMs.toDouble();

  return showDialog<({double duckRatio, int crossfadeMs})>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('音频引擎与播控参数'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('台词闪避目标比例', style: theme.textTheme.labelLarge),
                    const Spacer(),
                    Text(
                      '${(duck * 100).round()}%',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: duck,
                  min: 0.10,
                  max: 0.70,
                  divisions: 12,
                  onChanged: (v) => setState(() => duck = v),
                ),
                Text(
                  '开启“台词闪避”时，正在播放的 BGM 将平滑衰减至该比例（默认 30%）',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('BGM 切歌淡出时长', style: theme.textTheme.labelLarge),
                    const Spacer(),
                    Text(
                      fade == 0 ? '瞬切 (0ms)' : '${fade.round()}ms',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: fade,
                  min: 0,
                  max: 1500,
                  divisions: 15,
                  onChanged: (v) => setState(() => fade = v),
                ),
                Text(
                  '播放新 BGM 或停止当前 BGM 时的平滑淡出时间，紧急 Panic 始终瞬断',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop((
                duckRatio: duck,
                crossfadeMs: fade.round(),
              )),
              child: const Text('保存参数'),
            ),
          ],
        );
      },
    ),
  );
}

/// Shows StageCommander's live safety workflow and shortcut cheat sheet.
Future<void> showShortcutsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield_rounded),
            SizedBox(width: 10),
            Text('舞台播控安全逻辑与快捷键'),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _ShortcutRow(
                keycap: 'Space',
                title: '发射台激活开关 (GO / Arm)',
                subtitle: '软件默认处于红色锁定态防止误触；按下空格或点击 GO 后才响应当前幕快捷键。',
              ),
              SizedBox(height: 10),
              _ShortcutRow(
                keycap: 'Esc',
                title: '紧急全停 + 立即上锁 (Panic)',
                subtitle: '演出意外时一键瞬断所有 BGM 与音效输出，并强制退回锁定态。',
              ),
              SizedBox(height: 10),
              _ShortcutRow(
                keycap: '1..9 / A..Z / F1..F12',
                title: '分幕物理热键触发',
                subtitle: '仅在激活状态下响应当前所选幕的音效；基于物理键位识别，中文输入法下同样 100% 触发。',
              ),
              SizedBox(height: 10),
              _ShortcutRow(
                keycap: 'BGM vs SFX',
                title: '独占背景 vs 单例重触发',
                subtitle: 'BGM 全局同时仅播一首并支持波形拖拽与 30% 台词闪避；同条 SFX 连按立即重头触发，多条不同 SFX 可叠加混音。',
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
            ),
            child: const Text('知道了'),
          ),
        ],
      );
    },
  );
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.keycap,
    required this.title,
    required this.subtitle,
  });

  final String keycap;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 74),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Text(
            keycap,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
