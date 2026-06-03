import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../ble_connection/data/models/ble_device_state.dart';
import '../../../ble_connection/presentation/controllers/ble_connection_controller.dart';
import '../../../catalog/presentation/screens/catalog_screen.dart';
import '../../../observation/domain/models/alt_az_result.dart';
import '../../../oe4_control/presentation/controllers/oe4_control_controller.dart';
import '../../domain/models/calibration_flow_step.dart';
import '../../domain/models/calibration_method.dart';
import '../../domain/models/calibration_result.dart';
import '../controllers/calibration_controller.dart';
import '../widgets/calibration_controls.dart';
import '../widgets/calibration_method_card.dart';
import '../widgets/calibration_point_list.dart';
import '../widgets/calibration_status_badge.dart';
import '../widgets/calibration_step_card.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  bool _loadRequested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadRequested) return;

    _loadRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CalibrationController>().loadSavedCalibration();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calibracion')),
      body:
          Consumer3<
            CalibrationController,
            BleConnectionController,
            Oe4ControlController
          >(
            builder: (context, calibration, bleController, oe4Controller, _) {
              final bleState = bleController.state;
              final isConnected =
                  bleState.connectionStatus == BleConnectionStatus.connected &&
                  bleState.connectedDevice != null;
              final deviceId = bleState.connectedDevice?.id;

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                oe4Controller.syncConnectionDevice(
                  isConnected ? deviceId : null,
                );
              });

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  const _HeaderCard(),
                  const SizedBox(height: 14),
                  _StatusPanel(calibration: calibration),
                  const SizedBox(height: 14),
                  _ConnectionNotice(isConnected: isConnected),
                  if (calibration.errorMessage != null) ...[
                    const SizedBox(height: 14),
                    _ErrorBanner(message: calibration.errorMessage!),
                  ],
                  const SizedBox(height: 14),
                  if (calibration.isLoading)
                    const _LoadingCard()
                  else
                    _buildContent(
                      context,
                      calibration,
                      oe4Controller,
                      deviceId,
                      isConnected,
                    ),
                ],
              );
            },
          ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    CalibrationController calibration,
    Oe4ControlController oe4Controller,
    String? deviceId,
    bool isConnected,
  ) {
    if (calibration.flowStep == CalibrationFlowStep.idle) {
      return _buildIdleContent(context, calibration);
    }
    return _buildActiveFlow(
      context,
      calibration,
      oe4Controller,
      deviceId,
      isConnected,
    );
  }

  Widget _buildIdleContent(
    BuildContext context,
    CalibrationController calibration,
  ) {
    final result = calibration.visibleResult;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (result != null) ...[
          _ResultSummaryCard(result: result, isSaved: true),
          const SizedBox(height: 14),
        ],
        Text(
          'Elige un metodo de correccion estimada',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        for (final method in CalibrationMethod.values) ...[
          CalibrationMethodCard(
            method: method,
            onTap: () => calibration.startMethod(method),
          ),
          const SizedBox(height: 10),
        ],
        if (calibration.savedResult != null) ...[
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: calibration.isBusy
                ? null
                : () => _confirmClearCalibration(context, calibration),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Borrar correccion estimada'),
          ),
        ],
      ],
    );
  }

  Widget _buildActiveFlow(
    BuildContext context,
    CalibrationController calibration,
    Oe4ControlController oe4Controller,
    String? deviceId,
    bool isConnected,
  ) {
    return switch (calibration.flowStep) {
      CalibrationFlowStep.waitingHome => _WaitingHomeStep(
        isBusy: calibration.isBusy,
        onHome: () => _sendHome(calibration, oe4Controller, deviceId),
        onContinue: calibration.continueAfterHome,
        onCancel: calibration.cancelFlow,
      ),
      CalibrationFlowStep.selectingObject => _SelectingObjectStep(
        starOptions: calibration.calibrationStarOptions,
        onSelected: calibration.selectStar,
        onCancel: calibration.cancelFlow,
      ),
      CalibrationFlowStep.calculatingTarget => const _CalculatingStep(),
      CalibrationFlowStep.movingToTarget => _MovingToTargetStep(
        calibration: calibration,
        isBusy: calibration.isBusy,
        onGoto: () => _sendGotoToTarget(calibration, oe4Controller, deviceId),
        onBack: calibration.continueAfterHome,
        onCancel: calibration.cancelFlow,
      ),
      CalibrationFlowStep.waitingUserCentering => _CenteringStep(
        calibration: calibration,
        controlsEnabled: isConnected,
        isBusy: calibration.isBusy,
        onNudge: (direction) =>
            _sendNudge(calibration, oe4Controller, deviceId, direction),
        onConfirm: calibration.confirmAdjustedReference,
        onCancel: calibration.cancelFlow,
      ),
      CalibrationFlowStep.completed => _CompletedStep(
        result: calibration.visibleResult,
        isBusy: calibration.isBusy,
        hasUnsavedResult: calibration.hasUnsavedResult,
        onSave: calibration.savePendingResult,
        onNewCalibration: calibration.cancelFlow,
        onViewVisibleObjects: () => _openVisibleObjects(context),
      ),
      CalibrationFlowStep.failed => _FailedStep(
        message:
            calibration.errorMessage ??
            'El flujo de correccion estimada fallo.',
        onBack: calibration.cancelFlow,
      ),
      _ => _FailedStep(
        message: 'Estado de correccion no soportado en el MVP.',
        onBack: calibration.cancelFlow,
      ),
    };
  }

  Future<void> _sendHome(
    CalibrationController calibration,
    Oe4ControlController oe4Controller,
    String? deviceId,
  ) async {
    if (!_ensureConnected(deviceId)) return;
    await calibration.sendHome(() => oe4Controller.sendHome(deviceId!));
  }

  Future<void> _sendGotoToTarget(
    CalibrationController calibration,
    Oe4ControlController oe4Controller,
    String? deviceId,
  ) async {
    if (!_ensureConnected(deviceId)) return;
    await calibration.sendGotoToTarget(
      (altitude, azimuth) =>
          oe4Controller.sendGoto(deviceId!, alt: altitude, az: azimuth),
    );
  }

  Future<void> _sendNudge(
    CalibrationController calibration,
    Oe4ControlController oe4Controller,
    String? deviceId,
    CalibrationNudgeDirection direction,
  ) async {
    if (!_ensureConnected(deviceId)) return;
    await calibration.nudge(
      direction,
      (altitude, azimuth) =>
          oe4Controller.sendGoto(deviceId!, alt: altitude, az: azimuth),
    );
  }

  bool _ensureConnected(String? deviceId) {
    if (deviceId != null) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Conecta el ESP32 por BLE primero.')),
    );
    return false;
  }

  Future<void> _confirmClearCalibration(
    BuildContext context,
    CalibrationController calibration,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Borrar correccion estimada'),
          content: const Text(
            'Se eliminara la correccion logica guardada en este dispositivo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Borrar'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await calibration.clearCalibration();
    }
  }

  void _openVisibleObjects(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CatalogScreen(initialVisibleOnly: true),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.secondary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.center_focus_strong_rounded,
                    color: colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Calibracion logica del prototipo',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Compara la posicion astronomica calculada con una posicion ajustada manualmente en motores. Esta fase no valida apuntado optico real.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  final CalibrationController calibration;

  const _StatusPanel({required this.calibration});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estado actual',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            CalibrationStatusBadge(status: calibration.status),
            if (calibration.savedResult != null) ...[
              const SizedBox(height: 10),
              Text(
                'Ultima correccion estimada: ${_formatDate(calibration.savedResult!.createdAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConnectionNotice extends StatelessWidget {
  final bool isConnected;

  const _ConnectionNotice({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isConnected ? colorScheme.secondary : colorScheme.error;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isConnected
                ? Icons.bluetooth_connected_rounded
                : Icons.bluetooth_disabled_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isConnected
                  ? 'ESP32 conectado. El flujo usara HOME y GOTO existentes.'
                  : 'Puedes revisar el flujo, pero HOME y GOTO requieren conexion BLE.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: colorScheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _WaitingHomeStep extends StatelessWidget {
  final bool isBusy;
  final VoidCallback onHome;
  final VoidCallback onContinue;
  final VoidCallback onCancel;

  const _WaitingHomeStep({
    required this.isBusy,
    required this.onHome,
    required this.onContinue,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return CalibrationStepCard(
      stepNumber: 1,
      totalSteps: 5,
      title: 'Coloca el telescopio en posicion inicial',
      description:
          'Usa HOME como referencia mecanica antes de calcular la posicion de la estrella.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: isBusy ? null : onHome,
            icon: const Icon(Icons.home_rounded),
            label: const Text('Enviar HOME'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: isBusy ? null : onContinue,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Continuar'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: isBusy ? null : onCancel,
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}

class _SelectingObjectStep extends StatelessWidget {
  final List<CalibrationStarOption> starOptions;
  final ValueChanged<CalibrationStarOption> onSelected;
  final VoidCallback onCancel;

  const _SelectingObjectStep({
    required this.starOptions,
    required this.onSelected,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final visibleOptions = starOptions
        .where((option) => option.isVisible)
        .toList(growable: false);
    final notVisibleOptions = starOptions
        .where((option) => !option.isVisible)
        .toList(growable: false);

    return CalibrationStepCard(
      stepNumber: 2,
      totalSteps: 5,
      title: 'Seleccionar estrella visible',
      description:
          'Estrella visible para referencia. La app calcula Alt/Az con la ubicacion, fecha y hora actuales; esta fase no verifica apuntado optico real.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (visibleOptions.isEmpty) ...[
            const _InlineNotice(
              icon: Icons.visibility_off_rounded,
              message:
                  'No hay estrellas de calibracion visibles con la ubicacion, fecha y hora actuales.\nRevisa la configuracion de ubicacion/hora o intenta mas tarde.',
            ),
            const SizedBox(height: 12),
          ],
          if (visibleOptions.isNotEmpty) ...[
            _StarSectionTitle(
              label: 'Estrellas visibles ahora (${visibleOptions.length})',
            ),
            const SizedBox(height: 8),
            for (final option in visibleOptions)
              _StarTile(option: option, onTap: () => onSelected(option)),
          ],
          if (notVisibleOptions.isNotEmpty) ...[
            const SizedBox(height: 10),
            const _StarSectionTitle(label: 'No visibles actualmente'),
            const SizedBox(height: 8),
            for (final option in notVisibleOptions)
              _StarTile(option: option, onTap: null),
          ],
          const SizedBox(height: 8),
          TextButton(onPressed: onCancel, child: const Text('Cancelar')),
        ],
      ),
    );
  }
}

class _StarSectionTitle extends StatelessWidget {
  final String label;

  const _StarSectionTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label, style: Theme.of(context).textTheme.titleSmall);
  }
}

class _StarTile extends StatelessWidget {
  final CalibrationStarOption option;
  final VoidCallback? onTap;

  const _StarTile({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final star = option.star;
    final position = option.position;
    final colorScheme = Theme.of(context).colorScheme;
    final stateColor = option.isVisible
        ? colorScheme.secondary
        : colorScheme.onSurfaceVariant;
    final stateLabel = option.isVisible
        ? 'Visible ahora'
        : position.altitudeDeg < 0
        ? 'No visible - bajo el horizonte'
        : 'No visible para calibracion';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: option.isVisible
            ? colorScheme.secondary.withValues(alpha: 0.08)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          enabled: option.isVisible,
          onTap: onTap,
          leading: Icon(
            option.isVisible
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded,
            color: stateColor,
          ),
          title: Text(star.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${star.constellation} · Mag ${star.magnitude ?? 'N/A'} · ${star.spectralType}',
              ),
              const SizedBox(height: 4),
              Text(
                'Alt ${_formatDeg(position.altitudeDeg)} / Az ${_formatDeg(position.azimuthDeg)}',
              ),
              const SizedBox(height: 2),
              Text('Estado: $stateLabel'),
            ],
          ),
          trailing: option.isVisible
              ? const Icon(Icons.chevron_right_rounded)
              : const Icon(Icons.block_rounded),
        ),
      ),
    );
  }
}

