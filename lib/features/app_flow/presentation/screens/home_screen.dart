import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ap_widgets.dart';
import '../../../calibration/presentation/controllers/calibration_controller.dart';
import '../../../settings/application/settings_service.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../application/app_flow_state.dart';
import '../widgets/telescope_icon.dart';
import 'education/education_shell.dart';
import 'observation/observation_shell.dart';

/// Inicio: elección de modo.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static void openSettings(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  static void openObservation(BuildContext context, {ObservationTab? tab}) {
    final flow = context.read<AppFlowState>();
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.popUntil((r) => r.isFirst);
    // After closing any open mode, so only the new screen takes the request.
    if (tab != null) flow.requestTab(tab);
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const ObservationShell()),
    );
  }

  static void openEducation(BuildContext context) {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.popUntil((r) => r.isFirst);
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const EducationShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calibration = context.watch<CalibrationController>();
    final settings = context.watch<SettingsService>().state;
    final aligned = calibration.isInitialAligned;
    final star = calibration.initialAlignmentReferenceName;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Configuración',
            icon: const Icon(Icons.settings),
            onPressed: () => openSettings(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const Column(
            children: [
              AppLogo(size: 68),
              SizedBox(height: 10),
              Text(
                'AstroPilot',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: ApColors.text,
                ),
              ),
              SizedBox(height: 10),
              Text('¿Qué quieres hacer hoy?', style: ApText.body),
            ],
          ),
          const SizedBox(height: 20),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ModeCard(
                    icon: const TelescopeIcon(
                      size: 30,
                      color: ApColors.primary,
                      sparkle: false,
                      strokeWidth: 1.8,
                    ),
                    tint: ApColors.primary,
                    title: 'Observación',
                    description:
                        'Alinea el telescopio y apunta a objetos del cielo',
                    badge: aligned
                        ? ApPill(
                            'Alineado con ${star ?? 'una estrella'} ✓',
                            tone: ApTone.ok,
                            small: true,
                          )
                        : null,
                    action: aligned ? 'Continuar observando' : 'Empezar',
                    onTap: () => openObservation(
                      context,
                      tab: aligned ? ObservationTab.catalog : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ModeCard(
                    icon: const Icon(
                      Icons.school,
                      size: 28,
                      color: ApColors.secondary,
                    ),
                    tint: ApColors.secondary,
                    title: 'Educativo',
                    description:
                        'Aprende sobre astros, satélites y responde el quiz',
                    action: 'Explorar',
                    onTap: () => openEducation(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ApCard(
            gap: 10,
            children: [
              _InfoRow(
                label: 'Ubicación',
                value:
                    '${settings.latDeg.toStringAsFixed(4)}, '
                    '${settings.lonDeg.toStringAsFixed(4)}',
                mono: true,
              ),
              if (settings.isCustomTime)
                _InfoRow(
                  label: 'Hora',
                  value: 'Planificando: ${_formatLocal(settings.observerTime)}',
                )
              else
                const _PhoneClockRow(),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatLocal(DateTime utc) {
    final t = utc.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)}/${t.year} ${two(t.hour)}:${two(t.minute)}';
  }
}

class _ModeCard extends StatelessWidget {
  final Widget icon;
  final Color tint;
  final String title;
  final String description;
  final Widget? badge;
  final String action;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.tint,
    required this.title,
    required this.description,
    required this.action,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ApColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: ApColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 210),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: icon,
                ),
                const SizedBox(height: 10),
                Text(title, style: ApText.title.copyWith(fontSize: 18)),
                const SizedBox(height: 10),
                Text(
                  description,
                  style: ApText.small.copyWith(fontSize: 13, height: 18 / 13),
                ),
                if (badge != null) ...[const SizedBox(height: 10), badge!],
                const Spacer(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        action,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: ApColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward,
                      size: 18,
                      color: ApColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La hora del teléfono, que es la que usan los cálculos. Verla ayuda a
/// notar un reloj mal puesto antes de apuntar.
class _PhoneClockRow extends StatefulWidget {
  const _PhoneClockRow();

  @override
  State<_PhoneClockRow> createState() => _PhoneClockRowState();
}

class _PhoneClockRowState extends State<_PhoneClockRow> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _InfoRow(
      label: 'Hora',
      value: '${HomeScreen._formatLocal(DateTime.now())} · del teléfono',
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;

  const _InfoRow({required this.label, required this.value, this.mono = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: ApText.small),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: ApText.strong
                .copyWith(fontSize: 13)
                .merge(mono ? ApText.number : null),
          ),
        ),
      ],
    );
  }
}
