import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/widgets/ap_widgets.dart';
import '../../../../../ble_connection/data/models/ble_device_state.dart';
import '../../../../../ble_connection/presentation/controllers/ble_connection_controller.dart';
import '../../../../../settings/application/settings_service.dart';
import '../../../../../settings/domain/models/observer_state.dart';
import '../../../../../settings/domain/settings_defaults.dart';
import '../../../widgets/mode_scaffold.dart';
import '../../home_screen.dart';
import '../observation_progress.dart';

/// Paso 1: conectar el telescopio y revisar ubicación y hora.
class ConnectionStep extends StatefulWidget {
  final ObservationProgress progress;
  final VoidCallback onNext;

  const ConnectionStep({
    super.key,
    required this.progress,
    required this.onNext,
  });

  @override
  State<ConnectionStep> createState() => _ConnectionStepState();
}

class _ConnectionStepState extends State<ConnectionStep> {
  String? _connectingId;

  Future<void> _connect(BleConnectionController ble, BleDevice device) async {
    setState(() => _connectingId = device.id);
    await ble.connectToDevice(device);
    if (mounted) setState(() => _connectingId = null);
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleConnectionController>();
    final state = ble.state;
    final settings = context.watch<SettingsService>().state;
    final progress = widget.progress;
    final connected = progress.connected;
    final connecting = state.connectionStatus == BleConnectionStatus.connecting;
    final scanning = state.scanStatus == BleScanStatus.scanning;
    final devices = state.discoveredDevices;

    return ModeBody(
      children: [
        _StatusCard(
          connected: connected,
          connecting: connecting,
          deviceName: state.connectedDevice?.name,
          onDisconnect: ble.disconnect,
        ),
        if (!state.arePermissionsGranted)
          _ActionNotice(
            text:
                'Faltan permisos de Bluetooth. Actívalos en la configuración '
                'de la app para buscar el telescopio.',
            action: 'Abrir configuración de la app',
            onAction: ble.openSettings,
          )
        else if (!state.isBluetoothEnabled)
          const ApNotice(
            icon: Icons.bluetooth_disabled,
            tone: ApTone.warn,
            text: 'Bluetooth está desactivado. Habilítalo para continuar.',
          ),
        if (!connected) ...[
          ApButton(
            label: scanning ? 'Detener búsqueda' : 'Buscar dispositivos',
            icon: scanning ? Icons.stop : Icons.search,
            large: true,
            onPressed: connecting ? null : ble.toggleScan,
          ),
          if (scanning) const ApProgress(),
          if (state.errorMessage != null)
            ApNotice(
              icon: Icons.error_outline,
              tone: ApTone.error,
              text: state.errorMessage!,
            ),
          if (devices.isNotEmpty)
            ApCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              gap: 0,
              children: [
                for (var i = 0; i < devices.length; i++) ...[
                  if (i > 0) const ApDivider(),
                  _DeviceRow(
                    device: devices[i],
                    connecting: _connectingId == devices[i].id && connecting,
                    enabled: !connecting,
                    onConnect: () => _connect(ble, devices[i]),
                  ),
                ],
              ],
            )
          else if (!scanning)
            const ApCard(
              padding: EdgeInsets.fromLTRB(20, 28, 20, 28),
              children: [
                Icon(
                  Icons.bluetooth_searching,
                  size: 48,
                  color: ApColors.muted,
                ),
                Text(
                  'Presiona "Buscar dispositivos" para escanear',
                  textAlign: TextAlign.center,
                  style: ApText.body,
                ),
              ],
            ),
        ],
        _ChecksCard(settings: settings, progress: progress),
        ApButton(
          label: 'Siguiente',
          icon: Icons.arrow_forward,
          iconAfter: true,
          large: true,
          onPressed: progress.isDoneConnection ? widget.onNext : null,
        ),
        if (!progress.isDoneConnection)
          CenteredSmall(
            !connected
                ? 'Conecta el telescopio para continuar.'
                : 'Revisa la configuración para continuar.',
          ),
      ],
    );
  }
}

extension on ObservationProgress {
  bool get isDoneConnection => connected && checksOk;
}

class _StatusCard extends StatelessWidget {
  final bool connected;
  final bool connecting;
  final String? deviceName;
  final VoidCallback onDisconnect;

  const _StatusCard({
    required this.connected,
    required this.connecting,
    required this.deviceName,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final color = connected
        ? ApColors.ok
        : connecting
        ? ApColors.primary
        : const Color(0xFF64748B);
    return ApCard(
      children: [
        const ApStepBadge('Paso 1 de 5'),
        Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.18),
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    connected
                        ? 'Conectado'
                        : connecting
                        ? 'Conectando…'
                        : 'Desconectado',
                    style: ApText.title.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    connected
                        ? deviceName ?? 'AstroPilot-OE4'
                        : 'Busca y conecta el telescopio AstroPilot-OE4',
                    style: ApText.body,
                  ),
                ],
              ),
            ),
            const Icon(Icons.bluetooth, color: ApColors.muted),
          ],
        ),
        if (connected)
          ApButton(
            label: 'Desconectar',
            icon: Icons.link_off,
            kind: ApButtonKind.outlined,
            foreground: ApColors.error,
            onPressed: onDisconnect,
          ),
      ],
    );
  }
}

