import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../ble_connection/data/models/ble_device_state.dart';
import '../../../ble_connection/presentation/controllers/ble_connection_controller.dart';
import '../controllers/oe4_control_controller.dart';

class Oe4ControlScreen extends StatefulWidget {
  const Oe4ControlScreen({super.key});

  @override
  State<Oe4ControlScreen> createState() => _Oe4ControlScreenState();
}

class _Oe4ControlScreenState extends State<Oe4ControlScreen> {
  final _formKey = GlobalKey<FormState>();
  final _altController = TextEditingController();
  final _azController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _altController.addListener(_refreshValidationState);
    _azController.addListener(_refreshValidationState);
  }

  @override
  void dispose() {
    _altController.removeListener(_refreshValidationState);
    _azController.removeListener(_refreshValidationState);
    _altController.dispose();
    _azController.dispose();
    super.dispose();
  }

  void _refreshValidationState() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Control OE4')),
      body: Consumer2<BleConnectionController, Oe4ControlController>(
        builder: (context, bleController, oe4Controller, _) {
          final bleState = bleController.state;
          final isConnected =
              bleState.connectionStatus == BleConnectionStatus.connected &&
              bleState.connectedDevice != null;
          final deviceId = bleState.connectedDevice?.id;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            oe4Controller.syncConnectionDevice(isConnected ? deviceId : null);
          });

          return LayoutBuilder(
            builder: (context, constraints) {
              final useWideActions = constraints.maxWidth >= 520;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  const _HeaderCard(),
                  const SizedBox(height: 14),
                  _ConnectionCard(
                    isConnected: isConnected,
                    deviceName: bleState.connectedDevice?.name,
                    lastSentCommand: oe4Controller.lastSentCommand,
                    lastResponse: oe4Controller.lastResponse,
                    errorMessage: oe4Controller.errorMessage,
                  ),
                  const SizedBox(height: 14),
                  _ReliabilityCard(
                    isConnected: isConnected,
                    heartbeatActive: oe4Controller.heartbeatActive,
                    lastPongReceivedAt: oe4Controller.lastPongReceivedAt,
                    watchdogEnabled: oe4Controller.watchdogEnabled,
                    isTogglingWatchdog: oe4Controller.isTogglingWatchdog,
                    lastEsp32Alert: oe4Controller.lastEsp32Alert,
                    currentRssi: oe4Controller.currentRssi,
                    rssiUnavailable: oe4Controller.rssiUnavailable,
                    onWatchdogChanged: deviceId == null
                        ? null
                        : (enabled) => oe4Controller.setWatchdogEnabled(
                            deviceId,
                            enabled,
                          ),
                  ),
                  const SizedBox(height: 14),
                  _GotoCard(
                    formKey: _formKey,
                    altController: _altController,
                    azController: _azController,
                    altValidator: _validateAlt,
                    azValidator: _validateAz,
                    enabled: isConnected,
                    isSending: oe4Controller.isSending,
                    canSend: _canSendGoto(isConnected),
                    onSend: () => _sendManualGoto(deviceId, oe4Controller),
                  ),
                  const SizedBox(height: 14),
                  _ExpectedCaseCard(
                    enabled: isConnected,
                    isSending: oe4Controller.isSending,
                    onSendExpected: () =>
                        _sendGoto(deviceId, oe4Controller, alt: 90, az: 180),
                  ),
                  const SizedBox(height: 14),
                  _RoutineCard(
                    enabled: isConnected,
                    isSending: oe4Controller.isSending,
                    useWideActions: useWideActions,
                    onHome: () => _sendIfReady(
                      deviceId,
                      () => oe4Controller.sendHome(deviceId!),
                    ),
                    onStatus: () => _sendIfReady(
                      deviceId,
                      () => oe4Controller.sendStatus(deviceId!),
                    ),
                    onStop: () => _sendIfReady(
                      deviceId,
                      () => oe4Controller.sendStop(deviceId!),
                    ),
                    onTestRoutine: () => _sendIfReady(
                      deviceId,
                      () => oe4Controller.sendTestRoutine(deviceId!),
                    ),
                    onGoto045: () =>
                        _sendGoto(deviceId, oe4Controller, alt: 0, az: 45),
                    onGoto030: () =>
                        _sendGoto(deviceId, oe4Controller, alt: 0, az: 30),
                    onGoto0120: () =>
                        _sendGoto(deviceId, oe4Controller, alt: 0, az: 120),
                  ),
                  const SizedBox(height: 14),
                  const _EvidenceCard(),
                ],
              );
            },
          );
        },
      ),
    );
  }

  bool _canSendGoto(bool isConnected) {
    return isConnected && _parseAlt() != null && _parseAz() != null;
  }

  Future<void> _sendManualGoto(
    String? deviceId,
    Oe4ControlController controller,
  ) async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final alt = _parseAlt();
    final az = _parseAz();
    if (alt == null || az == null) return;

    await _sendGoto(deviceId, controller, alt: alt, az: az);
  }

  Future<void> _sendGoto(
    String? deviceId,
    Oe4ControlController controller, {
    required double alt,
    required double az,
  }) {
    return _sendIfReady(
      deviceId,
      () => controller.sendGoto(deviceId!, alt: alt, az: az),
    );
  }

  Future<void> _sendIfReady(
    String? deviceId,
    Future<void> Function() send,
  ) async {
    if (deviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conecta el ESP32 por BLE primero.')),
      );
      return;
    }
    await send();
  }

  double? _parseAlt() {
    final value = _parseNumber(_altController.text);
    if (value == null || value < -90 || value > 90) return null;
    return value;
  }

  double? _parseAz() {
    final value = _parseNumber(_azController.text);
    if (value == null || value < 0 || value > 360) return null;
    return value;
  }

  double? _parseNumber(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  String? _validateAlt(String? value) {
    final number = _parseNumber(value ?? '');
    if (number == null) return 'Ingresa una altitud válida';
    if (number < -90 || number > 90) return 'Rango permitido: -90 a 90';
    return null;
  }

  String? _validateAz(String? value) {
    final number = _parseNumber(value ?? '');
    if (number == null) return 'Ingresa un azimut válido';
    if (number < 0 || number > 360) return 'Rango permitido: 0 a 360';
    return null;
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _Oe4Card(
      accent: colorScheme.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.secondary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colorScheme.secondary.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(
                  Icons.precision_manufacturing_rounded,
                  color: colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Control Electromecánico OE4',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Envío de coordenadas Alt/Az al ESP32 para validar movimiento de motores paso a paso.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  final bool isConnected;
  final String? deviceName;
  final String? lastSentCommand;
  final String? lastResponse;
  final String? errorMessage;

  const _ConnectionCard({
    required this.isConnected,
    required this.deviceName,
    required this.lastSentCommand,
    required this.lastResponse,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = isConnected ? colorScheme.secondary : colorScheme.error;

    return _Oe4Card(
      title: 'Estado de conexion',
      icon: Icons.bluetooth_connected_rounded,
      accent: statusColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusPill(
            label: isConnected ? 'BLE: Conectado' : 'BLE: Desconectado',
            color: statusColor,
          ),
          const SizedBox(height: 12),
          _InfoLine(
            label: 'Dispositivo',
            value: isConnected
                ? (deviceName ?? 'ESP32 conectado')
                : 'Sin conexion',
          ),
          const SizedBox(height: 8),
          _MonospaceBlock(
            label: 'Ultimo comando enviado',
            value: lastSentCommand ?? 'Sin comandos enviados',
          ),
          const SizedBox(height: 10),
          _MonospaceBlock(
            label: 'Última respuesta BLE Notify',
            value: lastResponse ?? 'Sin respuesta recibida',
            accent: colorScheme.secondary,
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 10),
            _InlineNotice(
              icon: Icons.error_outline_rounded,
              message: errorMessage!,
              color: colorScheme.error,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReliabilityCard extends StatelessWidget {
  static const Color _okColor = Color(0xFF22C55E);
  static const Color _riskColor = Color(0xFFF59E0B);
  static const Color _criticalColor = Color(0xFFEF4444);

  final bool isConnected;
  final bool heartbeatActive;
  final DateTime? lastPongReceivedAt;
  final bool watchdogEnabled;
  final bool isTogglingWatchdog;
  final String? lastEsp32Alert;
  final int? currentRssi;
  final bool rssiUnavailable;
  final ValueChanged<bool>? onWatchdogChanged;

  const _ReliabilityCard({
    required this.isConnected,
    required this.heartbeatActive,
    required this.lastPongReceivedAt,
    required this.watchdogEnabled,
    required this.isTogglingWatchdog,
    required this.lastEsp32Alert,
    required this.currentRssi,
    required this.rssiUnavailable,
    required this.onWatchdogChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final heartbeatColor = isConnected && heartbeatActive
        ? _okColor
        : colorScheme.error;
    final watchdogColor = watchdogEnabled ? _riskColor : colorScheme.secondary;
    final rssiColor = _rssiStatusColor(colorScheme);
    final canToggleWatchdog = isConnected && !isTogglingWatchdog;

    return _Oe4Card(
      title: 'Confiabilidad y cobertura',
      icon: Icons.health_and_safety_rounded,
      accent: rssiColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ReliabilityTile(
                label: 'Heartbeat',
                value: isConnected && heartbeatActive ? 'Activo' : 'Inactivo',
                color: heartbeatColor,
                icon: Icons.favorite_rounded,
              ),
              _ReliabilityTile(
                label: 'RSSI actual',
                value: _rssiValue,
                color: rssiColor,
                icon: Icons.network_check_rounded,
              ),
              _ReliabilityTile(
                label: 'Estado RSSI',
                value: _rssiStatus,
                color: rssiColor,
                icon: Icons.shield_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'Switch Watchdog activo',
            toggled: watchdogEnabled,
            child: Container(
              decoration: BoxDecoration(
                color: watchdogColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: watchdogColor.withValues(alpha: 0.24),
                ),
              ),
              child: SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                value: isConnected && watchdogEnabled,
                onChanged: canToggleWatchdog ? onWatchdogChanged : null,
                title: Text(
                  'Watchdog activo',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Text(
                  watchdogEnabled
                      ? 'Prueba activa: STOP si PING se pierde por más de 1000 ms.'
                      : 'Desactivado para no interferir con pruebas normales.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _MonospaceBlock(
            label: 'Ultimo PONG recibido',
            value: _formatPong(lastPongReceivedAt),
            accent: heartbeatColor,
          ),
          const SizedBox(height: 10),
          _MonospaceBlock(
            label: 'Última alerta del ESP32',
            value: lastEsp32Alert ?? 'Sin alertas',
            accent: lastEsp32Alert == null
                ? colorScheme.secondary
                : colorScheme.error,
          ),
          const SizedBox(height: 10),
          _InlineNotice(
            icon: Icons.info_outline_rounded,
            color: colorScheme.secondary,
            message:
                'Umbrales RSSI preventivos: OK >= -70 dBm, Riesgo -71 a -85 dBm, Crítico < -85 dBm. Se ajustan con mediciones reales.',
          ),
        ],
      ),
    );
  }

  String get _rssiValue {
    if (!isConnected) return 'Sin BLE';
    if (rssiUnavailable) return 'RSSI no disponible';
    final rssi = currentRssi;
    if (rssi == null) return 'Leyendo...';
    return '$rssi dBm';
  }

  String get _rssiStatus {
    if (!isConnected) return 'Desconectado';
    if (rssiUnavailable || currentRssi == null) return 'Sin dato';
    if (currentRssi! >= -70) return 'OK';
    if (currentRssi! >= -85) return 'Riesgo';
    return 'Crítico';
  }

  Color _rssiStatusColor(ColorScheme colorScheme) {
    if (!isConnected) return colorScheme.error;
    if (rssiUnavailable || currentRssi == null) return colorScheme.secondary;
    if (currentRssi! >= -70) return _okColor;
    if (currentRssi! >= -85) return _riskColor;
    return _criticalColor;
  }

  String _formatPong(DateTime? value) {
    if (!isConnected) return 'Sin conexion BLE';
    if (value == null) return 'Sin PONG recibido';

    String two(int input) => input.toString().padLeft(2, '0');
    String three(int input) => input.toString().padLeft(3, '0');
    return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}.${three(value.millisecond)}';
  }
}

class _ReliabilityTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _ReliabilityTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 145, maxWidth: 210),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _StatusPill(label: value, color: color),
          ],
        ),
      ),
    );
  }
}

class _GotoCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController altController;
  final TextEditingController azController;
  final String? Function(String?) altValidator;
  final String? Function(String?) azValidator;
  final bool enabled;
  final bool isSending;
  final bool canSend;
  final VoidCallback onSend;

  const _GotoCard({
    required this.formKey,
    required this.altController,
    required this.azController,
    required this.altValidator,
    required this.azValidator,
    required this.enabled,
    required this.isSending,
    required this.canSend,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return _Oe4Card(
      title: 'Comando GOTO',
      icon: Icons.gps_fixed_rounded,
      child: Form(
        key: formKey,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _DegreeField(
                    controller: altController,
                    label: 'Altitud',
                    helper: '-90 a 90 grados',
                    enabled: enabled && !isSending,
                    validator: altValidator,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DegreeField(
                    controller: azController,
                    label: 'Azimut',
                    helper: '0 a 360 grados',
                    enabled: enabled && !isSending,
                    validator: azValidator,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canSend && !isSending ? onSend : null,
                icon: isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: const Text('Enviar GOTO'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpectedCaseCard extends StatelessWidget {
  final bool enabled;
  final bool isSending;
  final VoidCallback onSendExpected;

  const _ExpectedCaseCard({
    required this.enabled,
    required this.isSending,
    required this.onSendExpected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _Oe4Card(
      title: 'Caso esperado OE4',
      icon: Icons.rule_rounded,
      accent: colorScheme.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: enabled && !isSending ? onSendExpected : null,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Enviar prueba 90 / 180'),
            ),
          ),
          const SizedBox(height: 12),
          const _FormulaGrid(),
          const SizedBox(height: 10),
          _MonospaceBlock(
            label: 'Comando exacto',
            value: '{"cmd":"GOTO","alt":90,"az":180}',
            accent: colorScheme.secondary,
          ),
        ],
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  final bool enabled;
  final bool isSending;
  final bool useWideActions;
  final VoidCallback onHome;
  final VoidCallback onStatus;
  final VoidCallback onStop;
  final VoidCallback onTestRoutine;
  final VoidCallback onGoto045;
  final VoidCallback onGoto030;
  final VoidCallback onGoto0120;

  const _RoutineCard({
    required this.enabled,
    required this.isSending,
    required this.useWideActions,
    required this.onHome,
    required this.onStatus,
    required this.onStop,
    required this.onTestRoutine,
    required this.onGoto045,
    required this.onGoto030,
    required this.onGoto0120,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = !enabled || isSending;

    return _Oe4Card(
      title: 'Rutina de validación',
      icon: Icons.fact_check_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ActionGrid(
            useWideActions: useWideActions,
            children: [
              _CommandButton(
                label: 'HOME',
                icon: Icons.home_rounded,
                onPressed: disabled ? null : onHome,
              ),
              _CommandButton(
                label: 'STATUS',
                icon: Icons.monitor_heart_rounded,
                onPressed: disabled ? null : onStatus,
              ),
              _CommandButton(
                label: 'STOP',
                icon: Icons.stop_circle_rounded,
                isDanger: true,
                onPressed: !enabled ? null : onStop,
              ),
              _CommandButton(
                label: 'TEST_ROUTINE',
                icon: Icons.playlist_play_rounded,
                onPressed: disabled ? null : onTestRoutine,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'GOTOs rápidos de validación manual',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _ActionGrid(
            useWideActions: useWideActions,
            children: [
              _CommandButton(
                label: 'GOTO 0 / 45',
                icon: Icons.near_me_rounded,
                onPressed: disabled ? null : onGoto045,
              ),
              _CommandButton(
                label: 'GOTO 0 / 30',
                icon: Icons.near_me_rounded,
                onPressed: disabled ? null : onGoto030,
              ),
              _CommandButton(
                label: 'GOTO 0 / 120',
                icon: Icons.near_me_rounded,
                onPressed: disabled ? null : onGoto0120,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _SequenceReference(),
        ],
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _Oe4Card(
      title: 'Evidencia esperada',
      icon: Icons.assignment_turned_in_rounded,
      accent: colorScheme.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MonospaceBlock(
            label: 'Verificar en consola ESP32',
            value:
                'Comando: Volver a Cero -> posición interna actual: alt=0 pasos, az=0 pasos',
            accent: colorScheme.secondary,
          ),
          const SizedBox(height: 12),
          _InlineNotice(
            icon: Icons.info_outline_rounded,
            color: colorScheme.secondary,
            message:
                'La validación corresponde a un sistema en lazo abierto. El contador interno puede volver a cero, pero sin encoder no se garantiza precisión física absoluta.',
          ),
        ],
      ),
    );
  }
}

class _DegreeField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String helper;
  final bool enabled;
  final String? Function(String?) validator;

  const _DegreeField({
    required this.controller,
    required this.label,
    required this.helper,
    required this.enabled,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      validator: validator,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9,.]'))],
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        suffixText: 'deg',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _Oe4Card extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Widget child;
  final Color? accent;

  const _Oe4Card({this.title, this.icon, required this.child, this.accent});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = accent ?? colorScheme.primary;

    return Card(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accentColor.withValues(alpha: 0.10),
              colorScheme.surface.withValues(alpha: 0.02),
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null && icon != null) ...[
              Row(
                children: [
                  Icon(icon, color: accentColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyMedium,
        children: [
          TextSpan(
            text: '$label: ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

class _MonospaceBlock extends StatelessWidget {
  final String label;
  final String value;
  final Color? accent;

  const _MonospaceBlock({
    required this.label,
    required this.value,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = accent ?? colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accentColor.withValues(alpha: 0.18)),
          ),
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface,
              fontFamily: 'monospace',
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineNotice extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const _InlineNotice({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.22)),
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

class _FormulaGrid extends StatelessWidget {
  const _FormulaGrid();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _MetricTile(label: 'STEPS_PER_REV', value: '4096'),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _MetricTile(label: 'Altitud 90 deg', value: '1024 pasos'),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _MetricTile(label: 'Azimut 180 deg', value: '2048 pasos'),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.secondary.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontFamily: 'monospace',
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  final bool useWideActions;
  final List<Widget> children;

  const _ActionGrid({required this.useWideActions, required this.children});

  @override
  Widget build(BuildContext context) {
    if (useWideActions) {
      return Wrap(spacing: 10, runSpacing: 10, children: children);
    }

    return Column(
      children: children
          .map(
            (child) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(width: double.infinity, child: child),
            ),
          )
          .toList(),
    );
  }
}

class _CommandButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isDanger;
  final VoidCallback? onPressed;

  const _CommandButton({
    required this.label,
    required this.icon,
    this.isDanger = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (isDanger) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
          side: BorderSide(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _SequenceReference extends StatelessWidget {
  const _SequenceReference();

  @override
  Widget build(BuildContext context) {
    return _MonospaceBlock(
      label: 'Secuencia manual de validación',
      value:
          '1. HOME\n2. GOTO alt=0 az=45\n3. GOTO alt=0 az=30\n4. GOTO alt=0 az=120\n5. HOME\n6. STATUS',
      accent: Theme.of(context).colorScheme.primary,
    );
  }
}
