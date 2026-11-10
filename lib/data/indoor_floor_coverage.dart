/// Floors the shipped VEC scan actually contains.
///
/// shortcut: floors 1 and 2 only, replace when a scan of another floor ships.
const scannedIndoorFloors = {'1', '2'};

bool indoorFloorNotScanned(String? floor) {
  final value = floor?.trim();
  if (value == null || value.isEmpty) return false;
  return !scannedIndoorFloors.contains(value);
}
