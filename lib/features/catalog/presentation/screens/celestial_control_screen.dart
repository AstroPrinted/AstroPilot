import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../ble_connection/data/models/ble_device_state.dart';
import '../../../ble_connection/presentation/controllers/ble_connection_controller.dart';
import '../../../calibration/data/calibration_repository.dart';
import '../../../calibration/data/calibration_storage.dart';
import '../../../calibration/domain/models/calibration_method.dart';
import '../../../calibration/domain/services/astronomy_position_service.dart';
import '../../../calibration/domain/services/pointing_correction_service.dart';
import '../../../oe4_control/presentation/controllers/oe4_control_controller.dart';
import '../../../observation/domain/models/alt_az_result.dart';
import '../../../settings/application/settings_service.dart';
import '../../application/astronomical_goto_service.dart';
import '../../domain/models/celestial_object.dart';
import '../controllers/celestial_control_controller.dart';
import '../utils/coordinate_formatters.dart';
import '../widgets/celestial_fine_controls.dart';
import '../widgets/celestial_educational_panel.dart';

class CelestialControlScreen extends StatefulWidget {
  final CelestialObject object;

  const CelestialControlScreen({super.key, required this.object});

  @override
  State<CelestialControlScreen> createState() => _CelestialControlScreenState();
}

class _CelestialControlScreenState extends State<CelestialControlScreen> {
  late final CelestialControlController _controller;
  late final ScrollController _scrollController;
  bool _educationalModeEnabled = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _controller = CelestialControlController(
      object: widget.object,
      gotoService: AstronomicalGotoService(
        observerDataProvider: context.read<SettingsService>(),
        calibrationRepository: CalibrationRepository(
          storage: CalibrationStorage(),
        ),
        astronomyPositionService: const AstronomyPositionService(),
        correctionService: const PointingCorrectionService(),
      ),
    );
    unawaited(_controller.refreshPreview());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Consumer2<BleConnectionController, Oe4ControlController>(
          builder: (context, bleController, oe4Controller, _) {
            final bleState = bleController.state;
            final deviceId = bleState.connectedDevice?.id;
            final isConnected =
                bleState.connectionStatus == BleConnectionStatus.connected &&
                deviceId != null;

            if (!isConnected && _controller.isTracking) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _controller.stopTracking(
                  'Tracking detenido: BLE desconectado.',
                );
              });
            }

            return Scaffold(
              appBar: AppBar(title: Text('Control: ${widget.object.name}')),
              body: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _ObjectSummaryCard(object: widget.object),
                  const SizedBox(height: 14),
                  _ConnectionCard(
                    isConnected: isConnected,
                    deviceName: bleState.connectedDevice?.name,
                  ),
                  const SizedBox(height: 14),
                  _PositionCard(controller: _controller),
                  const SizedBox(height: 14),
                  _CorrectionCard(controller: _controller),
                  const SizedBox(height: 14),
                  _TrackingCard(controller: _controller),
                  const SizedBox(height: 14),
                  _ActionsCard(
                    controller: _controller,
                    isConnected: isConnected,
                    externalSending: oe4Controller.isSending,
                    onRefresh: _controller.refreshPreview,
                    onInitialGoto: () => _withDevice(deviceId, (id) async {
                      await _controller.sendInitialGoto(
                        (alt, az) => _sendGotoChecked(
                          oe4Controller,
                          id,
                          altitude: alt,
                          azimuth: az,
                        ),
                      );
                    }),
                    onStartTracking: () => _withDevice(deviceId, (id) async {
                      await _controller.startTracking(
                        (alt, az) => _sendGotoChecked(
                          oe4Controller,
                          id,
                          altitude: alt,
                          azimuth: az,
                        ),
                      );
                    }),
                    onStopTracking: _controller.stopTracking,
                    onStop: () => _withDevice(deviceId, (id) async {
                      await _controller.sendStop(
                        () => _sendStopChecked(oe4Controller, id),
                      );
                    }),
                    onFineTune: (direction) =>
                        _withDevice(deviceId, (id) async {
                          await _controller.fineTune(
                            direction,
                            (alt, az) => _sendGotoChecked(
                              oe4Controller,
                              id,
                              altitude: alt,
                              azimuth: az,
                            ),
                          );
                        }),
                  ),
                  const SizedBox(height: 14),
                  _LastCommandCard(command: _controller.lastSentCommand),
                  const SizedBox(height: 14),
                  _EducationalModeToggleCard(
                    enabled: _educationalModeEnabled,
                    onChanged: (value) {
                      setState(() => _educationalModeEnabled = value);
                    },
                  ),
                  if (_educationalModeEnabled) ...[
                    const SizedBox(height: 14),
                    CelestialEducationalPanel(
                      objectName: widget.object.name,
                      currentPosition: _controller.currentPosition,
                      savedCalibration: _controller.savedCalibration,
                      previewCommand: _controller.previewCommand,
                      lastUpdatedAt: _controller.lastUpdatedAt,
                      nextTrackingAt: _controller.nextTrackingAt,
                      trackingInterval:
                          CelestialControlController.trackingInterval,
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _withDevice(
    String? deviceId,
    Future<void> Function(String deviceId) action,
  ) async {
    if (deviceId == null) {
      _showSnackBar('Conecta el ESP32 por BLE primero.');
      return;
    }
    await action(deviceId);
  }

  Future<void> _sendGotoChecked(
    Oe4ControlController controller,
    String deviceId, {
    required double altitude,
    required double azimuth,
  }) async {
    await controller.sendGoto(deviceId, alt: altitude, az: azimuth);
    final error = controller.errorMessage;
    if (error != null) throw StateError(error);
  }

  Future<void> _sendStopChecked(
    Oe4ControlController controller,
    String deviceId,
  ) async {
    await controller.sendStop(deviceId);
    final error = controller.errorMessage;
    if (error != null) throw StateError(error);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ObjectSummaryCard extends StatelessWidget {
  final CelestialObject object;

  const _ObjectSummaryCard({required this.object});

  @override
  Widget build(BuildContext context) {
    return _ControlCard(
      title: object.name,
      icon: Icons.auto_awesome_rounded,
      children: [
        _InfoLine(label: 'Tipo', value: _typeLabel(object)),
        _InfoLine(label: 'Magnitud', value: object.magnitude ?? 'N/A'),
        if (object is DeepSkyObject)
          _InfoLine(
            label: 'Catálogos',
            value: (object as DeepSkyObject).catalogs.join(', '),
          ),
        if (object is CalibrationStar)
          _InfoLine(
            label: 'Constelación',
            value: (object as CalibrationStar).constellation,
          ),
      ],
    );
  }

  String _typeLabel(CelestialObject object) {
    if (object is SolarSystemBody) return 'Sistema Solar';
    if (object is DeepSkyObject) return object.objectType;
    return 'Estrella de calibración';
  }
}

class _ConnectionCard extends StatelessWidget {
  final bool isConnected;
  final String? deviceName;

  const _ConnectionCard({required this.isConnected, required this.deviceName});

  @override
  Widget build(BuildContext context) {
    return _ControlCard(
      title: 'Conexion BLE',
      icon: isConnected
          ? Icons.bluetooth_connected_rounded
          : Icons.bluetooth_disabled_rounded,
      accent: isConnected
          ? Theme.of(context).colorScheme.secondary
          : Theme.of(context).colorScheme.error,
      children: [
        _StatusMessage(
          icon: isConnected
              ? Icons.check_circle_outline_rounded
              : Icons.error_outline_rounded,
          message: isConnected
              ? 'ESP32 conectado: ${deviceName ?? 'dispositivo BLE'}'
              : 'ESP32 desconectado. Los comandos están deshabilitados.',
          isError: !isConnected,
        ),
      ],
    );
  }
}

class _PositionCard extends StatelessWidget {
  final CelestialControlController controller;

  const _PositionCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final position = controller.currentPosition;
    final preview = controller.previewCommand;
    final error = controller.errorMessage;

    return _ControlCard(
      title: 'Alt/Az del objeto',
      icon: Icons.explore_rounded,
      children: [
        if (position == null)
          _StatusMessage(
            icon: Icons.sync_rounded,
            message: error ?? 'Calculando posición actual...',
            isError: error != null,
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Altitud objetivo',
                  value: _formatSigned(position.altitudeDeg),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  label: 'Azimut objetivo',
                  value: _formatUnsigned(position.azimuthDeg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _VisibilityMessage(position: position),
          const SizedBox(height: 10),
          if (preview == null)
            _StatusMessage(
              icon: Icons.block_rounded,
              message: error ?? 'Comando final no disponible.',
              isError: true,
            )
          else
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Altitud final',
                    value: _formatSigned(preview.finalAltitude),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricTile(
                    label: 'Azimut final',
                    value: _formatUnsigned(preview.finalAzimuth),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          _InfoLine(
            label: 'Última hora de calculo',
            value: position.computedAt.toIso8601String(),
          ),
        ],
      ],
    );
  }
}

class _CorrectionCard extends StatelessWidget {
  final CelestialControlController controller;

  const _CorrectionCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final calibration = controller.savedCalibration;
    final reference = calibration?.points.isNotEmpty == true
        ? calibration!.points.last
        : null;
    return _ControlCard(
      title: 'Calibración',
      icon: Icons.tune_rounded,
      children: [
        if (calibration == null)
          const _StatusMessage(
            icon: Icons.info_outline_rounded,
            message:
                'No calibrado. Realiza calibración con una estrella antes de usar GoTo o tracking.',
          )
        else ...[
          _StatusMessage(
            icon: Icons.check_circle_outline_rounded,
            message: calibration.method == CalibrationMethod.oneStar
                ? 'Referencia inicial activa. El firmware conoce la posición Alt/Az actual del telescopio.'
                : 'Corrección multipunto disponible para GoTo inicial y tracking lógico.',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: calibration.method == CalibrationMethod.oneStar
                      ? 'Altitud fijada'
                      : 'Offset altitud',
                  value: calibration.method == CalibrationMethod.oneStar
                      ? _formatSigned(
                          reference?.motorAltitudeAtCalibration ??
                              reference?.calculatedAltitude ??
                              0,
                        )
                      : _formatSigned(calibration.altitudeOffset),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  label: calibration.method == CalibrationMethod.oneStar
                      ? 'Azimut fijado'
                      : 'Offset azimut',
                  value: calibration.method == CalibrationMethod.oneStar
                      ? _formatUnsigned(
                          reference?.motorAzimuthAtCalibration ??
                              reference?.calculatedAzimuth ??
                              0,
                        )
                      : _formatSigned(calibration.azimuthOffset),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TrackingCard extends StatelessWidget {
  final CelestialControlController controller;

  const _TrackingCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return _ControlCard(
      title: 'Tracking lógico',
      icon: Icons.track_changes_rounded,
      children: [
        _StatusMessage(
          icon: controller.isTracking
              ? Icons.play_circle_outline_rounded
              : Icons.pause_circle_outline_rounded,
          message: controller.isTracking
              ? 'Tracking lógico activo. Actualiza la posición cada 15 segundos.'
              : 'Tracking inactivo.',
        ),
        const SizedBox(height: 10),
        _InfoLine(
          label: 'Última actualización',
          value: controller.lastUpdatedAt?.toIso8601String() ?? 'N/A',
        ),
        _InfoLine(
          label: 'Proximo envio',
          value: controller.nextTrackingAt?.toIso8601String() ?? 'N/A',
        ),
        if (controller.statusMessage != null)
          _InfoLine(label: 'Estado', value: controller.statusMessage!),
      ],
    );
  }
}

class _LastCommandCard extends StatelessWidget {
  final CelestialSentCommand? command;

  const _LastCommandCard({required this.command});

  @override
  Widget build(BuildContext context) {
    final sent = command;
    return _ControlCard(
      title: 'Ultimo comando enviado',
      icon: Icons.send_rounded,
      children: [
        if (sent == null)
          const _StatusMessage(
            icon: Icons.info_outline_rounded,
            message: 'Aún no se han enviado comandos desde esta pantalla.',
          )
        else ...[
          _InfoLine(label: 'Tipo', value: sent.label),
          _InfoLine(label: 'Hora', value: sent.sentAt.toIso8601String()),
          if (sent.altitude != null && sent.azimuth != null)
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Altitud enviada',
                    value: _formatSigned(sent.altitude!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricTile(
                    label: 'Azimut enviado',
                    value: _formatUnsigned(sent.azimuth!),
                  ),
                ),
              ],
            ),
          if (sent.astronomicalCommand != null) ...[
            const SizedBox(height: 8),
            _StatusMessage(
              icon: sent.usedCorrection
                  ? Icons.tune_rounded
                  : Icons.check_circle_outline_rounded,
              message: sent.usedCorrection
                  ? 'Se aplicó corrección multipunto.'
                  : 'Se envio usando la referencia calibrada.',
            ),
          ],
        ],
      ],
    );
  }
}

class _ActionsCard extends StatelessWidget {
  final CelestialControlController controller;
  final bool isConnected;
  final bool externalSending;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onInitialGoto;
  final Future<void> Function() onStartTracking;
  final VoidCallback onStopTracking;
  final Future<void> Function() onStop;
  final Future<void> Function(CelestialFineDirection direction) onFineTune;

  const _ActionsCard({
    required this.controller,
    required this.isConnected,
    required this.externalSending,
    required this.onRefresh,
    required this.onInitialGoto,
    required this.onStartTracking,
    required this.onStopTracking,
    required this.onStop,
    required this.onFineTune,
  });

  @override
  Widget build(BuildContext context) {
    final busy =
        controller.isSending ||
        (externalSending && !controller.isFineTuneInFlight);
    final primaryBusy = busy || controller.isFineTuneInFlight;
    final fineTuneBlockedByOtherCommand =
        externalSending && !controller.isFineTuneInFlight;
    final calibrated = controller.savedCalibration != null;
    final canSend =
        isConnected && calibrated && !primaryBusy && !controller.isTracking;
    final canFineTune =
        isConnected &&
        controller.canFineTune &&
        !controller.isTracking &&
        !controller.isSending &&
        !fineTuneBlockedByOtherCommand;

    return _ControlCard(
      title: 'Acciones de control',
      icon: Icons.precision_manufacturing_rounded,
      children: [
        if (!calibrated) ...[
          const _StatusMessage(
            icon: Icons.lock_outline_rounded,
            message:
                'GoTo y tracking están bloqueados hasta completar calibración con una estrella.',
          ),
          const SizedBox(height: 10),
        ],
        FilledButton.icon(
          onPressed: canSend ? onInitialGoto : null,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.gps_fixed_rounded),
          label: const Text('Enviar GoTo inicial'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canSend ? onStartTracking : null,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Trackear objeto'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: controller.isTracking ? onStopTracking : null,
                icon: const Icon(Icons.pause_rounded),
                label: const Text('Detener tracking'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: isConnected && !primaryBusy ? onStop : null,
          icon: const Icon(Icons.stop_circle_outlined),
          label: const Text('STOP'),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                'Ajuste fino',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            TextButton.icon(
              onPressed: busy || controller.isFineTuneInFlight
                  ? null
                  : onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Recalcular'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _StatusMessage(
          icon: canFineTune
              ? Icons.open_with_rounded
              : Icons.info_outline_rounded,
          message: canFineTune
              ? 'Tap para mover ${CelestialControlController.fineStepDegrees.toStringAsFixed(2)}°. Mantener presionado repite cada 250 ms.'
              : 'Disponible después de un GoTo inicial o tracking previo.',
        ),
        const SizedBox(height: 10),
        CelestialFineControls(enabled: canFineTune, onNudge: onFineTune),
      ],
    );
  }
}

class _EducationalModeToggleCard extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _EducationalModeToggleCard({
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _ControlCard(
      title: 'Modo educativo',
      icon: Icons.school_rounded,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: enabled,
          onChanged: onChanged,
          title: const Text('Mostrar explicación interactiva'),
          subtitle: const Text(
            'Panel solo visual: no envía comandos, no inicia tracking y no '
            'modifica calibración.',
          ),
        ),
      ],
    );
  }
}

class _ControlCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Color? accent;

  const _ControlCard({
    required this.title,
    required this.icon,
    required this.children,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = accent ?? colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accentColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontFamily: 'monospace',
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool isError;

  const _StatusMessage({
    required this.icon,
    required this.message,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isError ? colorScheme.error : colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _VisibilityMessage extends StatelessWidget {
  final AltAzResult position;

  const _VisibilityMessage({required this.position});

  @override
  Widget build(BuildContext context) {
    final visible = position.altitudeDeg >= 0;
    final nearHorizon = visible && position.altitudeDeg < 5;
    return _StatusMessage(
      icon: visible
          ? nearHorizon
                ? Icons.warning_amber_rounded
                : Icons.visibility_rounded
          : Icons.visibility_off_rounded,
      message: visible
          ? nearHorizon
                ? 'Objeto visible, pero muy cerca del horizonte (0° a 5°).'
                : 'Objeto sobre el horizonte.'
          : 'Objeto bajo el horizonte. GoTo y tracking bloqueados.',
      isError: !visible,
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label: ',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

String _formatSigned(double degrees) {
  return CoordinateFormatters.formatSignedDegrees(degrees);
}

String _formatUnsigned(double degrees) {
  return CoordinateFormatters.formatUnsignedDegrees(degrees);
}
