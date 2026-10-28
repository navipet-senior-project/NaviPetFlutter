import 'package:navipet/data/indoor_ar_contract.dart';

/// VEC 119 door as loaded into vec_destination_points (contract v2, MapSet
/// frame).
IndoorArRequest vec119Request({double headingDeg = 185.36}) => IndoorArRequest(
  room: '119',
  doorKey: 'VEC119',
  floor: '1',
  position: const IndoorArVector3(-5.7651, -1.8186, 22.6689),
  headingDeg: headingDeg,
  mapCode: 'MSET_XTBY7AM7ZK77',
  frame: 'multiset-mapset',
);
