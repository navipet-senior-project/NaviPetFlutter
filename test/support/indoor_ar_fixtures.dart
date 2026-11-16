import 'package:navipet/data/indoor_ar_contract.dart';

/// Not a real credential. The launch-screen tests pin their clock just before
/// it expires.
final testArToken = IndoorArToken(
  token: 'test-token',
  expiresOn: DateTime.utc(2026, 1, 1, 0, 30),
);

/// VEC 119 door as loaded into vec_destination_points (contract v2, MapSet
/// frame).
IndoorArRequest vec119Request({
  double headingDeg = 185.36,
  IndoorArToken? arToken,
}) => IndoorArRequest(
  room: '119',
  doorKey: 'VEC119',
  floor: '1',
  position: const IndoorArVector3(-5.7651, -1.8186, 22.6689),
  headingDeg: headingDeg,
  mapCode: 'MSET_XTBY7AM7ZK77',
  frame: 'multiset-mapset',
  arToken: arToken ?? testArToken,
);
