import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show MatrixUtils;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/campus_place.dart';
import '../data/indoor_building_catalog.dart';
import '../data/indoor_floor_coverage.dart';
import '../data/navigation_flow_controller.dart';
import '../theme/app_theme.dart';

const _ink = Color(0xFF00244E);
const _slate = Color(0xFF5D6B82);
const _doorFill = Color(0xFFF2E7B9);
const _doorStroke = Color(0xFF6B4B00);
const _entranceColor = Color(0xFF5B9CB0);
const _stairsColor = Color(0xFFBD6C76);
const _elevatorColor = Color(0xFF55958C);
const _restroomColor = Color(0xFF8D83AA);
const _verifiedGreen = Color(0xFF0B6B3A);

/// VEC room picker: corridor plans traced from the MultiSet scans as the Unity
/// building scene places them, with door pins from the Unity export.
class IndoorBuildingMapScreen extends StatefulWidget {
  const IndoorBuildingMapScreen({super.key});

  @override
  State<IndoorBuildingMapScreen> createState() =>
      _IndoorBuildingMapScreenState();
}

class _IndoorBuildingMapScreenState extends State<IndoorBuildingMapScreen> {
  late final Future<_VecIndoorMap> _map = _loadMap();
  final TransformationController _mapTransform = TransformationController();
  Size _mapViewportSize = Size.zero;
  Size _lastViewportSize = Size.zero;
  int _floor = 1;
  String? _selectedRoom = '119';
  bool _resolvingRoom = false;
  bool _expanded = false;
  int _selectionVersion = 0;

  void _selectRoom(String room) {
    if (_selectedRoom == room) return;
    setState(() {
      _selectedRoom = room;
      _selectionVersion++;
      // A stale lookup is discarded by its version, so it must not disable this room.
      _resolvingRoom = false;
    });
  }

  void _selectFloor(int floor) {
    if (_floor == floor) return;
    setState(() {
      _floor = floor;
      _selectedRoom = null;
      _selectionVersion++;
      _resolvingRoom = false;
      _lastViewportSize = Size.zero;
    });
  }

  void _setExpanded(bool expanded) => setState(() {
    _expanded = expanded;
    _lastViewportSize = Size.zero;
  });

  @override
  void dispose() {
    _mapTransform.dispose();
    super.dispose();
  }

  Future<_VecIndoorMap> _loadMap() async {
    final raw = await rootBundle.loadString('assets/indoor/vec_floors123.json');
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
    final nextScale = (currentScale * factor).clamp(.2, 4.0).toDouble();
    final ratio = nextScale / currentScale;
    final centerX = _mapViewportSize.width / 2;
    final centerY = _mapViewportSize.height / 2;
    final translateX = centerX + (current.entry(0, 3) - centerX) * ratio;
    final translateY = centerY + (current.entry(1, 3) - centerY) * ratio;
    _mapTransform.value = Matrix4.identity()
      ..translateByDouble(translateX, translateY, 0, 1)
      ..scaleByDouble(nextScale, nextScale, nextScale, 1);
  }

  void _fitMap(Size viewport) {
    if (viewport.isEmpty) return;
    final mapSize = _FloorPlanPainter.canvasSize;
    final scale = math
        .min(viewport.width / mapSize.width, viewport.height / mapSize.height)
        .clamp(.2, 4.0)
        .toDouble();
    _mapTransform.value = Matrix4.identity()
      ..translateByDouble(
        (viewport.width - mapSize.width * scale) / 2,
        (viewport.height - mapSize.height * scale) / 2,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, scale, 1);
  }

