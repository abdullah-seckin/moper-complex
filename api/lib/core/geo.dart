import 'dart:math';

double distanceMeters({
  required double fromLatitude,
  required double fromLongitude,
  required double toLatitude,
  required double toLongitude,
}) {
  const earthRadiusMeters = 6371000.0;
  final lat1 = _radians(fromLatitude);
  final lat2 = _radians(toLatitude);
  final deltaLat = _radians(toLatitude - fromLatitude);
  final deltaLng = _radians(toLongitude - fromLongitude);
  final a =
      sin(deltaLat / 2) * sin(deltaLat / 2) +
      cos(lat1) * cos(lat2) * sin(deltaLng / 2) * sin(deltaLng / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusMeters * c;
}

double _radians(double degree) => degree * pi / 180;