class _CalculatingStep extends StatelessWidget {
  const _CalculatingStep();

  @override
  Widget build(BuildContext context) {
    return const CalibrationStepCard(
      stepNumber: 2,
      totalSteps: 5,
      title: 'Calculando posicion Alt/Az',
      description:
          'La app esta usando fecha, hora, latitud y longitud actuales.',
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _MovingToTargetStep extends StatelessWidget {
  final CalibrationController calibration;
  final bool isBusy;
  final VoidCallback onGoto;
  final VoidCallback onBack;
  final VoidCallback onCancel;

  const _MovingToTargetStep({
    required this.calibration,
    required this.isBusy,
    required this.onGoto,
    required this.onBack,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final target = calibration.targetPosition;
    final targetIsVisible =
        target != null &&
        target.altitudeDeg >
            CalibrationController.visibleStarAltitudeThresholdDeg;
    return CalibrationStepCard(
      stepNumber: 3,
      totalSteps: 5,
      title: 'Enviar GoTo a posicion calculada',
      description:
          'Posicion calculada actual de ${calibration.selectedStar?.name ?? 'la estrella'}. La app enviara un comando GoTo existente.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (target != null) _TargetPanel(target: target),
          if (target != null && !targetIsVisible) ...[
            const SizedBox(height: 10),
            _InlineNotice(
              icon: Icons.visibility_off_rounded,
              message:
                  'La estrella ya no supera el umbral de ${CalibrationController.visibleStarAltitudeThresholdDeg.toStringAsFixed(0)} grados para calibracion.',
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: isBusy || !targetIsVisible ? null : onGoto,
            icon: const Icon(Icons.gps_fixed_rounded),
            label: const Text('Enviar GoTo'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: isBusy ? null : onBack,
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Cambiar estrella'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: isBusy ? null : onCancel,
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}

class _CenteringStep extends StatelessWidget {
  final CalibrationController calibration;
  final bool controlsEnabled;
  final bool isBusy;
  final Future<void> Function(CalibrationNudgeDirection direction) onNudge;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _CenteringStep({
    required this.calibration,
    required this.controlsEnabled,
    required this.isBusy,
    required this.onNudge,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return CalibrationStepCard(
      stepNumber: 4,
      totalSteps: 5,
      title: 'Ajusta la referencia de motores',
      description:
          'Cada boton envia un GOTO incremental de ${CalibrationController.fineStepDegrees.toStringAsFixed(2)} grados. Puedes mantenerlo presionado para repetir el movimiento. Guarda la posicion ajustada como referencia estimada del prototipo.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AdjustedPositionPanel(
            altitude: calibration.adjustedAltitude,
            azimuth: calibration.adjustedAzimuth,
          ),
          const SizedBox(height: 12),
          CalibrationControls(enabled: controlsEnabled, onNudge: onNudge),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: isBusy ? null : onConfirm,
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text('Guardar posicion ajustada como referencia'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: isBusy ? null : onCancel,
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}

class _CompletedStep extends StatelessWidget {
  final CalibrationResult? result;
  final bool isBusy;
  final bool hasUnsavedResult;
  final VoidCallback onSave;
  final VoidCallback onNewCalibration;
  final VoidCallback onViewVisibleObjects;

  const _CompletedStep({
    required this.result,
    required this.isBusy,
    required this.hasUnsavedResult,
    required this.onSave,
    required this.onNewCalibration,
    required this.onViewVisibleObjects,
  });

  @override
  Widget build(BuildContext context) {
    final visibleResult = result;

    return CalibrationStepCard(
      stepNumber: 5,
      totalSteps: 5,
      title: 'Correccion estimada calculada',
      description:
          'Esta correccion se basa en el ajuste manual del usuario y en la posicion estimada de los motores.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (visibleResult != null)
            _ResultSummaryCard(
              result: visibleResult,
              isSaved: !hasUnsavedResult,
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: isBusy || !hasUnsavedResult ? null : onSave,
            icon: const Icon(Icons.save_rounded),
            label: Text(
              hasUnsavedResult
                  ? 'Guardar correccion estimada'
                  : 'Correccion estimada guardada',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: isBusy || hasUnsavedResult ? null : onViewVisibleObjects,
            icon: const Icon(Icons.visibility_rounded),
            label: const Text('Ver objetos visibles'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: isBusy ? null : onNewCalibration,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Nuevo ajuste logico'),
          ),
        ],
      ),
    );
  }
}

class _FailedStep extends StatelessWidget {
  final String message;
  final VoidCallback onBack;

  const _FailedStep({required this.message, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return CalibrationStepCard(
      stepNumber: 1,
      totalSteps: 5,
      title: 'No se pudo continuar',
      description: message,
      child: OutlinedButton.icon(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_rounded),
        label: const Text('Volver'),
      ),
    );
  }
}

class _TargetPanel extends StatelessWidget {
  final AltAzResult target;

  const _TargetPanel({required this.target});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Posicion calculada actual',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Altitud actual',
                value: _formatDeg(target.altitudeDeg),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                label: 'Azimut actual',
                value: _formatDeg(target.azimuthDeg),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'UTC ${target.computedAt.toIso8601String()}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _AdjustedPositionPanel extends StatelessWidget {
  final double? altitude;
  final double? azimuth;

  const _AdjustedPositionPanel({required this.altitude, required this.azimuth});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            label: 'Altitud ajustada',
            value: altitude == null ? 'N/A' : _formatDeg(altitude!),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricTile(
            label: 'Azimut ajustado',
            value: azimuth == null ? 'N/A' : _formatDeg(azimuth!),
          ),
        ),
      ],
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
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
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

class _InlineNotice extends StatelessWidget {
  final IconData icon;
  final String message;

  const _InlineNotice({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class _ResultSummaryCard extends StatelessWidget {
  final CalibrationResult result;
  final bool isSaved;

  const _ResultSummaryCard({required this.result, required this.isSaved});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final point = result.points.isEmpty ? null : result.points.last;
    final stateLabel = isSaved
        ? 'Correccion estimada guardada'
        : 'Correccion estimada sin guardar';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune_rounded, color: colorScheme.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Resumen de correccion estimada',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _SavedBadge(isSaved: isSaved),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Offset estimado altitud',
                    value: _formatSignedDeg(result.altitudeOffset),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricTile(
                    label: 'Offset estimado azimut',
                    value: _formatSignedDeg(result.azimuthOffset),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SummaryRow(label: 'Estado', value: stateLabel),
            _SummaryRow(label: 'Metodo', value: result.method.title),
            _SummaryRow(
              label: 'Fecha/hora',
              value: _formatDate(result.createdAt),
            ),
            if (point != null) ...[
              _SummaryRow(
                label: 'Objeto de referencia',
                value: point.objectName,
              ),
              _SummaryRow(
                label: 'Altitud calculada',
                value: _formatDeg(point.calculatedAltitude),
              ),
              _SummaryRow(
                label: 'Azimut calculado',
                value: _formatDeg(point.calculatedAzimuth),
              ),
              _SummaryRow(
                label: 'Altitud ajustada',
                value: _formatDeg(point.adjustedAltitude),
              ),
              _SummaryRow(
                label: 'Azimut ajustado',
                value: _formatDeg(point.adjustedAzimuth),
              ),
            ],
            if (result.estimatedError != null) ...[
              const SizedBox(height: 4),
              Text(
                'Diferencia estimada MVP: ${_formatDeg(result.estimatedError!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'Esta correccion se basa en el ajuste manual del usuario; no confirma apuntado optico real.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            CalibrationPointList(points: result.points),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 142,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedBadge extends StatelessWidget {
  final bool isSaved;

  const _SavedBadge({required this.isSaved});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isSaved ? colorScheme.secondary : colorScheme.tertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isSaved ? 'Estimada guardada' : 'Sin guardar',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
      ),
    );
  }
}

String _formatDeg(double value) => '${value.toStringAsFixed(2)}°';

String _formatSignedDeg(double value) {
  final sign = value >= 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(2)}°';
}

String _formatDate(DateTime value) {
  return value.toLocal().toString().split('.').first;
}
