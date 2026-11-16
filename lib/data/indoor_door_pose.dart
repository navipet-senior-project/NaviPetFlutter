import 'indoor_ar_contract.dart';

/// A backend door pose in the Unity MapSet frame, with no axis conversion.
class IndoorDoorPose {
  const IndoorDoorPose({
    required this.mapCode,
    required this.frame,
    required this.doorKey,
    required this.floor,
    required this.position,
    required this.headingDeg,
  });

  final String mapCode;
  final String frame;
  final String doorKey;
  final String floor;
  final IndoorArVector3 position;
  final double headingDeg;

  /// Invalid or incomplete indoor data must never launch AR at a default door.
  static IndoorDoorPose? tryParse(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final mapCode = value['mapCode'];
    final frame = value['frame'];
    final doorKey = value['doorKey'];
    final floor = value['floor'];
    final position = value['position'];
    final heading = value['headingDeg'];
    if (mapCode is! String ||
        mapCode.trim().isEmpty ||
        frame != 'multiset-mapset' ||
        doorKey is! String ||
        doorKey.trim().isEmpty ||
        floor is! String ||
        floor.trim().isEmpty ||
        position is! Map<String, dynamic> ||
        heading is! num ||
        !(heading >= 0 && heading < 360)) {
      return null;
    }
    final x = position['x'];
    final y = position['y'];
    final z = position['z'];
    if (x is! num ||
        !x.isFinite ||
        y is! num ||
        !y.isFinite ||
        z is! num ||
        !z.isFinite) {
      return null;
    }
    return IndoorDoorPose(
      mapCode: mapCode,
      frame: frame as String,
      doorKey: doorKey,
      floor: floor,
      position: IndoorArVector3(x.toDouble(), y.toDouble(), z.toDouble()),
      headingDeg: heading.toDouble(),
    );
  }
}
