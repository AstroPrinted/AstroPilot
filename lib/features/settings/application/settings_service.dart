import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../observation/domain/models/observer_data.dart';
import '../../observation/domain/services/observer_data_provider.dart';
import '../domain/models/observer_state.dart';
import '../domain/settings_defaults.dart';

class SettingsService extends ChangeNotifier implements ObserverDataProvider {
  static final SettingsService _instance = SettingsService._();

  factory SettingsService() => _instance;

  SettingsService._();

  ObserverState _state = ObserverState.defaults();
  SharedPreferences? _prefs;

  ObserverState get state => _state;

  bool get isAutoMode => _state.isAutoMode;

  @override
  ObserverData current() {
    return ObserverData(
      latDeg: _state.latDeg,
      lonDeg: _state.lonDeg,
      heightMeters: _state.heightMeters,
      utc: _state.effectiveUtc,
    );
  }

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    final prefs = _prefs!;

    final lat =
        prefs.getDouble(SettingsKeys.manualLat) ?? SettingsDefaults.defaultLat;
    final lon =
        prefs.getDouble(SettingsKeys.manualLon) ?? SettingsDefaults.defaultLon;
    final validManual = ObserverState.isWithinChile(lat, lon);
    final useCustomTime = prefs.getBool(SettingsKeys.useCustomTime) ?? false;
    final customTimeIso = prefs.getString(SettingsKeys.customTimeIso);

    _state = ObserverState(
      isAutoMode: prefs.getBool(SettingsKeys.autoMode) ?? false,
      latDeg: validManual ? lat : SettingsDefaults.defaultLat,
      lonDeg: validManual ? lon : SettingsDefaults.defaultLon,
      heightMeters:
          prefs.getDouble(SettingsKeys.manualHeight) ??
          SettingsDefaults.defaultHeight,
      observerTime: _parseCustomTime(customTimeIso) ?? DateTime.now().toUtc(),
      isCustomTime: useCustomTime && _parseCustomTime(customTimeIso) != null,
      status: LocationStatus.manual,
      errorMessage: validManual
          ? null
          : 'Coordenadas guardadas fuera de Chile. Usando Santiago.',
    );

    if (!validManual) {
      await _persistManualCoordinates(
        SettingsDefaults.defaultLat,
        SettingsDefaults.defaultLon,
        SettingsDefaults.defaultHeight,
      );
    }

    notifyListeners();