class _DeviceRow extends StatelessWidget {
  final BleDevice device;
  final bool connecting;
  final bool enabled;
  final VoidCallback onConnect;

  const _DeviceRow({
    required this.device,
    required this.connecting,
    required this.enabled,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final telescope = device.isTelescope;
    final label = connecting ? 'Conectando…' : 'Conectar';
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 14),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          ApListIcon(
            telescope ? Icons.star : Icons.bluetooth,
            color: telescope ? ApColors.secondary : ApColors.muted,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: ApColors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.signal_cellular_alt,
                      size: 16,
                      color: ApColors.muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'RSSI: ${device.rssi} dBm',
                      style: ApText.small
                          .copyWith(fontSize: 12.5)
                          .merge(ApText.number),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          telescope
              ? FilledButton(
                  onPressed: enabled ? onConnect : null,
                  style: style,
                  child: Text(label),
                )
              : OutlinedButton(
                  onPressed: enabled ? onConnect : null,
                  style: style.copyWith(
                    side: const WidgetStatePropertyAll(
                      BorderSide(color: ApColors.outline),
                    ),
                  ),
                  child: Text(label),
                ),
        ],
      ),
    );
  }
}

class _ChecksCard extends StatelessWidget {
  final ObserverState settings;
  final ObservationProgress progress;

  const _ChecksCard({required this.settings, required this.progress});

  /// De dónde salen las coordenadas: GPS, ingresadas a mano, la ubicación
  /// por defecto o un GPS que falló y dejó la manual.
  static String _locationSource(ObserverState s) {
    if (s.isLoadingLocation) return 'obteniendo GPS…';
    final isDefault =
        s.latDeg == SettingsDefaults.defaultLat &&
        s.lonDeg == SettingsDefaults.defaultLon;
    return switch (s.status) {
      LocationStatus.gpsActive => 'GPS',
      LocationStatus.manual when isDefault => 'por defecto: Santiago',
      LocationStatus.manual => 'ingresada a mano',
      LocationStatus.gpsDisabled => 'GPS no disponible, usando la manual',
      LocationStatus.permissionDenied =>
        'sin permiso de GPS, usando la manual',
      LocationStatus.outOfBounds => 'GPS fuera de Chile, usando la manual',
    };
  }

  @override
  Widget build(BuildContext context) {
    final locationText = progress.locationOk
        ? '${settings.latDeg.toStringAsFixed(4)} / '
              '${settings.lonDeg.toStringAsFixed(4)} ✓\n'
              'Ubicación ${_locationSource(settings)}'
        : 'La ubicación está fuera del rango permitido para Chile';
    final timeText = progress.timeOk
        ? 'Usando hora actual ✓'
        : 'Planning Mode activo: ${_formatLocal(settings.observerTime)}';
    final failText = !progress.locationOk
        ? 'Sin una ubicación válida no se puede calcular dónde están los astros.'
        : 'Estás usando una hora planificada. Para observar ahora, activa '
              '"Usar hora actual".';
    void openSettings() => HomeScreen.openSettings(context);

    return ApCard(
      children: [
        const ApCardHead(icon: Icons.checklist, title: 'Antes de empezar'),
        _TappableCheck(
          ok: progress.locationOk,
          title: 'Ubicación',
          detail: locationText,
          onTap: openSettings,
        ),
        _TappableCheck(
          ok: progress.timeOk,
          title: 'Hora',
          detail: timeText,
          onTap: openSettings,
        ),
        if (!progress.checksOk)
          ApNotice(icon: Icons.warning, tone: ApTone.warn, text: failText),
        const Text(
          'Toca Ubicación u Hora para cambiarlas en Configuración (GPS o '
          'coordenadas manuales, hora actual o planificada).',
          style: ApText.small,
        ),
      ],
    );
  }

  static String _formatLocal(DateTime utc) {
    final t = utc.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)}/${t.year} ${two(t.hour)}:${two(t.minute)}';
  }
}

/// Fila de verificación que abre Configuración.
class _TappableCheck extends StatelessWidget {
  final bool ok;
  final String title;
  final String detail;
  final VoidCallback onTap;

  const _TappableCheck({
    required this.ok,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ApColors.surface2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              Expanded(
                child: ApCheckRow(
                  leading: Icon(
                    ok ? Icons.check_circle : Icons.warning,
                    size: 20,
                    color: ok ? ApColors.ok : ApColors.warn,
                  ),
                  title: title,
                  detail: detail,
                ),
              ),
              const Icon(Icons.chevron_right, color: ApColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionNotice extends StatelessWidget {
  final String text;
  final String action;
  final VoidCallback onAction;

  const _ActionNotice({
    required this.text,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ApNotice(icon: Icons.lock, tone: ApTone.warn, text: text),
        const SizedBox(height: 10),
        ApButton(
          label: action,
          icon: Icons.settings,
          kind: ApButtonKind.outlined,
          onPressed: onAction,
        ),
      ],
    );
  }
}
