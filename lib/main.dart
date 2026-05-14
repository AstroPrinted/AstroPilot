import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'features/catalog/data/repository/celestial_catalog_repository.dart';
import 'features/catalog/presentation/screens/catalog_screen.dart';
import 'features/ble_connection/domain/ble_service.dart';
import 'features/ble_connection/presentation/controllers/ble_connection_controller.dart';
import 'features/ble_connection/presentation/screens/connection_screen.dart';
import 'features/ble_connection/shared/widgets/bottom_nav_shell.dart';
import 'features/oe4_control/domain/motor_command_service.dart';
import 'features/oe4_control/presentation/controllers/oe4_control_controller.dart';
import 'features/oe4_control/presentation/screens/oe4_control_screen.dart';
import 'features/settings/application/settings_service.dart';
import 'features/settings/presentation/screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CelestialCatalogRepository().initialize();
  final settingsService = SettingsService();
  await settingsService.init();
  runApp(AstroPilotApp(settingsService: settingsService));
}

class AstroPilotApp extends StatelessWidget {
  final SettingsService settingsService;
  final bool initializeBle;

  const AstroPilotApp({
    super.key,
    required this.settingsService,
    this.initializeBle = true,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsService),
        ChangeNotifierProvider(
          create: (_) {
            final controller = BleConnectionController(BleService());
            if (initializeBle) controller.init();
            return controller;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => Oe4ControlController(MotorCommandService()),
        ),
      ],
      child: MaterialApp(
        title: 'AstroPilot',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const BottomNavShell(
          tabs: [
            ConnectionScreen(),
            CatalogScreen(),
            Oe4ControlScreen(),
            SettingsScreen(),
          ],
        ),
      ),
    );
  }
}