    if (_state.isAutoMode) {
      await _fetchGpsPosition();
    }
  }

  Future<void> toggleAutoMode(bool enabled) async {
    if (!enabled) {
      _state = _state.copyWith(
        isAutoMode: false,
        status: LocationStatus.manual,
        clearErrorMessage: true,
        isLoadingLocation: false,
      );
      await _prefs?.setBool(SettingsKeys.autoMode, false);
      notifyListeners();
      return;
    }

    _state = _state.copyWith(
      isAutoMode: true,
      isLoadingLocation: true,
      clearErrorMessage: true,
    );
    await _prefs?.setBool(SettingsKeys.autoMode, true);
    notifyListeners();
    await _fetchGpsPosition();
  }

  Future<void> setManualCoordinates(
    double latDeg,
    double lonDeg,
    double heightMeters,
  ) async {
    if (!ObserverState.isWithinChile(latDeg, lonDeg)) {
      _state = _state.copyWith(
        status: LocationStatus.outOfBounds,
        errorMessage: 'Ubicación fuera del territorio nacional (Chile).',
      );
      notifyListeners();
      return;
    }

    final normalizedHeight = heightMeters < 0
        ? SettingsDefaults.defaultHeight
        : heightMeters;
    _state = _state.copyWith(
      isAutoMode: false,
      latDeg: latDeg,
      lonDeg: lonDeg,
      heightMeters: normalizedHeight,
      status: LocationStatus.manual,
      clearErrorMessage: true,
      isLoadingLocation: false,
    );
    await _prefs?.setBool(SettingsKeys.autoMode, false);
    await _persistManualCoordinates(latDeg, lonDeg, normalizedHeight);
    notifyListeners();
  }

  Future<void> setCustomTime(DateTime dateTime) async {
    final utc = dateTime.toUtc();
    _state = _state.copyWith(
      observerTime: utc,
      isCustomTime: true,
      clearErrorMessage: true,
    );
    await _prefs?.setBool(SettingsKeys.useCustomTime, true);
    await _prefs?.setString(SettingsKeys.customTimeIso, utc.toIso8601String());
    notifyListeners();
  }

  Future<void> resetToCurrentTime() async {
    _state = _state.copyWith(
      observerTime: DateTime.now().toUtc(),
      isCustomTime: false,
      clearErrorMessage: true,
    );
    await _prefs?.setBool(SettingsKeys.useCustomTime, false);
    await _prefs?.remove(SettingsKeys.customTimeIso);
    notifyListeners();
  }

  Future<void> openSystemSettings() async {
    await openAppSettings();
  }

  Future<void> _fetchGpsPosition() async {
    try {
      final permissionGranted = await _ensureLocationPermission();
      if (!permissionGranted) return;

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _fallbackToManual(
          LocationStatus.gpsDisabled,
          'GPS no disponible. Usando ubicación manual.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      if (!ObserverState.isWithinChile(position.latitude, position.longitude)) {
        await _fallbackToManual(
          LocationStatus.outOfBounds,
          'Ubicación GPS fuera de Chile. Usando ubicación manual.',
        );
        return;
      }

      _state = _state.copyWith(
        isAutoMode: true,
        latDeg: position.latitude,
        lonDeg: position.longitude,
        heightMeters: position.altitude.isFinite
            ? position.altitude.clamp(0.0, double.infinity).toDouble()
            : SettingsDefaults.defaultHeight,
        status: LocationStatus.gpsActive,
        clearErrorMessage: true,
        isLoadingLocation: false,
      );
      notifyListeners();
    } on LocationServiceDisabledException {
      await _fallbackToManual(
        LocationStatus.gpsDisabled,
        'GPS no disponible. Usando ubicación manual.',
      );
    } on TimeoutException {
      await _fallbackToManual(
        LocationStatus.gpsDisabled,
        'No se pudo obtener GPS a tiempo. Usando ubicación manual.',
      );
    } catch (_) {
      await _fallbackToManual(
        LocationStatus.gpsDisabled,
        'No se pudo obtener GPS. Usando ubicación manual.',
      );
    }
  }

  Future<bool> _ensureLocationPermission() async {
    var status = await Permission.locationWhenInUse.status;
    if (status.isDenied) {
      status = await Permission.locationWhenInUse.request();
    }

    if (status.isGranted || status.isLimited) return true;

    await _fallbackToManual(
      LocationStatus.permissionDenied,
      status.isPermanentlyDenied
          ? 'Permiso de ubicación denegado permanentemente. Abre configuración del sistema.'
          : 'Permiso de ubicación denegado. Usa coordenadas manuales.',
    );
    return false;
  }

  Future<void> _fallbackToManual(LocationStatus status, String message) async {
    _state = _state.copyWith(
      isAutoMode: false,
      status: status,
      errorMessage: message,
      isLoadingLocation: false,
    );
    await _prefs?.setBool(SettingsKeys.autoMode, false);
    notifyListeners();
  }

  Future<void> _persistManualCoordinates(
    double latDeg,
    double lonDeg,
    double heightMeters,
  ) async {
    await _prefs?.setDouble(SettingsKeys.manualLat, latDeg);
    await _prefs?.setDouble(SettingsKeys.manualLon, lonDeg);
    await _prefs?.setDouble(SettingsKeys.manualHeight, heightMeters);
  }

  DateTime? _parseCustomTime(String? iso) {
    if (iso == null) return null;
    return DateTime.tryParse(iso)?.toUtc();
  }
}
