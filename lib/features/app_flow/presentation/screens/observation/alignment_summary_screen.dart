import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/ap_widgets.dart';
import '../../../../calibration/presentation/controllers/calibration_controller.dart';
import '../../../application/app_flow_state.dart';
import '../../widgets/mode_scaffold.dart';
import 'observation_shell.dart';

/// Pestaña Alineación una vez terminado el tutorial: estado de cada paso y
/// atajos para repetirlo.
class AlignmentSummaryScreen extends StatelessWidget {
  const AlignmentSummaryScreen({super.key});

  Future<void> _confirmClear(
    BuildContext context,
    CalibrationController calibration,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete, color: ApColors.error),
        title: const Text(
          'Borrar alineación y ajuste fino',
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'Se eliminarán la alineación con la estrella y la corrección del '
          'ajuste fino. La referencia 0 / 0 se mantiene.',
          style: ApText.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ApColors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await calibration.clearCalibration();
  }

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AppFlowState>();
    final calibration = context.watch<CalibrationController>();
    final zeroAt = flow.zeroFixedAt;
    final aligned = calibration.isInitialAligned;
    final star = calibration.initialAlignmentReferenceName;
    final alignedAt = calibration.initialAlignmentTimestamp;
    final correction = calibration.correctionCalibrationResult;
    final hasFine = correction?.hasCorrectionCalibration ?? false;
    final fineStars = correction?.points.map((p) => p.objectName).join(' y ');
    final lost = flow.referenceLost;

    void repeat(ObservationStep step) {
      if (step == ObservationStep.alignment) {
        calibration.startInitialAlignment();
      }
      flow.startTutorialAt(step);
    }

    return Scaffold(
      appBar: const ModeAppBar(title: 'Alineación'),
      body: ModeBody(
        header: const [ReferenceLostBanner()],
        children: [
          const ApCard(
            children: [
              ApCardHead(
                icon: Icons.center_focus_strong,
                title: 'Estado de la alineación',
              ),
              Text(
                'Puedes repetir cualquier paso sin empezar de cero.',
                style: ApText.body,
              ),
            ],
          ),
          _StepCard(
            badge: 'Paso 2 · Nivelación',
            pill: zeroAt != null
                ? const ApPill('0 / 0 fijado ✓', tone: ApTone.ok)
                : const ApPill('Sin 0 / 0', tone: ApTone.error),
            text: zeroAt != null
                ? 'Referencia de horizonte y norte fijada hoy a las '
                      '${formatClock(zeroAt)}.'
                : 'La referencia de horizonte y norte ya no es válida.',
            action: 'Rehacer 0 / 0',
            icon: Icons.restart_alt,
            onAction: () => repeat(ObservationStep.leveling),
          ),
          _StepCard(
            badge: 'Paso 3 · Estrella',
            pill: aligned && !lost
                ? ApPill('Alineado con ${star ?? 'una estrella'} ✓',
                    tone: ApTone.ok)
                : const ApPill('Perdida', tone: ApTone.error),
            text: aligned && !lost
                ? 'Alineado con ${star ?? 'una estrella'}'
                      '${alignedAt == null ? '' : ' a las ${formatClock(alignedAt)}'}.'
                : 'La alineación con la estrella ya no es válida. Repite este '
                      'paso para volver a apuntar con precisión.',
            action: 'Repetir alineación',
            icon: Icons.restart_alt,
            onAction: () => repeat(ObservationStep.alignment),
          ),
          _StepCard(
            badge: 'Paso 4 · Ajuste fino',
            pill: hasFine
                ? ApPill(
                    '${correction!.points.length} '
                    '${correction.points.length == 1 ? 'estrella' : 'estrellas'}',
                    tone: ApTone.info,
                  )
                : const ApPill('Sin ajuste fino', tone: ApTone.warn),
            text: hasFine
                ? 'Corrección con $fineStars.'
                : 'Sin ajuste fino, los objetos podrían no quedar centrados al '
                      'hacer GOTO.',
            action: hasFine ? 'Repetir ajuste fino' : 'Hacer ajuste fino',
            icon: Icons.tune,
            onAction: () => repeat(ObservationStep.fineAdjust),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ApButton(
                label: 'Ver el tutorial desde el paso 1',
                icon: Icons.replay,
                kind: ApButtonKind.text,
                onPressed: () {
                  flow.startTutorialAt(ObservationStep.connection);
                },
              ),
              const SizedBox(height: 10),
              ApButton(
                label: 'Borrar alineación y ajuste fino',
                icon: Icons.delete,
                kind: ApButtonKind.outlined,
                foreground: ApColors.error,
                onPressed: aligned || hasFine
                    ? () => _confirmClear(context, calibration)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String badge;
  final Widget pill;
  final String text;
  final String action;
  final IconData icon;
  final VoidCallback onAction;

  const _StepCard({
    required this.badge,
    required this.pill,
    required this.text,
    required this.action,
    required this.icon,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return ApCard(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [ApStepBadge(badge), pill],
        ),
        Text(text, style: ApText.body),
        ApButton(
          label: action,
          icon: icon,
          kind: ApButtonKind.outlined,
          onPressed: onAction,
        ),
      ],
    );
  }
}
