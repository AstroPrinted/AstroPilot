import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/app_flow/application/app_flow_state.dart';
import 'features/app_flow/presentation/screens/home_screen.dart';
import 'features/app_flow/presentation/screens/welcome_screen.dart';
import 'features/calibration/data/calibration_repository.dart';
import 'features/calibration/data/calibration_storage.dart';
import 'features/calibration/domain/services/astronomy_position_service.dart';
import 'features/calibration/domain/services/calibration_service.dart';
import 'features/calibration/domain/services/pointing_correction_service.dart';
import 'features/calibration/presentation/controllers/calibration_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/catalog/data/repository/celestial_catalog_repository.dart';
import 'features/ble_connection/domain/ble_service.dart';
import 'features/ble_connection/presentation/controllers/ble_connection_controller.dart';
import 'features/observation/domain/services/sun_guard.dart';
import 'features/oe4_control/domain/motor_command_service.dart';
import 'features/oe4_control/presentation/controllers/oe4_control_controller.dart';
import 'features/settings/application/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CelestialCatalogRepository().initialize();
  final settingsService = SettingsService();
  await settingsService.init();
  final prefs = await SharedPreferences.getInstance();
  runApp(AstroPilotApp(settingsService: settingsService, prefs: prefs));
}

class AstroPilotApp extends StatelessWidget {
  final SettingsService settingsService;
  final SharedPreferences? prefs;
  final bool initializeBle;

  const AstroPilotApp({
    super.key,
    required this.settingsService,
    this.prefs,
    this.initializeBle = true,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsService),
        ChangeNotifierProvider(
          create: (_) => BleConnectionController(BleService()),
        ),
        ChangeNotifierProvider(
          create: (context) {
            final flow = AppFlowState(
              connection: context.read<BleConnectionController>(),
              prefs: prefs,
            );
            // The first launch asks for permissions from the welcome screen.
            if (initializeBle && flow.onboardingDone) {
              context.read<BleConnectionController>().init();
            }
            return flow;
          },
          lazy: false,
        ),
        ChangeNotifierProvider(
          // Starts the heartbeat and the STATUS reads as soon as it connects.
          lazy: false,
          create: (context) => Oe4ControlController(
            MotorCommandService(),
            connection: context.read<BleConnectionController>(),
            sunGuard: SunGuard(
              observerDataProvider: context.read<SettingsService>(),
            ),
          ),
        ),
        ChangeNotifierProvider(
          lazy: false,
          create: (context) => CalibrationController(
            catalogRepository: CelestialCatalogRepository(),
            calibrationRepository: CalibrationRepository(
              storage: CalibrationStorage(),
            ),
            astronomyPositionService: const AstronomyPositionService(),
            calibrationService: const CalibrationService(
              correctionService: PointingCorrectionService(),
            ),
            observerDataProvider: context.read<SettingsService>(),
            sunGuard: SunGuard(
              observerDataProvider: context.read<SettingsService>(),
            ),
            motorPositionProvider: () =>
                context.read<Oe4ControlController>().motorPosition,
          )..loadSavedCalibration(),
        ),
      ],
      child: MaterialApp(
        title: 'AstroPilot',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const _AppRoot(),
      ),
    );
  }
}

/// Bienvenida la primera vez; después, Inicio.
class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    final done = context.select<AppFlowState, bool>((s) => s.onboardingDone);
    return done ? const HomeScreen() : const WelcomeScreen();
  }
}
