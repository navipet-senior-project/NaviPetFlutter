import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/navigation_flow_state.dart';

import 'support/flow_fakes.dart' as harness;

void main() {
  test('starts idle', () {
    expect(harness.build().state, isA<FlowIdle>());
  });

  test('opening search enters the searching state', () {
    final controller = harness.build()..openSearch();

    expect(controller.state, isA<FlowSearching>());
  });

  test('selecting a mapped place opens a routable preview', () async {
    final map = harness.RecordingMap();
    final controller = harness.build(map: map)..openSearch();

    await controller.selectPlace(harness.horn);

    final state = controller.state as FlowPlacePreview;
    expect(state.routable, isTrue);
    expect(state.destination!.name, 'Horn Center');
    expect(map.calls, contains('showPlace:Horn Center'));
  });

  test('selecting an unmapped place opens a non-routable preview', () async {
    final controller = harness.build()..openSearch();

    await controller.selectPlace(harness.unmapped);

    final state = controller.state as FlowPlacePreview;
    expect(state.routable, isFalse);
    expect(state.destination, isNull);
  });

  test('selecting a place records it in recents', () async {
    final recents = harness.FakeRecents();
    final controller = harness.build(recents: recents)..openSearch();

    await controller.selectPlace(harness.horn);

    expect(recents.saved, [harness.horn.id]);
  });

  test('back from a preview returns to search with the query kept', () async {
    final controller = harness.build()..openSearch();
    controller.queryChanged('horn');
    await controller.selectPlace(harness.horn);

    controller.back();

    final state = controller.state as FlowSearching;
    expect(state.query, 'horn');
  });

  test('back from search returns to idle and clears the map', () {
    final map = harness.RecordingMap();
    final controller = harness.build(map: map)..openSearch();

    controller.back();

    expect(controller.state, isA<FlowIdle>());
    expect(map.calls, contains('clear'));
  });

  test(
    'a stale selectPlace reply is discarded once a newer one lands',
    () async {
      final search = harness.FakeSearchGateway();
      // Block the first selectPlace's gateway reply so it stays in flight
      // while a second, newer selectPlace runs to completion first.
      search.blockPlace(harness.horn.id);
      final controller = harness.build(search: search)..openSearch();

      final firstSelect = controller.selectPlace(harness.horn);
      await controller.selectPlace(harness.unmapped);

      // Now let the stale first reply land.
      search.unblockPlace(harness.horn.id);
      await firstSelect;

      final state = controller.state as FlowPlacePreview;
      expect(state.place.id, harness.unmapped.id);
      expect(state.routable, isFalse);
    },
  );
}
