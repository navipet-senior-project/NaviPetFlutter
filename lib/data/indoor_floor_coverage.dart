/// Floors the shipped VEC scan actually contains.
///
/// shortcut: floors 1-3 only, replace when a scan of another floor ships.
const scannedIndoorFloors = {'1', '2', '3'};

bool indoorScanCovered(String? buildingCode, String? floor) {
  if (buildingCode?.trim().toUpperCase() != 'VEC') return false;
  final value = floor?.trim();
  return value != null && scannedIndoorFloors.contains(value);
}
