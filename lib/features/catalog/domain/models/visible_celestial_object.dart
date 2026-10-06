import '../../../observation/domain/models/alt_az_result.dart';
import 'celestial_object.dart';

class VisibleCelestialObject {
  final CelestialObject object;
  final AltAzResult? position;
  final bool isVisible;
  final bool isNearHorizon;
  final String? blockedReason;

  /// Visible, pero dentro de la zona prohibida alrededor del Sol.
  final bool isNearSun;

  const VisibleCelestialObject({
    required this.object,
    required this.position,
    required this.isVisible,
    required this.isNearHorizon,
    this.blockedReason,
    this.isNearSun = false,
  });
}
