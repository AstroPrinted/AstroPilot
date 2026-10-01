import 'package:astroprintedlogicincludedgeoengine/features/app_flow/application/app_flow_state.dart';
import 'package:astroprintedlogicincludedgeoengine/features/ble_connection/data/models/ble_device_state.dart';
import 'package:astroprintedlogicincludedgeoengine/features/ble_connection/domain/ble_service.dart';
import 'package:astroprintedlogicincludedgeoengine/features/ble_connection/presentation/controllers/ble_connection_controller.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/services/alignment_session.dart';
import 'package:astroprintedlogicincludedgeoengine/features/settings/application/settings_service.dart';
import 'package:astroprintedlogicincludedgeoengine/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('navigation', () {
    Future<void> pumpApp(WidgetTester tester, {required bool onboarded}) async {
      SharedPreferences.setMockInitialValues({
        'app_flow.onboarding_done': onboarded,
      });
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        AstroPilotApp(
          settingsService: SettingsService(),
          prefs: prefs,
          initializeBle: false,
        ),
      );
      await tester.pump();
    }

    testWidgets('first launch asks for permissions', (tester) async {
      await pumpApp(tester, onboarded: false);

      expect(find.text('Antes de empezar'), findsOneWidget);
      expect(find.text('Dar permisos'), findsOneWidget);
    });

    testWidgets('home offers both modes after onboarding', (tester) async {
      await pumpApp(tester, onboarded: true);

      expect(find.text('¿Qué quieres hacer hoy?'), findsOneWidget);
      expect(find.text('Observación'), findsOneWidget);
      expect(find.text('Educativo'), findsOneWidget);
      expect(find.text('Empezar'), findsOneWidget);
    });

    testWidgets('observation starts at the connection step', (tester) async {
      await pumpApp(tester, onboarded: true);
      await tester.tap(find.text('Observación'));
      await tester.pumpAndSettle();

      expect(find.text('Paso 1 de 5'), findsOneWidget);
      expect(find.text('Buscar dispositivos'), findsOneWidget);
      // Sin conexión aparece la pestaña Conexión además de las otras tres.
      for (final tab in ['Conexión', 'Alineación', 'Catálogo', 'Técnico']) {
        expect(find.text(tab), findsWidgets);
      }
    });

    testWidgets('education has catalog, quiz and satellites', (tester) async {
      await pumpApp(tester, onboarded: true);
      await tester.tap(find.text('Educativo'));
      await tester.pumpAndSettle();

      expect(find.text('Catálogo Celestial'), findsOneWidget);
      expect(find.text('Quiz'), findsOneWidget);
      expect(find.text('Satélites'), findsOneWidget);
    });
  });

  group('AppFlowState', () {
    late _FakeConnection connection;
    late AppFlowState flow;

    setUp(() {
      connection = _FakeConnection()..setConnected(true);
      flow = AppFlowState(connection: connection);
    });

    tearDown(() {
      flow.dispose();
      connection.dispose();
    });

    test('a dropped connection loses the 0 / 0 reference', () {
      flow.markZeroFixed();
      // BleConnectionController invalidates first, then reports the drop.
      AlignmentSession.invalidate();
      connection.setConnected(false);

      expect(flow.isZeroFixed, isFalse);
      expect(flow.referenceLost, isTrue);
    });

    test('a manual reference is not reported as a loss', () {
      flow.markZeroFixed();
      AlignmentSession.invalidate();

      expect(flow.isZeroFixed, isFalse);
      expect(flow.referenceLost, isFalse);
    });

    test('fixing 0 / 0 again clears the loss', () {
      flow.markZeroFixed();
      AlignmentSession.invalidate();
      connection.setConnected(false);
      connection.setConnected(true);
      flow.markZeroFixed();

      expect(flow.referenceLost, isFalse);
    });

    test('repeating a step reopens the tutorial there', () {
      flow.completeTutorial();
      flow.startTutorialAt(ObservationStep.alignment);

      expect(flow.tutorialCompleted, isFalse);
      expect(flow.tutorialStep, ObservationStep.alignment);
    });
  });
}

class _FakeBleService extends BleService {
  @override
  Stream<bool> get bluetoothStateStream => const Stream.empty();

  @override
  Future<void> stopScan() async {}
}

class _FakeConnection extends BleConnectionController {
  _FakeConnection() : super(_FakeBleService());

  BleConnectionState _fake = const BleConnectionState();

  @override
  BleConnectionState get state => _fake;

  void setConnected(bool connected) {
    _fake = connected
        ? const BleConnectionState(
            connectionStatus: BleConnectionStatus.connected,
            connectedDevice: BleDevice(
              id: 'oe4',
              name: 'AstroPilot-OE4',
              rssi: -50,
              isTelescope: true,
            ),
          )
        : const BleConnectionState();
    notifyListeners();
  }
}
