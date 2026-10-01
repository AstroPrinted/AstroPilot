import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../data/models/ble_device_state.dart';
import '../../domain/ble_service.dart';
import '../../../calibration/domain/services/alignment_session.dart';

class BleConnectionController extends ChangeNotifier {
  final BleService _bleService;
  BleConnectionState _state = const BleConnectionState();
  StreamSubscription? _scanSubscription;
  StreamSubscription? _bluetoothSubscription;
  StreamSubscription? _connectionSubscription;
  Timer? _connectionTimeoutTimer;

  BleConnectionState get state => _state;

  BleConnectionController(this._bleService);

  bool _initialized = false;

  /// Pide permisos y empieza a escuchar el estado del Bluetooth. Llamarlo de
  /// nuevo solo vuelve a pedir los permisos.
  Future<void> init() async {
    if (_initialized) return requestPermissions();
    _initialized = true;
    final perms = await _requestPermissions();
    final btEnabled = perms && await _bleService.isBluetoothEnabled();

    _state = _state.copyWith(
      isBluetoothEnabled: btEnabled,
      arePermissionsGranted: perms,
    );
    notifyListeners();

    _bluetoothSubscription = _bleService.bluetoothStateStream.listen((enabled) {
      _state = _state.copyWith(isBluetoothEnabled: enabled);
      notifyListeners();
    });
  }

  Future<bool> _requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // iOS has one Bluetooth permission; GPS is requested in Settings.
      return (await Permission.bluetooth.request()).isGranted;
    }

    final status = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    return status.values.every((s) => s.isGranted);
  }

  Future<void> requestPermissions() async {
    final perms = await _requestPermissions();
    final btEnabled = perms && await _bleService.isBluetoothEnabled();

    _state = _state.copyWith(
      isBluetoothEnabled: btEnabled,
      arePermissionsGranted: perms,
      errorMessage: perms
          ? null
          : 'Permisos denegados. Abre configuración para habilitarlos.',
    );
    notifyListeners();
  }

  Future<void> toggleScan() async {
    if (!_state.isBluetoothEnabled) {
      _state = _state.copyWith(
        errorMessage: 'Bluetooth está desactivado. Habilítalo para continuar.',
      );
      notifyListeners();
      return;
    }

    if (!_state.arePermissionsGranted) {
      _state = _state.copyWith(
        errorMessage:
            'Permisos denegados. Abre configuración para habilitarlos.',
      );
      notifyListeners();
      return;
    }

    if (_state.scanStatus == BleScanStatus.scanning) {
      await _bleService.stopScan();
      _scanSubscription?.cancel();
      _state = _state.copyWith(scanStatus: BleScanStatus.stopped);
      notifyListeners();
      return;
    }

    _state = _state.copyWith(
      scanStatus: BleScanStatus.scanning,
      discoveredDevices: [],
      errorMessage: null,
    );
    notifyListeners();

    _scanSubscription = _bleService.scanDevices().listen(
      (devices) {
        _state = _state.copyWith(discoveredDevices: devices);
        notifyListeners();
      },
      onError: (Object error) {
        _state = _state.copyWith(
          scanStatus: BleScanStatus.stopped,
          errorMessage:
              'No se pudo buscar dispositivos. Revisa Bluetooth y los permisos e intenta de nuevo.',
        );
        notifyListeners();
      },
      cancelOnError: true,
    );
  }

  Future<void> connectToDevice(BleDevice device) async {
    AlignmentSession.invalidate();
    await _connectionSubscription?.cancel();
    _state = _state.copyWith(
      connectionStatus: BleConnectionStatus.connecting,
      errorMessage: null,
    );
    notifyListeners();

    _connectionTimeoutTimer = Timer(const Duration(seconds: 15), () {
      if (_state.connectionStatus == BleConnectionStatus.connecting) {
        _state = _state.copyWith(
          connectionStatus: BleConnectionStatus.error,
          errorMessage: 'No se pudo conectar. Intenta de nuevo.',
        );
        notifyListeners();
      }
    });

    try {
      await _bleService.connectToDevice(device.id);
      _connectionTimeoutTimer?.cancel();
      _state = _state.copyWith(
        connectionStatus: BleConnectionStatus.connected,
        connectedDevice: device,
        scanStatus: BleScanStatus.stopped,
      );
      await _bleService.stopScan();
      _scanSubscription?.cancel();
      _connectionSubscription = _bleService
          .connectionStatusStream(device.id)
          .listen((status) {
            if (status == BleConnectionStatus.disconnected) {
              AlignmentSession.invalidate();
            }
            if (_state.connectedDevice?.id != device.id &&
                status != BleConnectionStatus.disconnected) {
              return;
            }

            _state = _state.copyWith(
              connectionStatus: status,
              connectedDevice: status == BleConnectionStatus.disconnected
                  ? null
                  : _state.connectedDevice,
            );
            notifyListeners();
          });
      notifyListeners();
    } catch (e) {
      _connectionTimeoutTimer?.cancel();
      _state = _state.copyWith(
        connectionStatus: BleConnectionStatus.error,
        errorMessage: 'No se pudo conectar. Intenta de nuevo.',
      );
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    AlignmentSession.invalidate();
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    if (_state.connectedDevice != null) {
      await _bleService.disconnectDevice(_state.connectedDevice!.id);
    }
    _state = _state.copyWith(
      connectionStatus: BleConnectionStatus.disconnected,
      connectedDevice: null,
    );
    notifyListeners();
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _bluetoothSubscription?.cancel();
    _connectionSubscription?.cancel();
    _connectionTimeoutTimer?.cancel();
    _bleService.stopScan();
    super.dispose();
  }
}
