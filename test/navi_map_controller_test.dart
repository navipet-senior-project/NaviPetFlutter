import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/navi_map_controller.dart';
import 'package:navipet/data/navigation_models.dart';

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
  Future<void> showGuidance(
    List<NavigationCoordinate> remaining, {
    required NavigationCoordinate position,
    required NaviDestination destination,
    double? bearing,
  }) async => calls.add('showGuidance');

  @override
  Future<void> clear() async => calls.add('clear');
}

void main() {
  test('route camera replaces stale place-sheet padding', () {
    final camera = routeCameraOptions(bottomInset: 320);

    expect(camera.padding?.top, 140);
    expect(camera.padding?.left, 48);
    expect(camera.padding?.bottom, 320);
    expect(camera.padding?.right, 48);
  });

  test('guidance arrow stays at the user and follows their heading', () {
    const position = NavigationCoordinate(latitude: 33.78, longitude: -118.11);
    final arrow = userArrowOptions(position, bearing: 125);

    expect(arrow.geometry.coordinates.lat, position.latitude);
    expect(arrow.geometry.coordinates.lng, position.longitude);
    expect(arrow.textField, '▲');
    expect(arrow.textRotate, 125);
    expect(arrow.textSize, userArrowSize);
    expect(userArrowSize, greaterThan(42));
    expect(guidanceRouteWidth, greaterThan(selectedRouteWidth));
    expect(selectedRouteWidth, greaterThan(7));
  });

  test('destination has a visible pin at its exact coordinate', () {
    const destination = NavigationCoordinate(
      latitude: 33.79,
      longitude: -118.10,
    );
    final pin = destinationPinOptions(destination);

    expect(pin.geometry.coordinates.lat, destination.latitude);
    expect(pin.geometry.coordinates.lng, destination.longitude);
    expect(pin.textField, '◆');
    expect(pin.textSize, greaterThan(30));
  });

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
