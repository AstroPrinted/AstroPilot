import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/widgets/ap_widgets.dart';
import '../../../../../oe4_control/presentation/controllers/oe4_control_controller.dart';
import '../../../../application/app_flow_state.dart';
import '../../../widgets/mode_scaffold.dart';
import '../../../widgets/telescope_commands.dart';
import 'step_widgets.dart';

/// Paso 2: nivelar, apuntar al norte y fijar la referencia 0 / 0.
class LevelingStep extends StatefulWidget {
  final VoidCallback onNext;

  const LevelingStep({super.key, required this.onNext});

  @override
  State<LevelingStep> createState() => _LevelingStepState();
}

class _LevelingStepState extends State<LevelingStep> {
  bool _confirming = false;
  bool _redoing = false;
  String? _error;

  Future<void> _fix() async {
    final commands = TelescopeCommands.of(context);
    final flow = context.read<AppFlowState>();
    setState(() {
      _confirming = true;
      _error = null;
    });
    try {
      await commands.setManualReference(0, 0);
      flow.markZeroFixed();
      _redoing = false;
    } catch (error) {
      _error = errorText(error);
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fixed = context.select<AppFlowState, bool>((s) => s.isZeroFixed);
    final oe4 = context.watch<Oe4ControlController>();
    final position = oe4.telescopePosition;
    final showFixed = fixed && !_redoing;

    return ModeBody(
      children: [
        ApCard(
          children: [
            const ApStepBadge('Paso 2 de 5'),
            const Text('Nivela y fija el punto 0 / 0', style: ApText.title),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: ApColors.surface2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const AspectRatio(
                aspectRatio: 320 / 120,
                child: CustomPaint(painter: _LevelingPainter()),
              ),
            ),
            const NumberedSteps(
              items: [
                'Pon el telescopio lo más horizontal que puedas.',
                'Apúntalo hacia el norte. Sugerencia: usa la brújula del celular.',
                'Presiona "Fijar 0 / 0".',
              ],
            ),
          ],
        ),
        ApCard(
          children: [
            const ApCardHead(
              icon: Icons.my_location,
              title: 'Posición del telescopio',
            ),
            ApTiles(
              tiles: [
                ApTile(label: 'Altitud', value: formatDeg(position?.altitude)),
                ApTile(label: 'Azimut', value: formatDeg(position?.azimuth)),
              ],
            ),
          ],
        ),
        if (_error != null)
          ApNotice(icon: Icons.error_outline, tone: ApTone.error, text: _error!),
        if (showFixed) ...[
          const ApNotice(
            icon: Icons.check_circle,
            tone: ApTone.ok,
            text: 'Referencia 0 / 0 fijada ✓',
          ),
          ApButton(
            label: 'Siguiente',
            icon: Icons.arrow_forward,
            iconAfter: true,
            large: true,
            onPressed: widget.onNext,
          ),
          ApButton(
            label: 'Volver a fijar',
            kind: ApButtonKind.text,
            onPressed: () => setState(() => _redoing = true),
          ),
        ] else
          ApButton(
            label: _confirming ? 'Confirmando…' : 'Fijar 0 / 0',
            icon: Icons.push_pin,
            large: true,
            busy: _confirming,
            onPressed: oe4.isSending ? null : _fix,
          ),
        const ApInfoLine(
          text:
              'Este paso le dice al telescopio dónde está el horizonte y el '
              'norte. Así, en el paso siguiente el telescopio puede acercarse '
              'a la estrella por sí solo.',
        ),
      ],
    );
  }
}

/// Telescopio horizontal apuntando al norte (ilustración del diseño).
class _LevelingPainter extends CustomPainter {
  const _LevelingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 320, size.height / 120);
    Paint stroke(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    void dashed(Offset a, Offset b, Paint paint, double dash, double gap) {
      final total = (b - a).distance;
      final direction = (b - a) / total;
      var d = 0.0;
      while (d < total) {
        final end = (d + dash).clamp(0, total).toDouble();
        canvas.drawLine(a + direction * d, a + direction * end, paint);
        d += dash + gap;
      }
    }

    void label(String text, Offset at, Color color, {bool mono = false}) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontFamily: mono ? ApText.mono : null,
            fontWeight: text == 'N' ? FontWeight.w600 : null,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, at - Offset(painter.width / 2, painter.height));
    }

    final horizon = stroke(ApColors.muted.withValues(alpha: 0.4));
    dashed(const Offset(16, 104), const Offset(304, 104), horizon, 4, 6);
    final hint = TextPainter(
      text: const TextSpan(
        text: 'horizonte',
        style: TextStyle(color: ApColors.muted, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    hint.paint(canvas, Offset(16, 96 - hint.height));

    final legs = stroke(ApColors.muted);
    canvas.drawLine(const Offset(104, 68), const Offset(86, 104), legs);
    canvas.drawLine(const Offset(104, 68), const Offset(122, 104), legs);
    canvas.drawLine(const Offset(104, 68), const Offset(104, 104), legs);

    final tube = stroke(ApColors.secondary);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(56, 50, 104, 18),
        const Radius.circular(4),
      ),
      tube,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(160, 47, 12, 24),
        const Radius.circular(3),
      ),
      tube,
    );

    final arrow = stroke(ApColors.primary);
    dashed(const Offset(184, 59), const Offset(262, 59), arrow, 5, 5);
    canvas.drawPath(
      Path()
        ..moveTo(256, 53)
        ..lineTo(264, 59)
        ..lineTo(256, 65),
      arrow,
    );
    canvas.drawCircle(const Offset(288, 59), 14, arrow);
    label('N', const Offset(288, 66), ApColors.text);
    label('alt 0°', const Offset(108, 40), ApColors.secondary, mono: true);
    label('az 0°', const Offset(222, 48), ApColors.primary, mono: true);
  }

  @override
  bool shouldRepaint(_LevelingPainter oldDelegate) => false;
}
