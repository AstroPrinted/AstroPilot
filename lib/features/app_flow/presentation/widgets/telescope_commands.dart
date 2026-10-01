import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../ble_connection/data/models/ble_device_state.dart';
import '../../../ble_connection/presentation/controllers/ble_connection_controller.dart';
import '../../../oe4_control/presentation/controllers/oe4_control_controller.dart';

/// Comandos al telescopio conectado. Cada uno lanza [StateError] con el
/// mensaje visible si no hay conexión o el ESP32 respondió un error, para
/// que los controladores de alineación y catálogo lo muestren.
class TelescopeCommands {
  final Oe4ControlController oe4;
  final String? deviceId;

  const TelescopeCommands(this.oe4, this.deviceId);

  factory TelescopeCommands.of(BuildContext context) {
    final state = context.read<BleConnectionController>().state;
    final connected =
        state.connectionStatus == BleConnectionStatus.connected &&
        state.connectedDevice != null;
    return TelescopeCommands(
      context.read<Oe4ControlController>(),
      connected ? state.connectedDevice!.id : null,
    );
  }

  bool get isConnected => deviceId != null;

  Future<void> _checked(Future<void> Function(String id) send) async {
    final id = deviceId;
    if (id == null) {
      throw StateError('Conecta el telescopio por Bluetooth primero.');
    }
    await send(id);
    final error = oe4.errorMessage;
    if (error != null) throw StateError(error);
  }

  Future<void> goto(double altitude, double azimuth) => _checked(
    (id) => oe4.sendGoto(id, alt: altitude, az: azimuth, throwOnError: true),
  );

  Future<void> moveBy(double deltaAltitude, double deltaAzimuth) => _checked(
    (id) => oe4.moveBy(
      id,
      deltaAlt: deltaAltitude,
      deltaAz: deltaAzimuth,
      throwOnError: true,
    ),
  );

  Future<void> moveTo(double altitude, double azimuth) => _checked(
    (id) => oe4.moveTo(id, alt: altitude, az: azimuth, throwOnError: true),
  );

  Future<void> stop() => _checked((id) => oe4.sendStop(id));

  Future<void> status() =>
      _checked((id) => oe4.sendStatus(id, throwOnError: true));

  Future<void> setPosition(double altitude, double azimuth) => _checked(
    (id) => oe4.sendSetPosition(
      id,
      alt: altitude,
      az: azimuth,
      throwOnError: true,
    ),
  );

  /// Referencia manual (Nivelación y Técnico): reemplaza la alineación.
  Future<void> setManualReference(double altitude, double azimuth) =>
      _checked((id) => oe4.setManualReference(id, alt: altitude, az: azimuth));
}

/// Texto de un error para mostrarlo en pantalla.
String errorText(Object error) =>
    error is StateError ? error.message : error.toString();
