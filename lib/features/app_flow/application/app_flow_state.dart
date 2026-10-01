import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ble_connection/data/models/ble_device_state.dart';
import '../../ble_connection/presentation/controllers/ble_connection_controller.dart';
import '../../calibration/domain/services/alignment_session.dart';
import '../../catalog/domain/models/celestial_object.dart';

/// Pasos del tutorial de Observación.
enum ObservationStep {
  connection('Conexión'),
  leveling('Nivelación'),
  alignment('Alineación'),
  fineAdjust('Ajuste fino'),
  catalog('Catálogo');

  final String label;
  const ObservationStep(this.label);
}

/// Pestañas del modo Observación. Conexión solo aparece sin conexión.
enum ObservationTab { connection, alignment, catalog, technical }

/// Estado de navegación que comparten Inicio, Observación y Educativo. La
/// posición del telescopio y la alineación siguen en sus controladores; aquí
/// solo vive lo que el flujo necesita recordar entre pantallas.
class AppFlowState extends ChangeNotifier {
  static const _onboardingKey = 'app_flow.onboarding_done';

  final BleConnectionController? connection;
  final SharedPreferences? _prefs;

  bool _onboardingDone;
  DateTime? _zeroFixedAt;
  bool _fineAdjustSkipped = false;
  bool _tutorialCompleted = false;
  bool _referenceLost = false;
  bool _wasConnected = false;
  bool _invalidatedReference = false;
  CelestialObject? _pendingObject;
  ObservationTab? _requestedTab;
  ObservationStep _tutorialStep = ObservationStep.connection;
  ({double altitude, double azimuth})? _alignmentCorrection;

  AppFlowState({this.connection, SharedPreferences? prefs})
    : _prefs = prefs,
      _onboardingDone = prefs?.getBool(_onboardingKey) ?? false {
    _wasConnected = isConnected;
    connection?.addListener(_onConnectionChanged);
    AlignmentSession.changes.addListener(_onReferenceChanged);
  }

  static Future<AppFlowState> load({
    BleConnectionController? connection,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return AppFlowState(connection: connection, prefs: prefs);
  }

  bool get onboardingDone => _onboardingDone;
  DateTime? get zeroFixedAt => _zeroFixedAt;
  bool get isZeroFixed => _zeroFixedAt != null;
  bool get fineAdjustSkipped => _fineAdjustSkipped;
  bool get tutorialCompleted => _tutorialCompleted;
  CelestialObject? get pendingObject => _pendingObject;

  /// Cuánto se corrigió la referencia 0 / 0 al centrar la estrella
  /// (objetivo menos posición al confirmar).
  ({double altitude, double azimuth})? get alignmentCorrection =>
      _alignmentCorrection;

  void setAlignmentCorrection(({double altitude, double azimuth})? value) {
    _alignmentCorrection = value;
    notifyListeners();
  }

  /// Paso que muestra el tutorial (pestaña Alineación).
  ObservationStep get tutorialStep => _tutorialStep;

  /// La referencia del telescopio se perdió por una desconexión.
  bool get referenceLost => _referenceLost;

  bool get isConnected =>
      connection?.state.connectionStatus == BleConnectionStatus.connected &&
      connection?.state.connectedDevice != null;

  Future<void> completeOnboarding() async {
    _onboardingDone = true;
    notifyListeners();
    await _prefs?.setBool(_onboardingKey, true);
  }

  void markZeroFixed() {
    _zeroFixedAt = DateTime.now();
    _referenceLost = false;
    notifyListeners();
  }

  void skipFineAdjust() {
    _fineAdjustSkipped = true;
    notifyListeners();
  }

  void clearFineAdjustSkip() {
    if (!_fineAdjustSkipped) return;
    _fineAdjustSkipped = false;
    notifyListeners();
  }

  void setTutorialStep(ObservationStep step) {
    if (_tutorialStep == step) return;
    _tutorialStep = step;
    notifyListeners();
  }

  /// Vuelve a mostrar el tutorial desde [step] (repetir un paso).
  void startTutorialAt(ObservationStep step) {
    _tutorialCompleted = false;
    _tutorialStep = step;
    notifyListeners();
  }

  void completeTutorial() {
    _tutorialCompleted = true;
    notifyListeners();
  }

  void dismissReferenceLost() {
    if (!_referenceLost) return;
    _referenceLost = false;
    notifyListeners();
  }

  void setPendingObject(CelestialObject? object) {
    _pendingObject = object;
    notifyListeners();
  }

  /// Pide a la pantalla de Observación que abra una pestaña al mostrarse.
  void requestTab(ObservationTab tab) {
    _requestedTab = tab;
    notifyListeners();
  }

  ObservationTab? takeRequestedTab() {
    final tab = _requestedTab;
    _requestedTab = null;
    return tab;
  }

  void _onConnectionChanged() {
    final connected = isConnected;
    if (connected == _wasConnected) return;
    // BleConnectionController invalidates the reference just before it
    // reports the dropped connection, so the loss is decided here.
    if (_wasConnected &&
        !connected &&
        (_invalidatedReference || _tutorialCompleted)) {
      _referenceLost = true;
    }
    _invalidatedReference = false;
    _wasConnected = connected;
    notifyListeners();
  }

  void _onReferenceChanged() {
    // A new connection, a disconnection or a manual reference invalidates the
    // 0/0 reference and with it the star alignment. Only a lost connection is
    // reported as a loss; a manual reference is the user's own choice.
    _invalidatedReference = _invalidatedReference || _zeroFixedAt != null;
    _zeroFixedAt = null;
    _fineAdjustSkipped = false;
    _alignmentCorrection = null;
    notifyListeners();
  }

  @override
  void dispose() {
    connection?.removeListener(_onConnectionChanged);
    AlignmentSession.changes.removeListener(_onReferenceChanged);
    super.dispose();
  }
}
