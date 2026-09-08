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
import '../../domain/models/calibration_status.dart';
import '../../domain/models/correction_calibration_status.dart';
import '../../domain/models/correction_model.dart';
import '../../domain/models/initial_alignment_status.dart';
import '../controllers/calibration_controller.dart';
import '../widgets/calibration_controls.dart';
import '../widgets/calibration_method_card.dart';
import '../widgets/calibration_point_list.dart';
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
      appBar: AppBar(
        title: const Text('Alineación y corrección'),
        actions: [
          Consumer<BleConnectionController>(
            builder: (context, ble, _) {
              final device = ble.state.connectedDevice;
              return IconButton(
                tooltip: 'Detener motores',
                icon: const Icon(Icons.stop_circle_outlined),
                onPressed: device == null
                    ? null
                    : () => context.read<Oe4ControlController>().sendStop(
                        device.id,
                      ),
              );
            },
          ),
        ],
      ),
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
                  if (calibration.flowWarningMessage != null) ...[
                    const SizedBox(height: 14),
                    _WarningBanner(message: calibration.flowWarningMessage!),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InitialAlignmentBlock(calibration: calibration),
        const SizedBox(height: 14),
        _CorrectionCalibrationBlock(calibration: calibration),
        if (calibration.isInitialAligned) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: calibration.isBusy
                ? null
                : () => _openVisibleObjects(context),
            icon: const Icon(Icons.visibility_rounded),
            label: const Text('Ver objetos disponibles para observar'),
          ),
        ],
        if (calibration.initialAlignmentResult != null ||
            calibration.correctionCalibrationResult != null) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: calibration.isBusy
                ? null
                : () => _confirmClearCalibration(context, calibration),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Borrar alineación y corrección'),
          ),
        ],
        if (calibration.correctionCalibrationResult != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: calibration.isBusy
                ? null
                : calibration.clearCorrectionCalibration,
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Borrar solo corrección de precisión'),
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
      CalibrationFlowStep.selectingObject => _SelectingObjectStep(
        calibration: calibration,
        onSelected: calibration.selectStar,
        onCancel: calibration.cancelFlow,
      ),
      CalibrationFlowStep.calculatingTarget => _CalculatingStep(
        stepNumber: calibration.currentFlowStepNumber,
        totalSteps: calibration.totalFlowSteps,
        referenceLabel: calibration.referenceProgressLabel,
      ),
      CalibrationFlowStep.movingToTarget => _GotoReferenceStep(
        calibration: calibration,
        controlsEnabled: isConnected,
        isBusy: calibration.isBusy,
        onSendGoto: () =>
            _sendReferenceGoto(calibration, oe4Controller, deviceId),
        onCancel: calibration.cancelFlow,
      ),
      CalibrationFlowStep.waitingUserCentering => _CenteringStep(
        calibration: calibration,
        controlsEnabled: isConnected,
        isBusy: calibration.isBusy,
        onNudge: (direction) =>
            _sendNudge(calibration, oe4Controller, deviceId, direction),
        onMoveToAdjustment: (altitude, azimuth) => _sendManualAdjustment(
          calibration,
          oe4Controller,
          deviceId,
          altitude,
          azimuth,
        ),
        onConfirm: () =>
            _confirmCenteredReference(calibration, oe4Controller, deviceId),
        onCancel: calibration.cancelFlow,
      ),
      CalibrationFlowStep.completed => _CompletedStep(
        stepNumber: calibration.currentFlowStepNumber,
        totalSteps: calibration.totalFlowSteps,
        result: calibration.visibleResult,
        isBusy: calibration.isBusy,
        hasUnsavedResult: calibration.hasUnsavedResult,
        onSave: calibration.savePendingResult,
        onNewCalibration: calibration.cancelFlow,
        onViewVisibleObjects: () => _openVisibleObjects(context),
      ),
      CalibrationFlowStep.failed => _FailedStep(
        message: calibration.errorMessage ?? 'El flujo no pudo completarse.',
        onBack: calibration.cancelFlow,
      ),
      _ => _FailedStep(
        message: 'Estado de corrección no soportado en el MVP.',
        onBack: calibration.cancelFlow,
      ),
    };
  }

  Future<void> _confirmCenteredReference(
    CalibrationController calibration,
    Oe4ControlController oe4Controller,
    String? deviceId,
  ) async {
    if (!_ensureConnected(deviceId)) return;
    await calibration.confirmCenteredReference(
      setInitialPosition: calibration.isInitialAlignmentFlow
          ? (altitude, azimuth) => _checked(
              oe4Controller,
              () => oe4Controller.sendSetPosition(
                deviceId!,
                alt: altitude,
                az: azimuth,
                throwOnError: true,
              ),
            )
          : null,
    );
  }

  Future<void> _sendReferenceGoto(
    CalibrationController calibration,
    Oe4ControlController oe4Controller,
    String? deviceId,
  ) async {
    if (!_ensureConnected(deviceId)) return;
    await calibration.sendGotoToReference(
      (altitude, azimuth) => _checked(
        oe4Controller,
        () => oe4Controller.sendGoto(
          deviceId!,
          alt: altitude,
          az: azimuth,
          throwOnError: true,
        ),
      ),
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
      (deltaAltitude, deltaAzimuth) => _checked(
        oe4Controller,
        () => oe4Controller.sendNudge(
          deviceId!,
          deltaAlt: deltaAltitude,
          deltaAz: deltaAzimuth,
          throwOnError: true,
        ),
      ),
    );
  }

  Future<void> _sendManualAdjustment(
    CalibrationController calibration,
    Oe4ControlController oe4Controller,
    String? deviceId,
    double altitude,
    double azimuth,
  ) async {
    if (!_ensureConnected(deviceId)) return;
    await calibration.moveToAdjustedPosition(
      altitude: altitude,
      azimuth: azimuth,
      sendManualMove: (deltaAltitude, deltaAzimuth) => _checked(
        oe4Controller,
        () => oe4Controller.sendNudge(
          deviceId!,
          deltaAlt: deltaAltitude,
          deltaAz: deltaAzimuth,
          throwOnError: true,
        ),
      ),
    );
  }

  bool _ensureConnected(String? deviceId) {
    if (deviceId != null) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Conecta el ESP32 por BLE primero.')),
    );
    return false;
  }

  Future<void> _checked(
    Oe4ControlController controller,
    Future<void> Function() send,
  ) async {
    await send();
    final error = controller.errorMessage;
    if (error != null) throw StateError(error);
  }

  Future<void> _confirmClearCalibration(
    BuildContext context,
    CalibrationController calibration,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Borrar alineación y corrección'),
          content: const Text(
            'Se eliminará la alineación inicial guardada y cualquier corrección de precisión asociada.',
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
                    'Alineación inicial y corrección de precisión',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Primero sincroniza la posición lógica del telescopio con una estrella reconocible. Después puedes agregar correcciones finas para mejorar futuros GOTO.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _InitialAlignmentBlock extends StatelessWidget {
  final CalibrationController calibration;

  const _InitialAlignmentBlock({required this.calibration});

  @override
  Widget build(BuildContext context) {
    final result = calibration.initialAlignmentResult;
    final reference = calibration.initialAlignmentReferenceName;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '1. Alineación inicial del telescopio',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Este paso le indica al sistema hacia donde está apuntando fisicamente el telescopio. Debes hacerlo al iniciar una sesión de observación.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _InlineNotice(
              icon: calibration.isInitialAligned
                  ? Icons.check_circle_outline_rounded
                  : Icons.info_outline_rounded,
              message: reference == null
                  ? 'Estado: ${calibration.initialAlignmentStatus.label}'
                  : 'Estado: alineado con $reference a las ${_formatTime(result!.createdAt)}',
            ),
            if (result != null) ...[
              const SizedBox(height: 12),
              _SummaryRow(
                label: 'Referencia',
                value: result.lastReference?.objectName ?? 'N/A',
              ),
              _SummaryRow(
                label: 'Fecha/hora',
                value: _formatDate(result.createdAt),
              ),
              if (calibration.initialAlignedPosition != null)
                _SummaryRow(
                  label: 'Alt/Az usada',
                  value:
                      'Alt ${_formatDeg(calibration.initialAlignedPosition!.altitude)} / Az ${_formatDeg(calibration.initialAlignedPosition!.azimuth)}',
                ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: calibration.isBusy
                  ? null
                  : calibration.startInitialAlignment,
              icon: const Icon(Icons.center_focus_strong_rounded),
              label: Text(
                calibration.isInitialAligned
                    ? 'Rehacer alineación con una estrella'
                    : 'Iniciar alineación con una estrella',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CorrectionCalibrationBlock extends StatelessWidget {
  final CalibrationController calibration;

  const _CorrectionCalibrationBlock({required this.calibration});

  @override
  Widget build(BuildContext context) {
    final enabled = calibration.isInitialAligned;
    final correction = calibration.correctionCalibrationResult;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '2. Corrección de precisión',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Después de alinear el telescopio, puedes usar una o más estrellas para corregir errores de apuntamiento y mejorar futuros GOTO.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _InlineNotice(
              icon: enabled ? Icons.tune_rounded : Icons.lock_outline_rounded,
              message: enabled
                  ? 'Estado: ${calibration.correctionCalibrationStatus.label}'
                  : 'Primero realiza la alineación inicial del telescopio para habilitar las correcciones de precisión.',
            ),
            if (correction != null) ...[
              const SizedBox(height: 12),
              _SummaryRow(label: 'Modo activo', value: correction.method.title),
              _SummaryRow(
                label: 'Modelo',
                value: correction.correctionModel.label,
              ),
              _SummaryRow(
                label: 'Offset Alt/Az',
                value:
                    '${_formatDeg(correction.altitudeOffset)} / ${_formatDeg(correction.azimuthOffset)}',
              ),
            ],
            const SizedBox(height: 12),
            for (final method in CalibrationMethod.values) ...[
              CalibrationMethodCard(
                method: method,
                enabled: enabled,
                badgeText: enabled ? null : 'Bloqueada',
                onTap: () => calibration.startCorrectionMethod(method),
              ),
              const SizedBox(height: 10),
            ],
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
            _SummaryRow(
              label: 'Alineación inicial',
              value: _initialAlignmentStatusText(calibration),
            ),
            _SummaryRow(
              label: 'Corrección',
              value: _correctionStatusText(calibration),
            ),
            if (calibration.initialAlignedPosition != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'Altitud lógica',
                      value: _formatDeg(
                        calibration.initialAlignedPosition!.altitude,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricTile(
                      label: 'Azimut lógico',
                      value: _formatDeg(
                        calibration.initialAlignedPosition!.azimuth,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _initialAlignmentStatusText(CalibrationController calibration) {
    final reference = calibration.initialAlignmentReferenceName;
    final timestamp = calibration.initialAlignmentTimestamp;
    if (reference == null) {
      return calibration.initialAlignmentStatus.label;
    }
    final time = timestamp == null ? '' : ' a las ${_formatTime(timestamp)}';
    return '${calibration.initialAlignmentStatus.label} con $reference$time';
  }

  String _correctionStatusText(CalibrationController calibration) {
    if (!calibration.isInitialAligned) {
      return 'Bloqueada hasta completar la alineación inicial';
    }
    if (!calibration.hasCorrectionCalibration) {
      return 'Disponible';
    }
    final result = calibration.correctionCalibrationResult;
    final mode = result?.method.title ?? 'Corrección';
    final model = result?.correctionModel.label ?? 'modelo activo';
    return '$mode activa ($model)';
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
                  ? 'ESP32 conectado. El flujo usara movimiento manual y SET_POSITION.'
                  : 'Puedes revisar el flujo, pero movimiento manual y SET_POSITION requieren conexion BLE.',
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

class _WarningBanner extends StatelessWidget {
  final String message;

  const _WarningBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.tertiary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: colorScheme.tertiary),
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

class _SelectingObjectStep extends StatelessWidget {
  final CalibrationController calibration;
  final ValueChanged<CalibrationStarOption> onSelected;
  final VoidCallback onCancel;

  const _SelectingObjectStep({
    required this.calibration,
    required this.onSelected,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final starOptions = calibration.calibrationStarOptions;
    final visibleOptions = starOptions
        .where((option) => option.isVisible)
        .toList(growable: false);
    final notVisibleOptions = starOptions
        .where((option) => !option.isVisible)
        .toList(growable: false);
    final isInitialAlignment = calibration.isInitialAlignmentFlow;

    return CalibrationStepCard(
      stepNumber: calibration.currentFlowStepNumber,
      totalSteps: calibration.totalFlowSteps,
      title: isInitialAlignment
          ? 'Seleccionar estrella reconocible'
          : 'Seleccionar referencia de corrección',
      description: isInitialAlignment
          ? 'Elige una estrella visible y reconocible. Luego mueve manualmente el telescopio hasta centrarla en el ocular.'
          : 'Elige una estrella visible. La app hará GOTO y luego usarás el joystick para medir la corrección real.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (visibleOptions.length < calibration.requiredReferenceCount) ...[
            _InlineNotice(
              icon: Icons.visibility_off_rounded,
              message:
                  'No hay estrellas recomendadas visibles para ${isInitialAlignment ? 'la alineación inicial' : calibration.currentMethod?.title ?? 'este método'}.\nSe requiere al menos una estrella sobre ${CalibrationController.visibleStarAltitudeThresholdDeg.toStringAsFixed(0)} grados de altitud.',
            ),
            const SizedBox(height: 12),
          ],
          if (calibration.completedReferenceCount > 0) ...[
            const _InlineNotice(
              icon: Icons.info_outline_rounded,
              message:
                  'Para mejorar la corrección, elige una estrella separada de la referencia anterior.',
            ),
            const SizedBox(height: 12),
          ],
          if (visibleOptions.isNotEmpty) ...[
            _StarSectionTitle(
              label: 'Estrellas visibles ahora (${visibleOptions.length})',
            ),
            const SizedBox(height: 8),
            for (final option in visibleOptions)
              _StarTile(
                option: option,
                guide: calibration.guideForStar(option.star),
                onTap: option.isSelectable ? () => onSelected(option) : null,
              ),
          ],
          if (notVisibleOptions.isNotEmpty) ...[
            const SizedBox(height: 10),
            const _StarSectionTitle(label: 'No visibles actualmente'),
            const SizedBox(height: 8),
            for (final option in notVisibleOptions)
              _StarTile(
                option: option,
                guide: calibration.guideForStar(option.star),
                onTap: null,
              ),
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
  final String guide;
  final VoidCallback? onTap;

  const _StarTile({
    required this.option,
    required this.guide,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final star = option.star;
    final position = option.position;
    final colorScheme = Theme.of(context).colorScheme;
    final stateColor = option.isAlreadySelected
        ? colorScheme.tertiary
        : option.isVisible
        ? colorScheme.secondary
        : colorScheme.onSurfaceVariant;
    final stateLabel = option.isAlreadySelected
        ? 'Ya seleccionada como referencia'
        : option.isVisible
        ? 'Visible ahora'
        : position.altitudeDeg < 0
        ? 'No visible - bajo el horizonte'
        : 'No visible para este flujo';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: option.isSelectable
            ? colorScheme.secondary.withValues(alpha: 0.08)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          enabled: option.isSelectable,
          onTap: onTap,
          leading: Icon(
            option.isAlreadySelected
                ? Icons.check_circle_outline_rounded
                : option.isVisible
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
              const SizedBox(height: 2),
              Text(guide, style: Theme.of(context).textTheme.bodySmall),
              if (option.closestReferenceDistanceDeg != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Separacion con referencia previa: ${_formatDeg(option.closestReferenceDistanceDeg!)}',
                ),
              ],
              if (option.isTooCloseToReference &&
                  !option.isAlreadySelected) ...[
                const SizedBox(height: 2),
                Text(
                  'Advertencia: esta estrella está cerca de una referencia anterior.',
                  style: TextStyle(color: colorScheme.tertiary),
                ),
              ],
            ],
          ),
          trailing: option.isAlreadySelected
              ? const Icon(Icons.block_rounded)
              : option.isVisible
              ? const Icon(Icons.chevron_right_rounded)
              : const Icon(Icons.block_rounded),
        ),
      ),
    );
  }
}

class _CalculatingStep extends StatelessWidget {
  final int stepNumber;
  final int totalSteps;
  final String referenceLabel;

  const _CalculatingStep({
    required this.stepNumber,
    required this.totalSteps,
    required this.referenceLabel,
  });

  @override
  Widget build(BuildContext context) {
    return CalibrationStepCard(
      stepNumber: stepNumber,
      totalSteps: totalSteps,
      title: 'Calculando posición Alt/Az',
      description:
          '$referenceLabel. La app está usando fecha, hora, latitud y longitud actuales.',
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _GotoReferenceStep extends StatelessWidget {
  final CalibrationController calibration;
  final bool controlsEnabled;
  final bool isBusy;
  final VoidCallback onSendGoto;
  final VoidCallback onCancel;

  const _GotoReferenceStep({
    required this.calibration,
    required this.controlsEnabled,
    required this.isBusy,
    required this.onSendGoto,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return CalibrationStepCard(
      stepNumber: calibration.currentFlowStepNumber,
      totalSteps: calibration.totalFlowSteps,
      title: 'Enviar GOTO a la referencia',
      description:
          '${calibration.referenceProgressLabel}. El telescopio ya tiene alineación inicial; ahora se moverá al objetivo para medir el error real de apuntamiento.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (calibration.targetPosition != null) ...[
            _TargetPanel(target: calibration.targetPosition!),
            const SizedBox(height: 12),
          ],
          _InlineNotice(
            icon: Icons.info_outline_rounded,
            message:
                'Después del GOTO, centra manualmente la referencia si quedó fuera del ocular y confirma la corrección.',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: !controlsEnabled || isBusy ? null : onSendGoto,
            icon: const Icon(Icons.near_me_rounded),
            label: const Text('Enviar GOTO a la referencia'),
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
  final Future<void> Function(double altitude, double azimuth)
  onMoveToAdjustment;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _CenteringStep({
    required this.calibration,
    required this.controlsEnabled,
    required this.isBusy,
    required this.onNudge,
    required this.onMoveToAdjustment,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isInitialAlignment = calibration.isInitialAlignmentFlow;
    return CalibrationStepCard(
      stepNumber: calibration.currentFlowStepNumber,
      totalSteps: calibration.totalFlowSteps,
      title: isInitialAlignment
          ? 'Centra la estrella manualmente'
          : 'Corrige y centra la referencia',
      description: isInitialAlignment
          ? 'Usa los controles manuales para centrar ${calibration.selectedStar?.name ?? 'la estrella'} en el ocular. Al confirmar, la app fijará la posición lógica actual del telescopio.'
          : 'Si el GOTO no dejó ${calibration.selectedStar?.name ?? 'la referencia'} centrada, corrige con el joystick. Al confirmar, la app guardará el offset de precisión.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (calibration.targetPosition != null) ...[
            _TargetPanel(target: calibration.targetPosition!),
            const SizedBox(height: 10),
          ],
          if (calibration.selectedStarGuide.isNotEmpty) ...[
            _InlineNotice(
              icon: Icons.tips_and_updates_rounded,
              message: calibration.selectedStarGuide,
            ),
            const SizedBox(height: 12),
          ],
          _AdjustedPositionPanel(
            isInitialAlignment: isInitialAlignment,
            altitude: calibration.adjustedAltitude,
            azimuth: calibration.adjustedAzimuth,
          ),
          const SizedBox(height: 12),
          CalibrationControls(
            enabled: controlsEnabled,
            adjustedAltitude: calibration.adjustedAltitude,
            adjustedAzimuth: calibration.adjustedAzimuth,
            onNudge: onNudge,
            onMoveToAdjustment: onMoveToAdjustment,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: isBusy ? null : onConfirm,
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: Text(
              isInitialAlignment
                  ? 'Confirmar estrella centrada'
                  : 'Confirmar corrección',
            ),
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
  final int stepNumber;
  final int totalSteps;
  final CalibrationResult? result;
  final bool isBusy;
  final bool hasUnsavedResult;
  final VoidCallback onSave;
  final VoidCallback onNewCalibration;
  final VoidCallback onViewVisibleObjects;

  const _CompletedStep({
    required this.stepNumber,
    required this.totalSteps,
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
    final isInitialAlignment = visibleResult?.isInitialAlignment ?? false;

    return CalibrationStepCard(
      stepNumber: stepNumber,
      totalSteps: totalSteps,
      title: isInitialAlignment
          ? 'Alineación inicial guardada'
          : 'Corrección de precisión guardada',
      description: isInitialAlignment
          ? 'La posición lógica del telescopio fue fijada con la Alt/Az real de la estrella centrada.'
          : 'La app guardó el offset entre la posición esperada y la posición donde centraste la referencia.',
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
                  ? 'Guardar resultado'
                  : isInitialAlignment
                  ? 'Alineación guardada'
                  : 'Corrección guardada',
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
            label: Text(
              isInitialAlignment ? 'Nueva alineación' : 'Nueva corrección',
            ),
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
          'Posición calculada actual',
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
  final bool isInitialAlignment;
  final double? altitude;
  final double? azimuth;

  const _AdjustedPositionPanel({
    required this.isInitialAlignment,
    required this.altitude,
    required this.azimuth,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            label: isInitialAlignment
                ? 'Movimiento altitud'
                : 'Altitud centrada',
            value: altitude == null ? 'N/A' : _formatDeg(altitude!),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricTile(
            label: isInitialAlignment ? 'Movimiento azimut' : 'Azimut centrado',
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
    final isInitialAlignment = result.isInitialAlignment;
    final stateLabel = isSaved
        ? isInitialAlignment
              ? 'Alineación guardada'
              : 'Corrección guardada'
        : 'Resultado sin guardar';
    final reference = result.points.isNotEmpty ? result.points.last : null;

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
                    isInitialAlignment
                        ? 'Resumen de alineación inicial'
                        : 'Resumen de corrección de precisión',
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
                    label: isInitialAlignment
                        ? 'Altitud fijada'
                        : 'Offset altitud',
                    value: reference == null
                        ? 'N/A'
                        : _formatDeg(
                            isInitialAlignment
                                ? reference.motorAltitudeAtCalibration ??
                                      reference.calculatedAltitude
                                : result.altitudeOffset,
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricTile(
                    label: isInitialAlignment
                        ? 'Azimut fijado'
                        : 'Offset azimut',
                    value: reference == null
                        ? 'N/A'
                        : _formatDeg(
                            isInitialAlignment
                                ? reference.motorAzimuthAtCalibration ??
                                      reference.calculatedAzimuth
                                : result.azimuthOffset,
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SummaryRow(label: 'Estado', value: stateLabel),
            _SummaryRow(label: 'Estado guardado', value: result.status.label),
            _SummaryRow(
              label: 'Etapa',
              value: isInitialAlignment
                  ? 'Alineación inicial'
                  : 'Corrección de precisión',
            ),
            _SummaryRow(label: 'Método', value: result.method.title),
            _SummaryRow(label: 'Modelo', value: result.correctionModel.label),
            _SummaryRow(
              label: 'Referencias',
              value: result.points.length.toString(),
            ),
            _SummaryRow(
              label: 'Fecha/hora',
              value: _formatDate(result.createdAt),
            ),
            if (result.estimatedError != null) ...[
              const SizedBox(height: 4),
              Text(
                'Error de referencia: ${_formatDeg(result.estimatedError!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (result.warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Advertencias',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              for (final warning in result.warnings)
                _InlineNotice(
                  icon: Icons.warning_amber_rounded,
                  message: warning,
                ),
            ],
            const SizedBox(height: 14),
            Text(
              isInitialAlignment
                  ? 'Esta alineación solo establece hacia donde apunta el telescopio al iniciar. Las correcciones de precisión se agregan después.'
                  : 'Esta corrección mejora futuros GOTO aplicando el offset medido después de la alineación inicial.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Text(
              'Puntos registrados',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
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
        isSaved ? 'Guardada' : 'Sin guardar',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
      ),
    );
  }
}

String _formatDeg(double value) => '${value.toStringAsFixed(2)}°';

String _formatDate(DateTime value) {
  return value.toLocal().toString().split('.').first;
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
