import 'dart:async';

import 'package:astroprintedlogicincludedgeoengine/features/ble_connection/data/models/ble_device_state.dart';
import 'package:astroprintedlogicincludedgeoengine/features/ble_connection/domain/ble_service.dart';
import 'package:astroprintedlogicincludedgeoengine/features/ble_connection/presentation/controllers/ble_connection_controller.dart';
import 'package:astroprintedlogicincludedgeoengine/features/ble_connection/presentation/screens/connection_screen.dart';
import 'package:astroprintedlogicincludedgeoengine/features/settings/application/settings_service.dart';
import 'package:astroprintedlogicincludedgeoengine/features/settings/domain/models/observer_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeBleService extends BleService {
  int adapterChecks = 0;
  bool failScan = false;

  @override
  Future<bool> isBluetoothEnabled() async {
    adapterChecks++;
    return true;
  }

  @override
  Stream<bool> get bluetoothStateStream => const Stream.empty();

  @override
  Stream<List<BleDevice>> scanDevices() => failScan
      ? Stream.error(StateError('Bluetooth unavailable'))
      : Stream.value(const [
          BleDevice(id: 'ios-device-uuid', name: 'AstroPilot-OE4', rssi: -50),
        ]);

  @override
  Future<void> stopScan() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
  final requestedPermissions = <int>[];
  var grantPermissions = true;
  late FakeBleService service;
  late BleConnectionController controller;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    requestedPermissions.clear();
    grantPermissions = true;
    service = FakeBleService();
    controller = BleConnectionController(service);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'requestPermissions') {
            final permissions = List<int>.from(call.arguments as List);
            requestedPermissions.addAll(permissions);
            return {
              for (final permission in permissions)
                permission: grantPermissions ? 1 : 4,
            };
          }
          if (call.method == 'checkPermissionStatus') return 0;
          if (call.method == 'openAppSettings') return true;
          throw StateError('Unexpected permission call: ${call.method}');
        });
  });

  tearDown(() {
    controller.dispose();
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'iOS can scan with Bluetooth permission and no GPS permission',
    () async {
      await controller.init();
      expect(requestedPermissions, [Permission.bluetooth.value]);
      expect(controller.state.arePermissionsGranted, isTrue);
      await controller.toggleScan();
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.discoveredDevices.single.id, 'ios-device-uuid');
    },
  );

  test('Android keeps its scan, connect and location permissions', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await controller.init();
    expect(requestedPermissions, [
      Permission.bluetoothScan.value,
      Permission.bluetoothConnect.value,
      Permission.locationWhenInUse.value,
    ]);
  });

  test('denial prevents scanning and permission retry recovers', () async {
    grantPermissions = false;
    await controller.init();
    expect(controller.state.arePermissionsGranted, isFalse);
    expect(service.adapterChecks, 0);
    await controller.toggleScan();
    expect(controller.state.scanStatus, BleScanStatus.idle);

    grantPermissions = true;
    await controller.requestPermissions();
    expect(controller.state.arePermissionsGranted, isTrue);
    expect(controller.state.isBluetoothEnabled, isTrue);
  });

  testWidgets(
    'denial shows the Settings action even when Bluetooth is unavailable',
    (tester) async {
      grantPermissions = false;
      await controller.init();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: controller,
          child: const MaterialApp(home: ConnectionScreen()),
        ),
      );
      expect(find.text('Abrir configuración de la app'), findsOneWidget);
      expect(find.text('Solicitar permisos'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  test(
    'scan failure is recoverable instead of an unhandled stream error',
    () async {
      await controller.init();
      service.failScan = true;
      await controller.toggleScan();
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.scanStatus, BleScanStatus.stopped);
      expect(controller.state.errorMessage, contains('No se pudo buscar'));
      service.failScan = false;
      await controller.toggleScan();
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.discoveredDevices, hasLength(1));
    },
  );

  test(
    'GPS requests foreground location and falls back to manual on denial',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      await settings.init();
      grantPermissions = false;
      await settings.toggleAutoMode(true);
      expect(requestedPermissions, [Permission.locationWhenInUse.value]);
      expect(settings.state.status, LocationStatus.permissionDenied);
      expect(settings.isAutoMode, isFalse);
      expect(settings.state.isLoadingLocation, isFalse);
    },
  );
}
