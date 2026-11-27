/// VEC floors enabled for indoor AR.
///
/// shortcut: hardcoded coverage, update when indoor AR gains another floor.
const scannedIndoorFloors = {'1', '2', '3'};

bool indoorScanCovered(String? buildingCode, String? floor) {
  if (buildingCode?.trim().toUpperCase() != 'VEC') return false;
  final value = floor?.trim();
  return value != null && scannedIndoorFloors.contains(value);
}
