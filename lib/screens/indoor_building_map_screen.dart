import 'dart:convert';

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
  int _floor = 1;
  String _selectedRoom = '119';

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
                'Map points match the VEC floor 1 + 2 Unity export. The export contains room doors, entrances, stairs, elevators, and restrooms; it does not contain a traced walkable-route graph yet.',
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
                          'FLOOR $_floor',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${objects.length} scanned map points',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AspectRatio(
                      aspectRatio: .78,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3E7ED),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: InteractiveViewer(
                            minScale: 1,
                            maxScale: 4,
                            boundaryMargin: const EdgeInsets.all(80),
                            child: SizedBox.expand(
                              child: CustomPaint(
                                painter: _FloorMapPainter(
                                  objects,
                                  selectedRoom: _selectedRoom,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                        ),
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
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Directory rooms on this floor',
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

  @override
  void paint(Canvas canvas, Size size) {
    final building = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * .06,
        size.height * .07,
        size.width * .88,
        size.height * .86,
      ),
      const Radius.circular(18),
    );
    canvas.drawRRect(building, Paint()..color = const Color(0xFFF7F7F4));
    canvas.drawRRect(
      building,
      Paint()
        ..color = const Color(0xFF48566B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Unity's MapSet coordinates are used directly for room and facility
    // marker placement. This corridor band is a visual guide, not route data.
    final corridorY = _point(0, 22.0, size).dy;
    canvas.drawLine(
      Offset(size.width * .12, corridorY),
      Offset(size.width * .88, corridorY),
      Paint()
        ..color = const Color(0xFFBEC8D8)
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.round,
    );
    _drawText(
      canvas,
      'MAIN CORRIDOR',
      Offset(size.width * .5, corridorY - 16),
      9,
      const Color(0xFF47556B),
      bold: true,
    );

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
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: point, width: 27, height: 21),
          const Radius.circular(5),
        ),
        Paint()..color = color,
      );
      if (object.type == 'door' && object.id == 'VEC$selectedRoom') {
        canvas.drawCircle(
          point,
          20,
          Paint()
            ..color = const Color(0xFFF2B544)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }
      final label = object.type == 'door'
          ? object.id.substring(3)
          : switch (object.type) {
              'entrance' => 'E',
              'stairs' => 'S',
              'elevator' => 'L',
              'bathroom' => 'R',
              _ => '?',
            };
      _drawText(canvas, label, point, 9, const Color(0xFF26344F), bold: true);
    }
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
