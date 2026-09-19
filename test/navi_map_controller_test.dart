import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/navi_map_controller.dart';
import 'package:navipet/data/navigation_models.dart';
import 'package:navipet/data/travel_mode.dart';

/// Records calls so flow tests can assert what the map was asked to do.
class RecordingMapController implements NaviMapController {
  final List<String> calls = [];

  @override
  Future<void> showPlace(
    NavigationCoordinate coordinate, {
    required String label,
    required double bottomInset,
  }) async => calls.add('showPlace:$label:$bottomInset');

  @override
  Future<void> showRoute(
    RoutePlan plan, {
    required NavigationCoordinate origin,
    required NaviDestination destination,
    required double bottomInset,
  }) async => calls.add('showRoute:${destination.name}:${plan.selectedIndex}');

  @override
  Future<void> followUser(
    NavigationCoordinate coordinate, {
    double? bearing,
  }) async => calls.add('followUser');

  @override
  Future<void> clear() async => calls.add('clear');
}

void main() {
  test('the recording controller satisfies the interface', () async {
    final controller = RecordingMapController();

    await controller.showPlace(
      const NavigationCoordinate(latitude: 33.78, longitude: -118.11),
      label: 'Horn Center',
      bottomInset: 240,
    );
    await controller.clear();

    expect(controller.calls, ['showPlace:Horn Center:240.0', 'clear']);
  });
}
