import 'package:material_ui/material_ui.dart';

import '../../app/theme/md3_theme.dart';
import '../../controllers/stage_controller.dart';

/// Master Material Design 3 action bar housing Add Cue, Batch Import,
/// the Launch-Control Arming Switch (`GO`), Safe Lock, and Emergency Panic (`Esc`).
class StageActionDeck extends StatelessWidget {
  const StageActionDeck({
    super.key,
    required this.controller,
    required this.onAddCue,
    required this.onBatchImport,
  });

  final StageController controller;
  final VoidCallback onAddCue;
  final VoidCallback onBatchImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantics = theme.extension<StageSemanticColors>()!;
    final armed = controller.systemArmed;

    return Card(
      color: scheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Flexible(
              flex: 0,
              child: FilledButton.tonalIcon(
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  onAddCue();
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('添加音效'),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              flex: 0,
              child: OutlinedButton.icon(
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  onBatchImport();
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                icon: const Icon(Icons.audio_file_outlined),
                label: const Text('批量导入'),
              ),
            ),

            const Spacer(),

            if (armed) ...[
              OutlinedButton.icon(
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  controller.disarmSystemSafely();
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                icon: const Icon(Icons.lock_outline_rounded),
                label: const Text('仅锁定'),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: semantics.armedContainer,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: semantics.armedAccent, width: 1.5),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sensors_rounded,
                          color: semantics.onArmedContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'GO · 热键已激活',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: semantics.onArmedContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else
              Flexible(
                child: FilledButton.icon(
                  onPressed: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    controller.armSystem();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: semantics.armedAccent,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'GO · 激活系统 (Space)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),

            const SizedBox(width: 8),

            Flexible(
              child: FilledButton.icon(
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  controller.panicStopAll();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                icon: const Icon(Icons.stop_circle_rounded, size: 20),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '全部停止 (Esc)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onError,
                      fontWeight: FontWeight.w800,
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
}
