import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/floor_prior.dart';

void main() {
  test('verified entrance and confirmed route floor provide suggestions', () {
    final prior = FloorPrior();
    expect(prior.suggestionFor('route-a').floor, isNull);
    prior.verifiedEntrance('route-a', 1);
    expect(prior.suggestionFor('route-a').floor, 1);
    expect(
      prior.suggestionFor('route-a').confidence,
      FloorPriorConfidence.confirmed,
    );
    prior.confirmFloor('route-a', 2);
    expect(prior.suggestionFor('route-a').floor, 2);
    expect(prior.suggestionFor('route-b').floor, isNull);
  });

  test(
    'tracked transitions lower confidence and invalidation removes suggestion',
    () {
      final prior = FloorPrior()..verifiedEntrance('route-a', 1);
      prior.trackedTransition('route-a', 2);
      expect(prior.suggestionFor('route-a').floor, 2);
      expect(
        prior.suggestionFor('route-a').confidence,
        FloorPriorConfidence.tracked,
      );
      prior.trackingLost();
      expect(prior.suggestionFor('route-a').floor, isNull);
      expect(prior.suggestionFor('route-a').isStale, isTrue);
      prior.trackedTransition('route-a', 3);
      expect(prior.suggestionFor('route-a').floor, isNull);
      prior.confirmFloor('route-a', 3);
      prior.unobservedTransition();
      expect(prior.suggestionFor('route-a').isStale, isTrue);
      expect(prior.suggestionFor('route-a').floor, isNull);
    },
  );

  test('route changes and a new process cannot reuse prior state', () {
    final prior = FloorPrior()..verifiedEntrance('route-a', 1);
    prior.trackedTransition('route-b', 2);
    expect(prior.suggestionFor('route-b').floor, isNull);
    expect(FloorPrior().suggestionFor('route-a').floor, isNull);
  });
}
