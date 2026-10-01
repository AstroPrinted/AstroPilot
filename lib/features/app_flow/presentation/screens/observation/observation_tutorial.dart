import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/widgets/ap_widgets.dart';
import '../../../application/app_flow_state.dart';
import '../../widgets/mode_scaffold.dart';
import 'observation_progress.dart';
import 'observation_shell.dart';
import 'steps/connection_step.dart';
import 'steps/fine_adjust_step.dart';
import 'steps/leveling_step.dart';
import 'steps/star_alignment_step.dart';

/// Tutorial de Observación (pasos 1 a 4) con el indicador de progreso. El
/// paso 5 es la pestaña Catálogo.
class ObservationTutorial extends StatelessWidget {
  /// La pestaña Conexión muestra siempre el paso 1.
  final bool connectionOnly;

  const ObservationTutorial({super.key, this.connectionOnly = false});

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AppFlowState>();
    final progress = ObservationProgress.watch(context);
    var step = connectionOnly ? ObservationStep.connection : flow.tutorialStep;
    if (step == ObservationStep.catalog) step = ObservationStep.fineAdjust;

    void goTo(ObservationStep next) {
      if (next == ObservationStep.catalog) {
        flow.completeTutorial();
        flow.requestTab(ObservationTab.catalog);
        return;
      }
      flow.setTutorialStep(next);
      if (connectionOnly && next != ObservationStep.connection) {
        flow.requestTab(ObservationTab.alignment);
      }
    }

    return Scaffold(
      appBar: ModeAppBar(title: step.label),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ApStepper(
            labels: [for (final s in ObservationStep.values) s.label],
            states: progress.stepStates(step),
            onTap: (i) {
              final target = ObservationStep.values[i];
              if (progress.canOpen(target)) goTo(target);
            },
          ),
          const ReferenceLostBanner(),
          Expanded(
            child: switch (step) {
              ObservationStep.connection => ConnectionStep(
                progress: progress,
                onNext: () => goTo(ObservationStep.leveling),
              ),
              ObservationStep.leveling => LevelingStep(
                onNext: () => goTo(ObservationStep.alignment),
              ),
              ObservationStep.alignment => StarAlignmentStep(
                progress: progress,
                onNext: () => goTo(ObservationStep.fineAdjust),
                onGoToLeveling: () => goTo(ObservationStep.leveling),
              ),
              _ => FineAdjustStep(
                onFinish: () => goTo(ObservationStep.catalog),
              ),
            },
          ),
        ],
      ),
    );
  }
}
