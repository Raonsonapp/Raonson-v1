import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Чаро ҷой муайян нашуд.
enum LocationFailure { serviceOff, denied, deniedForever, timeout, error }

/// Натиҷаи «Ҷойи ҳозираи ман»: ё координата, ё сабаб.
class LocationOutcome {
  final double? lat;
  final double? lon;
  final LocationFailure? failure;
  const LocationOutcome.fix(double this.lat, double this.lon) : failure = null;
  const LocationOutcome.failed(LocationFailure this.failure)
      : lat = null,
        lon = null;
  bool get ok => failure == null;
}

/// GPS-и телефон (дар тестҳо бо нусхаи сохта иваз мешавад).
abstract class DeviceLocation {
  Future<LocationOutcome> current();
  Future<void> openAppSettings();
  Future<void> openLocationSettings();
}

/// Ба воситаи geolocator. Дақиқии миёна кофист — мо танҳо шаҳр/ноҳияи
/// наздикро меҷӯем, на суроғаро; ин тезтар ва камхарҷтар аст.
class GeolocatorDeviceLocation implements DeviceLocation {
  const GeolocatorDeviceLocation({this.timeLimit = const Duration(seconds: 12)});

  final Duration timeLimit;

  @override
  Future<LocationOutcome> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationOutcome.failed(LocationFailure.serviceOff);
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        return const LocationOutcome.failed(LocationFailure.deniedForever);
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.unableToDetermine) {
        return const LocationOutcome.failed(LocationFailure.denied);
      }
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: timeLimit,
        ).timeout(timeLimit + const Duration(seconds: 2));
        return LocationOutcome.fix(pos.latitude, pos.longitude);
      } on TimeoutException {
        // Дар бино GPS дер мекунад — ҷойи охирини маълум ҳам кофист.
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) return LocationOutcome.fix(last.latitude, last.longitude);
        return const LocationOutcome.failed(LocationFailure.timeout);
      }
    } on LocationServiceDisabledException {
      return const LocationOutcome.failed(LocationFailure.serviceOff);
    } on PermissionDeniedException {
      return const LocationOutcome.failed(LocationFailure.denied);
    } catch (_) {
      return const LocationOutcome.failed(LocationFailure.error);
    }
  }

  @override
  Future<void> openAppSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (_) {}
  }

  @override
  Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (_) {}
  }
}
