import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../data/indoor_ar_contract.dart';
import '../data/indoor_building_catalog.dart';
import '../theme/app_theme.dart';

/// Shows the VEC objects authored in Unity's exported floor 1 and 2 map.
/// Floors 3–5 appear on the directory photo, but aren't in the current Unity
/// scan, so they are deliberately shown as directory-only.
class IndoorBuildingMapScreen extends StatefulWidget {
  const IndoorBuildingMapScreen({super.key});

  @override
  State<IndoorBuildingMapScreen> createState() =>
      _IndoorBuildingMapScreenState();
}

class _IndoorBuildingMapScreenState extends State<IndoorBuildingMapScreen> {
  late final Future<_VecIndoorMap> _map = _loadMap();
  final TransformationController _mapTransform = TransformationController();
  bool _mapTransformInitialized = false;
  Size _mapViewportSize = Size.zero;
  int _floor = 1;
  String _selectedRoom = '119';

  @override
  void dispose() {
    _mapTransform.dispose();
    super.dispose();
  }

  Future<_VecIndoorMap> _loadMap() async {
    final raw = await rootBundle.loadString(
      'assets/indoor/vec_floors1and2.json',
    );
    final map = _VecIndoorMap.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    if (map.buildingId != IndoorBuildingCatalog.vecBuildingCode) {
      throw const FormatException('Indoor map building ID does not match VEC.');
    }
    return map;
  }

