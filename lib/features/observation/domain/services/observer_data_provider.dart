import '../models/observer_data.dart';

abstract interface class ObserverDataProvider {
  ObserverData current();
}

class QuintaNormalObserverDataProvider implements ObserverDataProvider {
  const QuintaNormalObserverDataProvider();

  static const double latitudeDeg = -33.43;
  static const double longitudeDeg = -70.68;
  static const double heightMeters = 520.0;

  @override
  ObserverData current() {
    return ObserverData(
      latDeg: latitudeDeg,
      lonDeg: longitudeDeg,
      heightMeters: heightMeters,
      utc: DateTime.now().toUtc(),
    );
  }
}