  /// The map only picks a room number. The destination is the same backend
  /// record autocomplete selects, so the AR launch screen loads its door pose
  /// from `place(id)` exactly as it does for a search result; the bundled scan
  /// asset is for drawing only and never supplies AR coordinates.
  Future<void> _verifyWithAr() async {
    final room = _selectedRoom;
    if (room == null) return;
    final floor = '$_floor';
    final selectionVersion = _selectionVersion;
    final gateway = context.read<NavigationFlowController>().searchGateway;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _resolvingRoom = true);
    String? message;
    String? placeId;
    try {
      final found = await gateway.autocomplete(
        '${IndoorBuildingCatalog.vecBuildingCode} $room',
      );
      final matches = found
          .where(
            (place) =>
                place.isLocal &&
                place.type == CampusDestinationType.room &&
                place.buildingCode == IndoorBuildingCatalog.vecBuildingCode &&
                place.roomNumber == room &&
                place.floorNumber == floor,
          )
          .map((place) => place.id)
          .toSet();
      if (matches.length == 1) {
        placeId = matches.single;
      } else {
        message =
            "Couldn't match room $room on floor $floor to a campus record. Search for it instead.";
      }
    } on CampusSearchException {
      message =
          "Couldn't look up room $room. Check your connection and try again.";
    } catch (_) {
      message = "Couldn't look up room $room. Try again.";
    }
    if (!mounted || selectionVersion != _selectionVersion) return;
    setState(() => _resolvingRoom = false);
    if (placeId == null) {
      messenger.showSnackBar(SnackBar(content: Text(message!)));
      return;
    }
    router.push(
      Uri(path: '/ar', queryParameters: {'destination': placeId}).toString(),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_expanded,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && _expanded) _setExpanded(false);
    },
    child: Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: _expanded ? null : _header(),
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
            if (_expanded) return _mapSection(map);
            return Column(
              children: [
                Expanded(child: _roomList(map)),
                _selectionSheet(map),
              ],
            );
          },
        ),
      ),
    ),
  );

  PreferredSizeWidget _header() {
    const titleLines = [
      ('Choose a room', TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
      (
        '${IndoorBuildingCatalog.vecDisplayName} · VEC',
        TextStyle(fontSize: 13, color: Color(0xFFC9D6E8)),
      ),
    ];
    const leadingWidth = 56.0;
    const actionWidth = 48.0;
    final padding = MediaQuery.paddingOf(context);
    final titleWidth = math.max(
      1.0,
      MediaQuery.sizeOf(context).width -
          padding.horizontal -
          leadingWidth -
          (kDebugMode ? actionWidth : 0),
    );
    final titleStyle =
        AppBarTheme.of(context).titleTextStyle ??
        Theme.of(context).textTheme.titleLarge;
    var titleHeight = 0.0;
    for (final (label, style) in titleLines) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: titleStyle?.merge(style) ?? style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: titleWidth);
      titleHeight += painter.height.ceilToDouble();
      painter.dispose();
    }
    return AppBar(
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      leadingWidth: leadingWidth,
      toolbarHeight: math.max(kToolbarHeight, titleHeight + 8),
      titleSpacing: 0,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, style) in titleLines) Text(label, style: style),
        ],
      ),
      actions: [
        if (kDebugMode)
          SizedBox(
            width: actionWidth,
            child: IconButton(
              tooltip: 'VEC positioning survey',
              onPressed: () => context.push('/dev/vec-positioning'),
              icon: const Icon(Icons.wifi_tethering),
            ),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(74),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          // Tabs are a fixed 56 px; past 1.3x the caption would overflow.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: Row(
              children: [
                for (final floor in _floors)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: floor == 1 ? 0 : 6),
                      child: _FloorTab(
                        floor: floor,
                        selected: floor == _floor,
                        onTap: () => _selectFloor(floor),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roomList(_VecIndoorMap map) {
    final pinned = map.pinnedRooms(_floor);
    final directory = _directoryOnlyRooms[_floor] ?? const <String>[];
    final ar = indoorScanCovered('VEC', '$_floor');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: _Pill(
            label: ar ? 'AR ready' : 'AR not covered',
            background: ar ? const Color(0xFFE3F4EC) : const Color(0xFFEEF1F5),
            foreground: ar ? _verifiedGreen : AppColors.labelInk,
          ),
        ),
        const SizedBox(height: 14),
        _mapSection(map),
        const SizedBox(height: 14),
        const Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            _Legend(color: _doorFill, label: 'Room door', door: true),
            _Legend(color: _entranceColor, label: 'Entrance'),
            _Legend(color: _stairsColor, label: 'Stairs'),
            _Legend(color: _elevatorColor, label: 'Elevator'),
            _Legend(color: _restroomColor, label: 'Restroom'),
          ],
        ),
        const SizedBox(height: 14),
        const _SectionTitle('Pinned on the scan', 'Door position verified'),
        const SizedBox(height: 10),
        if (pinned.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E2E2)),
            ),
            child: Text(
              'None yet on Floor $_floor. Pin points for this floor are on the way; rooms move here once they land.',
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.labelInk,
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final room in pinned)
                _RoomChip(
                  room: room,
                  pinned: true,
                  selected: room == _selectedRoom,
                  onTap: () => _selectRoom(room),
                ),
            ],
          ),
        if (directory.isNotEmpty) ...[
          const SizedBox(height: 14),
          const _SectionTitle('Directory only', 'Not placed on the map'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final room in directory)
                _RoomChip(
                  room: room,
                  pinned: false,
                  selected: room == _selectedRoom,
                  onTap: () => _selectRoom(room),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _mapSection(_VecIndoorMap map) {
    final pinned = map.pinnedRooms(_floor);
    final directory = _directoryOnlyRooms[_floor] ?? const <String>[];
    final viewport = ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: ColoredBox(
        color: const Color(0xFFF4F7FB),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            _mapViewportSize = size;
            if (_lastViewportSize != size) {
              _lastViewportSize = size;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _lastViewportSize == size) _fitMap(size);
              });
            }
            return _FloorPlan(
              transformationController: _mapTransform,
              floor: _floor,
              objects: map.objectsForFloor(_floor),
              selectedRoom: _selectedRoom,
              onSelectRoom: _selectRoom,
            );
          },
        ),
      ),
    );
    return Container(
      padding: _expanded
          ? const EdgeInsets.fromLTRB(8, 12, 8, 8)
          : const EdgeInsets.all(8),
      decoration: _expanded
          ? const BoxDecoration(color: Colors.white)
          : BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14101828),
                  blurRadius: 30,
                  offset: Offset(0, 10),
                ),
              ],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: _SectionTitle(
              'Floor $_floor',
              '${pinned.length} pinned · ${directory.length} directory-only',
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _MapButton(
                tooltip: 'Zoom in',
                icon: Icons.add,
                onPressed: () => _zoomMap(1.25),
              ),
              const SizedBox(width: 6),
              _MapButton(
                tooltip: 'Zoom out',
                icon: Icons.remove,
                onPressed: () => _zoomMap(.8),
              ),
              const SizedBox(width: 6),
              _MapButton(
                tooltip: _expanded ? 'Exit full-screen map' : 'Full-screen map',
                icon: _expanded ? Icons.fullscreen_exit : Icons.fullscreen,
                onPressed: () => _setExpanded(!_expanded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_expanded)
            Expanded(child: viewport)
          else
            SizedBox(height: 300, child: viewport),
          if (pinned.isEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(8, 8, 8, 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceWarm,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFC9A23A)),
              ),
              child: const Text(
                'Corridors are traced from the building scan. Door pin points for this floor are still coming.',
                style: TextStyle(
                  color: _doorStroke,
                  fontSize: 12,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _selectionSheet(_VecIndoorMap map) {
    final room = _selectedRoom;
    final ar = indoorScanCovered('VEC', '$_floor');
    final pinned = room != null && map.pinnedRooms(_floor).contains(room);
    final canVerify = pinned && ar;
    final (String badge, String note) = canVerify
        ? (
            'Door on scan',
            'This door position is verified in the building scan.',
          )
        : ar
        ? (
            'Directory only',
            "Floor $_floor has AR, but this room has no door in the scan yet, so AR can't confirm it.",
          )
        : (
            'Directory only',
            "The building scan covers this floor's corridors. Floor $_floor pin points are still coming, so this room isn't placed and AR isn't available yet.",
          );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x24101828),
            blurRadius: 32,
            offset: Offset(0, -12),
          ),
        ],
      ),
      // Large text on a short phone must scroll, not overflow.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .5,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D5DD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (room == null) ...[
              const Text(
                'Pick a room',
                style: TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap a door on the map or a room below.',
                style: TextStyle(
                  color: AppColors.labelInk,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Room $room',
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'VEC $room · Floor $_floor',
                          style: const TextStyle(
                            color: _slate,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: _Pill(
                      label: badge,
                      background: canVerify
                          ? const Color(0xFFE3F4EC)
                          : AppColors.accentSoft,
                      foreground: canVerify ? _verifiedGreen : _doorStroke,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                note,
                style: const TextStyle(
                  color: AppColors.labelInk,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  disabledBackgroundColor: const Color(0xFFEEF1F5),
                  disabledForegroundColor: AppColors.muted,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onPressed: canVerify && !_resolvingRoom ? _verifyWithAr : null,
                icon: const Icon(Icons.view_in_ar),
                label: Text(
                  !canVerify
                      ? 'AR unavailable here'
                      : _resolvingRoom
                      ? 'Opening AR for VEC $room…'
                      : 'Verify with AR',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

const _floors = [1, 2, 3, 4, 5];

/// Rooms the app's directory lists without a tagged door in the Unity export.
/// They are listed, never placed: floors 4–5 pin points have not landed yet.
const _directoryOnlyRooms = <int, List<String>>{
  1: ['104', '118', '129', '130', '133', '135'],
  4: ['402', '417', '418', '419', '420', '424', '425'],
  5: ['510', '514', '515', '516', '518', '519', '523'],
};

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

  List<String> pinnedRooms(int floor) =>
      objectsForFloor(floor)
          .where((object) => object.type == 'door')
          .map((object) => object.room)
          .toList()
        ..sort();
}

class _IndoorObject {
  const _IndoorObject({
    required this.id,
    required this.type,
    required this.floor,
    required this.x,
    required this.z,
    required this.rotationY,
  });

  factory _IndoorObject.fromJson(Map<String, dynamic> json) {
    final position = json['position'] as Map<String, dynamic>;
    final floorId = json['floorId'] as String;
    return _IndoorObject(
      id: json['id'] as String,
      type: json['type'] as String,
      floor: int.parse(floorId.substring(floorId.lastIndexOf('_') + 1)),
      x: (position['x'] as num).toDouble(),
      z: (position['z'] as num).toDouble(),
      rotationY: (json['rotationY'] as num?)?.toDouble() ?? 0,
    );
  }

  final String id;
  final String type;
  final int floor;
  final double x;
  final double z;
  final double rotationY;

  String get room => id.substring(3);
}

/// Corridor outlines traced from 1.2 m-thick slices of the MultiSet scan
/// meshes as placed in the Unity `VEC_Building` scene. Rects are Unity metres
/// with y = -z, so north is up.
class _FloorGeometry {
  const _FloorGeometry({
    required this.halls,
    this.core,
    required this.labels,
    this.pending = false,
  });

  final List<Rect> halls;
  final Rect? core;
  final List<(String, Offset, double)> labels;
  final bool pending;
}

const _geometry = <int, _FloorGeometry>{
  1: _FloorGeometry(
    halls: [
      Rect.fromLTWH(-34.8, -24.2, 64.8, 3),
      Rect.fromLTWH(-5, -33.6, 2.4, 9.4),
      Rect.fromLTWH(-2.6, -21.2, 4.8, 21.2),
      Rect.fromLTWH(-30.4, -24.4, 1.4, 9.6),
      Rect.fromLTWH(24, -24.2, 5, 6.6),
    ],
    labels: [
      ('Main corridor', Offset(-16, -22.7), 0),
      ('Entrance lobby', Offset(-0.2, -8), -math.pi / 2),
    ],
  ),
  2: _FloorGeometry(
    halls: [
      Rect.fromLTWH(-30.8, -24.4, 54.6, 3),
      Rect.fromLTWH(-12.8, -29.6, 17.8, 5.2),
      Rect.fromLTWH(-2, -21.4, 3.2, 5.8),
      Rect.fromLTWH(-30.4, -21.4, 3.2, 9.6),
    ],
    core: Rect.fromLTWH(-11, -27.8, 14.2, 3.4),
    labels: [
      ('Core', Offset(-3.9, -26.1), 0),
      ('Main corridor', Offset(-16, -22.9), 0),
    ],
  ),
  3: _FloorGeometry(
    halls: [
      Rect.fromLTWH(-31.2, -24.4, 54.9, 3),
      Rect.fromLTWH(23.4, -24.4, 3, 4.2),
      Rect.fromLTWH(-13, -29.4, 17.8, 5),
      Rect.fromLTWH(-2, -21.4, 3.2, 5.8),
      Rect.fromLTWH(-30.8, -21.4, 3.4, 8),
    ],
    core: Rect.fromLTWH(-11.2, -27.6, 14.2, 3.2),
    labels: [
      ('Core', Offset(-4.1, -26), 0),
      ('Main corridor', Offset(-12, -22.9), 0),
    ],
  ),
  4: _FloorGeometry(
    halls: [
      Rect.fromLTWH(-31, -23.8, 58.6, 2.8),
      Rect.fromLTWH(-12.8, -29, 18, 5.2),
      Rect.fromLTWH(-2, -21, 3.2, 6),
      Rect.fromLTWH(-30.8, -21, 2.4, 4.8),
    ],
    core: Rect.fromLTWH(-11, -27.2, 14.4, 3.4),
    labels: [
      ('Core', Offset(-3.8, -25.5), 0),
      ('Main corridor', Offset(-16, -22.4), 0),
      ('Pin points pending', Offset(12, -22.4), 0),
    ],
    pending: true,
  ),
  5: _FloorGeometry(
    halls: [
      Rect.fromLTWH(-31, -24, 57.2, 3),
      Rect.fromLTWH(-13.2, -29.4, 18.4, 5.4),
      Rect.fromLTWH(-2, -21, 3.2, 5.4),
      Rect.fromLTWH(-30.8, -21, 3.4, 8.6),
    ],
    core: Rect.fromLTWH(-11.2, -27.6, 14.2, 3.6),
    labels: [
      ('Core', Offset(-4.1, -25.8), 0),
      ('Main corridor', Offset(-16, -22.5), 0),
      ('Pin points pending', Offset(12, -22.5), 0),
    ],
    pending: true,
  ),
};

class _FloorPlan extends StatelessWidget {
  const _FloorPlan({
    required this.transformationController,
    required this.floor,
    required this.objects,
    required this.selectedRoom,
    required this.onSelectRoom,
  });

  final TransformationController transformationController;
  final int floor;
  final List<_IndoorObject> objects;
  final String? selectedRoom;
  final ValueChanged<String> onSelectRoom;

  @override
  Widget build(BuildContext context) {
    const hitRadius = 20.0;
    final doors = [
      for (final object in objects)
        if (object.type == 'door')
          (object.room, _FloorPlanPainter._objectCenter(object)),
    ];
    return ValueListenableBuilder<Matrix4>(
      valueListenable: transformationController,
      child: InteractiveViewer(
        constrained: false,
        transformationController: transformationController,
        minScale: .2,
        maxScale: 4,
        boundaryMargin: const EdgeInsets.all(400),
        child: SizedBox.fromSize(
          size: _FloorPlanPainter.canvasSize,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _FloorPlanPainter(
                floor: floor,
                objects: objects,
                selectedRoom: selectedRoom,
              ),
            ),
          ),
        ),
      ),
      builder: (context, transform, viewer) {
        final targets = [
          for (final (room, center) in doors)
            (room, MatrixUtils.transformPoint(transform, center)),
        ];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapUp: (details) {
            String? nearestRoom;
            var nearestDistance = hitRadius * hitRadius;
            for (final (room, center) in targets) {
              final distance = (details.localPosition - center).distanceSquared;
              if (distance <= nearestDistance) {
                nearestDistance = distance;
                nearestRoom = room;
              }
            }
            if (nearestRoom != null) onSelectRoom(nearestRoom);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              viewer!,
              for (final (room, center) in targets)
                Positioned.fromRect(
                  rect: Rect.fromCircle(center: center, radius: hitRadius),
                  child: Semantics(
                    key: ValueKey('door-$room'),
                    button: true,
                    selected: room == selectedRoom,
                    label: 'Select room $room',
                    onTap: () => onSelectRoom(room),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FloorPlanPainter extends CustomPainter {
  const _FloorPlanPainter({
    required this.floor,
    required this.objects,
    required this.selectedRoom,
  });

  final int floor;
  final List<_IndoorObject> objects;
  final String? selectedRoom;

  static const _world = Rect.fromLTWH(-36, -35, 67, 36);
  static const _pxPerMetre = 10.0;
  static final canvasSize = Size(
    _world.width * _pxPerMetre,
    _world.height * _pxPerMetre,
  );

  static Offset toCanvas(double x, double y) =>
      Offset((x - _world.left) * _pxPerMetre, (y - _world.top) * _pxPerMetre);

  static Offset _objectCenter(_IndoorObject object) =>
      toCanvas(object.x, -object.z);

  static Rect _rect(Rect r) =>
      Rect.fromPoints(toCanvas(r.left, r.top), toCanvas(r.right, r.bottom));

  @override
  void paint(Canvas canvas, Size size) {
    const m = _pxPerMetre;
    final grid = Paint()
      ..color = const Color(0xFFDCE3EC)
      ..strokeWidth = .6;
    for (var x = 0.0; x <= size.width; x += 5 * m) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y <= size.height; y += 5 * m) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final geometry = _geometry[floor]!;
    final outline = Paint()
      ..color = const Color(0xFF8FA2BC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7 * m;
    for (final hall in geometry.halls) {
      final path = Path()..addRect(_rect(hall));
      canvas.drawPath(
        geometry.pending ? _dashed(path, 1 * m, .5 * m) : path,
        outline,
      );
    }
    final fill = Paint()..color = Colors.white;
    for (final hall in geometry.halls) {
      canvas.drawRect(_rect(hall), fill);
    }
    if (geometry.core case final core?) {
      canvas.drawRect(_rect(core), Paint()..color = const Color(0xFFE3E9F1));
      canvas.drawRect(
        _rect(core),
        Paint()
          ..color = const Color(0xFF9FB0C6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .22 * m,
      );
    }
    for (final (text, at, angle) in geometry.labels) {
      _text(
        canvas,
        text,
        toCanvas(at.dx, at.dy),
        .9 * m,
        _slate,
        FontWeight.w600,
        angle: angle,
      );
    }

    final selected = objects.where(
      (o) => o.type == 'door' && o.room == selectedRoom,
    );
    for (final door in selected) {
      final c = _objectCenter(door);
      canvas.drawCircle(c, 1.7 * m, Paint()..color = const Color(0x61FDCC00));
      canvas.drawCircle(
        c,
        1.7 * m,
        Paint()
          ..color = const Color(0xFFE0A800)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .3 * m,
      );
    }

    for (final feature in objects.where((o) => o.type != 'door')) {
      final (color, label) = switch (feature.type) {
        'entrance' => (_entranceColor, 'IN'),
        'stairs' => (_stairsColor, 'ST'),
        'elevator' => (_elevatorColor, 'EL'),
        'bathroom' => (_restroomColor, 'WC'),
        _ => (const Color(0xFF8D98A8), '?'),
      };
      final c = _objectCenter(feature);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: 1.5 * m, height: 1.5 * m),
          const Radius.circular(.35 * m),
        ),
        Paint()..color = color,
      );
      _text(canvas, label, c, .6 * m, Colors.white, FontWeight.w800);
    }

    for (final door in objects.where((o) => o.type == 'door')) {
      final c = _objectCenter(door);
      canvas.drawCircle(c, .62 * m, Paint()..color = _doorFill);
      canvas.drawCircle(
        c,
        .62 * m,
        Paint()
          ..color = _doorStroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = .16 * m,
      );
      // Unity door headings: 0 faces north, 180 south, 90 sideways.
      final heading = door.rotationY.round() % 360;
      if (heading == 90 || heading == 270) {
        _text(
          canvas,
          door.room,
          c + const Offset(1 * m, 0),
          1.15 * m,
          _ink,
          FontWeight.w800,
          alignStart: true,
        );
      } else {
        _text(
          canvas,
          door.room,
          c + Offset(0, (heading == 0 ? -1.6 : 1.6) * m),
          1.15 * m,
          _ink,
          FontWeight.w800,
        );
      }
    }

    final bar = Paint()
      ..color = _slate
      ..strokeWidth = .18 * m
      ..style = PaintingStyle.stroke;
    final start = toCanvas(-34, -1.2);
    final end = toCanvas(-24, -1.2);
    canvas.drawLine(start, end, bar);
    canvas.drawLine(
      start.translate(0, -.4 * m),
      start.translate(0, .4 * m),
      bar,
    );
    canvas.drawLine(end.translate(0, -.4 * m), end.translate(0, .4 * m), bar);
    _text(canvas, '10 m', toCanvas(-29, -2.2), .9 * m, _slate, FontWeight.w600);
  }

  static Path _dashed(Path source, double dash, double gap) {
    final out = Path();
    for (final metric in source.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        out.addPath(metric.extractPath(d, d + dash), Offset.zero);
      }
    }
    return out;
  }

  static void _text(
    Canvas canvas,
    String text,
    Offset at,
    double fontSize,
    Color color,
    FontWeight weight, {
    double angle = 0,
    bool alignStart = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(at.dx, at.dy);
    if (angle != 0) canvas.rotate(angle);
    painter.paint(
      canvas,
      Offset(alignStart ? 0 : -painter.width / 2, -painter.height / 2),
    );
    canvas.restore();
    painter.dispose();
  }

  @override
  bool shouldRepaint(covariant _FloorPlanPainter oldDelegate) =>
      // objects is derived from floor, so it needs no separate compare.
      oldDelegate.floor != floor || oldDelegate.selectedRoom != selectedRoom;
}

class _FloorTab extends StatelessWidget {
  const _FloorTab({
    required this.floor,
    required this.selected,
    required this.onTap,
  });

  final int floor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? const Color(0xFFFDCC00) : const Color(0x14FFFFFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? const Color(0xFFFDCC00) : const Color(0x38FFFFFF),
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ExcludeSemantics(
                child: Text(
                  '$floor',
                  style: TextStyle(
                    color: selected ? _ink : Colors.white,
                    fontSize: 20,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Floor $floor',
                maxLines: 1,
                style: TextStyle(
                  color: selected ? _ink : const Color(0xFFC9D6E8),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RoomChip extends StatelessWidget {
  const _RoomChip({
    required this.room,
    required this.pinned,
    required this.selected,
    required this.onTap,
  });

  final String room;
  final bool pinned;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground, Color border) = pinned
        ? selected
              ? (AppColors.navy, Colors.white, AppColors.navy)
              : (Colors.white, _ink, const Color(0xFFD5DCE6))
        : selected
        ? (AppColors.accentSoft, _doorStroke, _doorStroke)
        : (const Color(0xFFF9F9F9), AppColors.labelInk, AppColors.faint);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: pinned ? _doorFill : null,
                      border: Border.all(color: _doorStroke, width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    room,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon, size: 20),
    style: IconButton.styleFrom(
      fixedSize: const Size(44, 44),
      backgroundColor: Colors.white,
      foregroundColor: _ink,
      elevation: 2,
      shadowColor: const Color(0x1A101828),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: foreground,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.caption);

  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 8,
    runSpacing: 4,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: _ink,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      Text(
        caption,
        style: const TextStyle(
          color: _slate,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.door = false});

  final Color color;
  final String label;
  final bool door;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(door ? 6 : 4),
          border: door ? Border.all(color: _doorStroke, width: 1.5) : null,
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.labelInk,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}