  void _zoomMap(double factor) {
    final current = _mapTransform.value;
    final currentScale = current.getMaxScaleOnAxis();
    if (currentScale <= 0 || _mapViewportSize.isEmpty) return;
    final nextScale = (currentScale * factor).clamp(.35, 4.0).toDouble();
    final ratio = nextScale / currentScale;
    final centerX = _mapViewportSize.width / 2;
    final centerY = _mapViewportSize.height / 2;
    final translateX = centerX + (current.entry(0, 3) - centerX) * ratio;
    final translateY = centerY + (current.entry(1, 3) - centerY) * ratio;
    _mapTransform.value = Matrix4.identity()
      ..translate(translateX, translateY)
      ..scale(nextScale);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF4F6FA),
    appBar: AppBar(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.navy,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            IndoorBuildingCatalog.vecDisplayName,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          Text(
            'VEC · Unity indoor map',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    ),
    body: SafeArea(
      child: FutureBuilder<_VecIndoorMap>(
        future: _map,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('The VEC indoor map could not load.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final map = snapshot.data!;
          final objects = map.objectsForFloor(_floor);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              _notice(
                'Tap a room marker or room number to select it. Pin positions come from the Unity scan; the scan does not include a walkable route or a complete building outline.',
                const Color(0xFFEAF4FA),
                const Color(0xFF28536A),
              ),
              const SizedBox(height: 12),
              _notice(
                'The directory photo also shows floors 3–5. Those floors are not part of the current Unity scan, so they are listed below without a map.',
                const Color(0xFFFFF4D6),
                const Color(0xFF684B12),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () {
                  final matches = objects
                      .where((item) => item.type == 'door' && item.id == 'VEC$_selectedRoom')
                      .toList(growable: false);
                  final door = matches.isEmpty ? null : matches.first;
                  if (door == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Choose a room on this floor to verify your location.')),
                    );
                    return;
                  }
                  context.push(
                    '/ar',
                    extra: IndoorArRequest(
                      room: _selectedRoom,
                      doorKey: door.id,
                      floor: '$_floor',
                      position: IndoorArVector3(door.x, door.y, door.z),
                      headingDeg: door.rotationY,
                      mapCode: IndoorBuildingCatalog.vecMapSetCode,
                      frame: IndoorBuildingCatalog.vecMapFrame,
                    ),
                  );
                },
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text('Verify location near room $_selectedRoom with AR'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final floor in const [1, 2]) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('Floor $floor'),
                        selected: _floor == floor,
                        selectedColor: AppColors.navy,
                        labelStyle: TextStyle(
                          color: _floor == floor
                              ? Colors.white
                              : AppColors.navy,
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (_) => setState(() {
                          _floor = floor;
                          final rooms = map.roomNumbersForFloor(floor);
                          if (!rooms.contains(_selectedRoom) &&
                              rooms.isNotEmpty) {
                            _selectedRoom = rooms.first;
                          }
                        }),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF26344F),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x220B1830),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'UNITY LEVEL $_floor',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _floor == 1
                              ? '${objects.length} Unity scan points'
                              : '${objects.length} scanned map points',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AspectRatio(
                      aspectRatio: 1.2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3E7ED),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final viewport = Size(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              );
                              _mapViewportSize = viewport;
                              final mapSize = Size(
                                viewport.width * 1.5,
                                viewport.height * 1.35,
                              );
                              if (!_mapTransformInitialized) {
                                _mapTransformInitialized = true;
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (!mounted) return;
                                  const initialScale = .75;
                                  _mapTransform.value = Matrix4.identity()
                                    ..translate(
                                      (viewport.width - mapSize.width * initialScale) / 2,
                                      (viewport.height - mapSize.height * initialScale) / 2,
                                    )
                                    ..scale(initialScale);
                                });
                              }
                              return InteractiveViewer(
                                constrained: false,
                                transformationController: _mapTransform,
                                minScale: .35,
                                maxScale: 4,
                                boundaryMargin: const EdgeInsets.all(500),
                                child: SizedBox(
                                  width: mapSize.width,
                                  height: mapSize.height,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTapDown: (details) {
                                      final room = _FloorMapPainter.hitTestRoom(
                                        objects,
                                        details.localPosition,
                                        mapSize,
                                      );
                                      if (room != null) {
                                        setState(() => _selectedRoom = room);
                                      }
                                    },
                                    child: CustomPaint(
                                      size: mapSize,
                                      painter: _FloorMapPainter(
                                        objects,
                                        selectedRoom: _selectedRoom,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Zoom',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                          IconButton(
                            tooltip: 'Zoom out',
                            onPressed: () => _zoomMap(.8),
                            color: Colors.white,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          IconButton(
                            tooltip: 'Zoom in',
                            onPressed: () => _zoomMap(1.25),
                            color: Colors.white,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _Legend(color: Color(0xFFF2E7B9), label: 'Room door'),
                        _Legend(color: Color(0xFF5B9CB0), label: 'Entrance'),
                        _Legend(color: Color(0xFFBD6C76), label: 'Stairs'),
                        _Legend(color: Color(0xFF55958C), label: 'Elevator'),
                        _Legend(color: Color(0xFF8D83AA), label: 'Restroom'),
                      ],
                    ),
                    if (_floor == 1) ...[
                      const SizedBox(height: 9),
                      const Text(
                        'Filled rooms have Unity scan points. Outlined rooms come from the directory reference.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    const Text(
                      'Pinch to zoom, drag to pan. Use + or - on either floor.',
                      style: TextStyle(color: Colors.white60, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Room doors in this scan',
                style: TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final room in map.roomNumbersForFloor(_floor))
                    ActionChip(
                      label: Text(room),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: _selectedRoom == room
                          ? const Color(0xFFFFF0C2)
                          : Colors.white,
                      onPressed: () => setState(() => _selectedRoom = room),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Directory-only floors',
                style: TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Wrap(
                spacing: 7,
                children: [
                  Chip(label: Text('3rd floor · not scanned')),
                  Chip(label: Text('4th floor · not scanned')),
                  Chip(label: Text('5th floor · not scanned')),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _notice(String text, Color background, Color foreground) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, color: foreground, size: 20),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: foreground, fontSize: 12, height: 1.4),
          ),
        ),
      ],
    ),
  );
}

class _VecIndoorMap {
  const _VecIndoorMap({required this.buildingId, required this.objects});

  factory _VecIndoorMap.fromJson(Map<String, dynamic> json) {
    final rawObjects = json['objects'] as List<dynamic>;
    return _VecIndoorMap(
      buildingId: json['buildingId'] as String,
      objects: rawObjects
          .map((entry) => _IndoorObject.fromJson(entry as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final String buildingId;
  final List<_IndoorObject> objects;

  List<_IndoorObject> objectsForFloor(int floor) =>
      objects.where((object) => object.floor == floor).toList(growable: false);

  List<String> roomNumbersForFloor(int floor) => objectsForFloor(floor)
      .where((object) => object.type == 'door')
      .map((object) => object.id.substring(3))
      .toList(growable: false);
}

class _IndoorObject {
  const _IndoorObject({
    required this.id,
    required this.type,
    required this.floor,
    required this.x,
    required this.z,
    required this.y,
    required this.rotationY,
  });

  factory _IndoorObject.fromJson(Map<String, dynamic> json) {
    final position = json['position'] as Map<String, dynamic>;
    return _IndoorObject(
      id: json['id'] as String,
      type: json['type'] as String,
      floor: (json['floorId'] as String).endsWith('1') ? 1 : 2,
      x: (position['x'] as num).toDouble(),
      z: (position['z'] as num).toDouble(),
      y: (position['y'] as num).toDouble(),
      rotationY: (json['rotationY'] as num?)?.toDouble() ?? 0,
    );
  }

  final String id;
  final String type;
  final int floor;
  final double x;
  final double z;
  final double y;
  final double rotationY;
}

class _FloorMapPainter extends CustomPainter {
  const _FloorMapPainter(this.objects, {required this.selectedRoom});

  final List<_IndoorObject> objects;
  final String selectedRoom;

  static const _minX = -34.0;
  static const _maxX = 34.0;
  static const _minZ = -5.0;
  static const _maxZ = 35.0;
  // First-floor diagram layout follows the user's sketch. These are display
  // coordinates only; AR continues to use the original Unity export values.
  static const Map<String, Rect> _floorOneRooms = {
    '124': Rect.fromLTWH(.10, .09, .19, .19),
    '127': Rect.fromLTWH(.60, .10, .13, .18),
    '128': Rect.fromLTWH(.74, .10, .14, .22),
    '129': Rect.fromLTWH(.90, .10, .055, .10),
    '130': Rect.fromLTWH(.90, .21, .055, .12),
    '121': Rect.fromLTWH(.15, .59, .14, .16),
    '120': Rect.fromLTWH(.29, .59, .08, .16),
    '119': Rect.fromLTWH(.375, .59, .065, .16),
    '118': Rect.fromLTWH(.445, .59, .055, .16),
    '104': Rect.fromLTWH(.39, .82, .09, .11),
    '136': Rect.fromLTWH(.695, .58, .07, .18),
    '134': Rect.fromLTWH(.765, .62, .06, .25),
    '132': Rect.fromLTWH(.825, .58, .07, .18),
    '135': Rect.fromLTWH(.695, .78, .07, .14),
    '133': Rect.fromLTWH(.825, .78, .07, .14),
  };
  static const List<Rect> _floorOneUnlabeledRooms = [
    Rect.fromLTWH(.29, .09, .30, .19),
    Rect.fromLTWH(.16, .76, .22, .17),
  ];
  static const Map<String, Rect> _floorTwoRooms = {
    '201': Rect.fromLTWH(.05, .08, .13, .25),
    '202': Rect.fromLTWH(.18, .08, .22, .25),
    '215': Rect.fromLTWH(.75, .08, .06, .25),
    '217': Rect.fromLTWH(.815, .08, .075, .25),
    '218': Rect.fromLTWH(.895, .08, .06, .25),
    '220': Rect.fromLTWH(.35, .57, .09, .37),
    '224': Rect.fromLTWH(.68, .57, .16, .37),
    '227': Rect.fromLTWH(.855, .57, .10, .37),
  };
  static const List<Rect> _floorTwoUnlabeledRooms = [
    Rect.fromLTWH(.40, .08, .35, .10),
    Rect.fromLTWH(.48, .20, .10, .14),
    Rect.fromLTWH(.58, .20, .10, .14),
    Rect.fromLTWH(.05, .57, .29, .37),
  ];
  static const Map<String, Offset> _floorOneFeatures = {
    'VECentr1B': Offset(.06, .45),
    'VECentr1A': Offset(.94, .45),
    'VECentr1C': Offset(.60, .945),
    'VECstairsF1B': Offset(.125, .66),
    'VECstairsF1A': Offset(.965, .66),
    'VECelev1A': Offset(.54, .64),
    'VECelev1B': Offset(.54, .76),
    'VECbathF1': Offset(.65, .64),
    'VECbathM1': Offset(.65, .76),
  };
  static const Map<String, Offset> _floorTwoFeatures = {
    'VECstairsF2B': Offset(.06, .45),
    'VECstairsF2A': Offset(.94, .45),
    'VECbathM2': Offset(.53, .27),
    'VECbathF2': Offset(.63, .27),
    'VECelev2A': Offset(.47, .65),
    'VECelev2B': Offset(.47, .85),
  };

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFFF7F7F4), BlendMode.src);
    if (objects.any((object) => object.floor == 1)) {
      _paintFloorOne(canvas, size);
      return;
    }
    if (objects.any((object) => object.floor == 2)) {
      _paintFloorTwo(canvas, size);
      return;
    }

    // Draw all pins before labels so a later scan point can't cover an earlier
    // room number. Coordinates remain the exact x/z values exported by Unity.
    for (final object in objects) {
      final point = _point(object.x, object.z, size);
      final color = switch (object.type) {
        'door' => const Color(0xFFF2E7B9),
        'entrance' => const Color(0xFF5B9CB0),
        'stairs' => const Color(0xFFBD6C76),
        'elevator' => const Color(0xFF55958C),
        'bathroom' => const Color(0xFF8D83AA),
        _ => const Color(0xFF8D98A8),
      };
      final roomNumber = object.type == 'door' ? object.id.substring(3) : null;
      final labelOffset = _labelOffset(roomNumber, object.type);
      final labelPoint = point + labelOffset;
      final markerRect = Rect.fromCenter(
        center: labelPoint,
        width: object.type == 'door' ? 38 : 30,
        height: 25,
      );
      if (labelOffset.distance > 0) {
        canvas.drawLine(
          point,
          labelPoint,
          Paint()
            ..color = const Color(0xFF8792A1)
            ..strokeWidth = 1.2,
        );
        canvas.drawCircle(point, 3, Paint()..color = const Color(0xFF26344F));
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(markerRect, const Radius.circular(5)),
        Paint()..color = color,
      );
      if (object.type == 'door' && object.id == 'VEC$selectedRoom') {
        canvas.drawCircle(
          labelPoint,
          22,
          Paint()
            ..color = const Color(0xFFF2B544)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }
    }

    // Labels are a separate pass so every number stays on top of nearby pins.
    for (final object in objects) {
      final point = _point(object.x, object.z, size);
      final labelPoint = point + _labelOffset(
        object.type == 'door' ? object.id.substring(3) : null,
        object.type,
      );
      final label = object.type == 'door'
          ? object.id.substring(3)
          : switch (object.type) {
              'entrance' => 'E',
              'stairs' => 'S',
              'elevator' => 'L',
              'bathroom' => 'R',
              _ => '?',
            };
      _drawText(canvas, label, labelPoint, 10, const Color(0xFF26344F), bold: true);
    }
  }

  void _paintFloorOne(Canvas canvas, Size size) {
    _paintFloorPlan(
      canvas,
      size,
      _floorOneRooms,
      _floorOneFeatures,
      _floorOneUnlabeledRooms,
      horizontalShift: .015,
      lowerEntranceCorridor: true,
    );
  }

  void _paintFloorTwo(Canvas canvas, Size size) {
    _paintFloorPlan(
      canvas,
      size,
      _floorTwoRooms,
      _floorTwoFeatures,
      _floorTwoUnlabeledRooms,
    );
  }

  void _paintFloorPlan(
    Canvas canvas,
    Size size,
    Map<String, Rect> roomLayout,
    Map<String, Offset> featureLayout,
    List<Rect> unlabeledRooms, {
    double horizontalShift = 0,
    bool lowerEntranceCorridor = false,
  }) {
    final scannedRooms = objects
        .where((object) => object.type == 'door')
        .map((object) => object.id.substring(3))
        .toSet();
    final outer = Rect.fromLTWH(
      size.width * .025,
      size.height * .025,
      size.width * .95,
      size.height * .95,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(outer, Radius.circular(size.width * .025)),
      Paint()..color = const Color(0xFFE2E6EC),
    );
    final building = outer.deflate(size.width * .018);
    canvas.drawRRect(
      RRect.fromRectAndRadius(building, Radius.circular(size.width * .022)),
      Paint()..color = const Color(0xFFF7F7F4),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(building, Radius.circular(size.width * .022)),
      Paint()
        ..color = const Color(0xFF33445E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * .004,
    );

    final corridor = Rect.fromLTWH(
      building.left + size.width * .012,
      size.height * .34,
      building.width - size.width * .024,
      size.height * .21,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(corridor, Radius.circular(size.width * .018)),
      Paint()..color = const Color(0xFFD5DAE3),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(corridor, Radius.circular(size.width * .018)),
      Paint()
        ..color = const Color(0xFFBCC5D0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * .002,
    );
    _drawText(
      canvas,
      'MAIN CORRIDOR',
      Offset(size.width * .50, size.height * .445),
      size.width * .022,
      const Color(0xFF566171),
      bold: true,
    );

    canvas.save();
    canvas.translate(-size.width * horizontalShift, 0);
    if (lowerEntranceCorridor) {
      final left = size.width * .575;
      final right = size.width * .625;
      final bottom = size.height * .925;
      canvas.drawRect(
        Rect.fromLTRB(left, corridor.bottom - 2, right, bottom),
        Paint()..color = const Color(0xFFD5DAE3),
      );
      final walls = Paint()
        ..color = const Color(0xFFBCC5D0)
        ..strokeWidth = size.width * .002;
      canvas.drawLine(Offset(left, corridor.bottom), Offset(left, bottom), walls);
      canvas.drawLine(Offset(right, corridor.bottom), Offset(right, bottom), walls);
      canvas.drawLine(Offset(left, bottom), Offset(right, bottom), walls);
    }

    for (final normalizedRect in unlabeledRooms) {
      final rect = Rect.fromLTWH(
        normalizedRect.left * size.width,
        normalizedRect.top * size.height,
        normalizedRect.width * size.width,
        normalizedRect.height * size.height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(size.width * .006)),
        Paint()..color = const Color(0xFFFAFAF7),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(size.width * .006)),
        Paint()
          ..color = const Color(0xFF8793A2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * .0025,
      );
    }

    for (final entry in roomLayout.entries) {
      final normalizedRect = entry.value;
      final rect = Rect.fromLTWH(
        normalizedRect.left * size.width,
        normalizedRect.top * size.height,
        normalizedRect.width * size.width,
        normalizedRect.height * size.height,
      );
      final isScanned = scannedRooms.contains(entry.key);
      final isSelected = entry.key == selectedRoom && isScanned;
      final radius = Radius.circular(size.width * .008);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()
          ..color = isSelected
              ? const Color(0xFFFFE8A8)
              : isScanned
              ? const Color(0xFFF2E7B9)
              : const Color(0xFFFAFAF7),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()
          ..color = isSelected
              ? const Color(0xFFB98212)
              : isScanned
              ? const Color(0xFF9A895C)
              : const Color(0xFF9AA4B1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected
              ? size.width * .005
              : size.width * .0025,
      );
      _drawText(
        canvas,
        entry.key,
        rect.center,
        math.min(rect.width, rect.height) * .23,
        const Color(0xFF26344F),
        bold: true,
      );
    }

    for (final object in objects.where((item) => item.type != 'door')) {
      final position = featureLayout[object.id];
      if (position == null) continue;
      final center = Offset(position.dx * size.width, position.dy * size.height);
      // The left floor-two access marker is an entrance in the user's plan,
      // although the exported Unity marker is typed as stairs.
      final displayType = object.floor == 2 && object.id == 'VECstairsF2B'
          ? 'entrance'
          : object.type;
      final color = switch (displayType) {
        'entrance' => const Color(0xFF5B9CB0),
        'stairs' => const Color(0xFFBD6C76),
        'elevator' => const Color(0xFF55958C),
        'bathroom' => const Color(0xFF8D83AA),
        _ => const Color(0xFF8D98A8),
      };
      final rect = Rect.fromCenter(
        center: center,
        width: size.width * .05,
        height: size.height * .065,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(size.width * .008)),
        Paint()..color = color,
      );
      final label = switch (displayType) {
        'entrance' => 'E',
        'stairs' => 'S',
        'elevator' => 'L',
        'bathroom' => 'R',
        _ => '?',
      };
      _drawText(
        canvas,
        label,
        center,
        size.width * .027,
        Colors.white,
        bold: true,
      );
    }

    canvas.restore();
  }

  static Offset _labelOffset(String? roomNumber, String type) {
    if (type == 'door') {
      return switch (roomNumber) {
        '120' => const Offset(0, -18),
        '119' => const Offset(0, 18),
        '201' || '202' => const Offset(0, 17),
        _ => Offset.zero,
      };
    }
    return Offset.zero;
  }

  static String? hitTestRoom(List<_IndoorObject> objects, Offset position, Size size) {
    if (objects.any((object) => object.floor == 1 || object.floor == 2)) {
      final roomLayout = objects.any((object) => object.floor == 1)
          ? _floorOneRooms
          : _floorTwoRooms;
      for (final object in objects.where((item) => item.type == 'door')) {
        final room = object.id.substring(3);
        final normalizedRect = roomLayout[room];
        if (normalizedRect == null) continue;
        final rect = Rect.fromLTWH(
          normalizedRect.left * size.width,
          normalizedRect.top * size.height,
          normalizedRect.width * size.width,
          normalizedRect.height * size.height,
        );
        if (rect.inflate(12).contains(position)) return room;
      }
      return null;
    }
    _IndoorObject? nearest;
    var nearestDistance = 30.0;
    for (final object in objects.where((item) => item.type == 'door')) {
      final point = Offset(
        size.width * (.09 + ((object.x - _minX) / (_maxX - _minX)) * .82),
        size.height * (.09 + ((_maxZ - object.z) / (_maxZ - _minZ)) * .80),
      );
      final labelPoint = point + _labelOffset(object.id.substring(3), object.type);
      final distance = (position - point).distance < (position - labelPoint).distance
          ? (position - point).distance
          : (position - labelPoint).distance;
      if (distance < nearestDistance) {
        nearest = object;
        nearestDistance = distance;
      }
    }
    return nearest?.id.substring(3);
  }

  Offset _point(double x, double z, Size size) => Offset(
    size.width * (.09 + ((x - _minX) / (_maxX - _minX)) * .82),
    size.height * (.09 + ((_maxZ - z) / (_maxZ - _minZ)) * .80),
  );

  void _drawText(
    Canvas canvas,
    String text,
    Offset center,
    double fontSize,
    Color color, {
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _FloorMapPainter oldDelegate) =>
      oldDelegate.objects != objects || oldDelegate.selectedRoom != selectedRoom;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: Color(0xFFE4E8F0),
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}
