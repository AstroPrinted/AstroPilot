import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ap_widgets.dart';
import '../../../ble_connection/presentation/controllers/ble_connection_controller.dart';
import '../../application/app_flow_state.dart';
import '../widgets/telescope_icon.dart';

enum _WelcomeState { initial, requesting, denied, bluetoothOff }

/// Bienvenida y permisos. Solo se muestra la primera vez.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  _WelcomeState _state = _WelcomeState.initial;

  Future<void> _requestPermissions() async {
    setState(() => _state = _WelcomeState.requesting);
    final ble = context.read<BleConnectionController>();
    final flow = context.read<AppFlowState>();
    await ble.init();
    // iOS asks Bluetooth here; location is a separate prompt.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await Permission.locationWhenInUse.request();
    }
    if (!mounted) return;
    _continueIfReady(ble, flow);
  }

  void _continueIfReady(BleConnectionController ble, AppFlowState flow) {
    final state = ble.state;
    if (!state.arePermissionsGranted) {
      setState(() => _state = _WelcomeState.denied);
    } else if (!state.isBluetoothEnabled) {
      setState(() => _state = _WelcomeState.bluetoothOff);
    } else {
      flow.completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 56, 16, 24),
          children: [
            const _Hero(),
            const SizedBox(height: 20),
            switch (_state) {
              _WelcomeState.initial || _WelcomeState.requesting => _Initial(
                busy: _state == _WelcomeState.requesting,
                onRequest: _requestPermissions,
              ),
              _WelcomeState.denied => _Denied(
                onOpenSettings: context.read<BleConnectionController>()
                    .openSettings,
                onRetry: _requestPermissions,
              ),
              _WelcomeState.bluetoothOff => _BluetoothOff(
                onRetry: () => _continueIfReady(
                  context.read<BleConnectionController>(),
                  context.read<AppFlowState>(),
                ),
              ),
            },
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        AppLogo(),
        SizedBox(height: 12),
        Text(
          'AstroPilot',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: ApColors.text,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Controla tu telescopio y aprende astronomía desde el hemisferio sur.',
          textAlign: TextAlign.center,
          style: ApText.body,
        ),
      ],
    );
  }
}

class _Initial extends StatelessWidget {
  final bool busy;
  final VoidCallback onRequest;

  const _Initial({required this.busy, required this.onRequest});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: apSpaced([
        const ApCard(
          children: [
            Text('Antes de empezar', style: ApText.title),
            Text(
              'AstroPilot necesita dos permisos. Solo te los pedimos esta vez.',
              style: ApText.body,
            ),
            _PermissionRow(
              icon: Icons.bluetooth,
              title: 'Bluetooth',
              detail: 'Para conectarse y controlar el telescopio AstroPilot-OE4.',
            ),
            _PermissionRow(
              icon: Icons.location_on,
              title: 'Ubicación',
              detail: 'Para calcular la posición de los astros desde donde estás.',
            ),
          ],
        ),
        ApButton(
          label: 'Dar permisos',
          icon: Icons.verified_user,
          large: true,
          busy: busy,
          onPressed: onRequest,
        ),
        const Text(
          'Puedes cambiar los permisos después desde los ajustes del teléfono.',
          textAlign: TextAlign.center,
          style: ApText.small,
        ),
      ], gap: 14),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return ApCheckRow(
      leading: ApListIcon(icon),
      title: title,
      detail: detail,
    );
  }
}

class _Denied extends StatelessWidget {
  final VoidCallback onOpenSettings;
  final VoidCallback onRetry;

  const _Denied({required this.onOpenSettings, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ApCard(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      gap: 14,
      children: [
        const Icon(Icons.lock, size: 48, color: ApColors.warn),
        const Text(
          'Permiso denegado',
          textAlign: TextAlign.center,
          style: ApText.title,
        ),
        const Text(
          'Sin Bluetooth y ubicación, AstroPilot no puede conectarse al '
          'telescopio ni calcular la posición de los astros. Actívalos desde '
          'la configuración de la app.',
          textAlign: TextAlign.center,
          style: ApText.body,
        ),
        ApButton(
          label: 'Abrir configuración de la app',
          icon: Icons.settings,
          onPressed: onOpenSettings,
        ),
        ApButton(
          label: 'Volver a intentar',
          kind: ApButtonKind.outlined,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

class _BluetoothOff extends StatelessWidget {
  final VoidCallback onRetry;
  const _BluetoothOff({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ApCard(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      gap: 14,
      children: [
        const Icon(Icons.bluetooth_disabled, size: 48, color: ApColors.muted),
        const Text(
          'Bluetooth está desactivado. Habilítalo para continuar.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: ApColors.text),
        ),
        ApButton(
          label: 'Ya lo activé',
          icon: Icons.refresh,
          kind: ApButtonKind.outlined,
          onPressed: onRetry,
        ),
      ],
    );
  }
}
