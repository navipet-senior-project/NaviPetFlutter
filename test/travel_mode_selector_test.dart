import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/travel_mode.dart';
import 'package:navipet/widgets/travel_mode_selector.dart';

Widget host({
  required TravelMode selected,
  ValueChanged<TravelMode>? onChanged,
}) => MaterialApp(
  home: Scaffold(
    body: TravelModeSelector(
      selected: selected,
      onChanged: onChanged ?? (_) {},
    ),
  ),
);

void main() {
  testWidgets('renders one chip per enabled mode, none more', (tester) async {
    await tester.pumpWidget(host(selected: TravelMode.walking));

    // enabledTravelModes currently contains only TravelMode.walking — this
    // must stay a count check against the registry, not a hard-coded "4
    // chips" assumption, or it would silently stop catching a regression
    // that renders every TravelMode regardless of enablement.
    expect(find.byType(ChoiceChip), findsNWidgets(enabledTravelModes.length));
    expect(find.text('Walking'), findsOneWidget);
  });

  testWidgets('marks the chip selected when it matches the selected mode', (
    tester,
  ) async {
    await tester.pumpWidget(host(selected: TravelMode.walking));

    final chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip));
    expect(chip.selected, isTrue);
  });

  testWidgets('marks the chip unselected when it does not match', (
    tester,
  ) async {
    // TravelMode.shuttle is not in enabledTravelModes and therefore never
    // renders its own chip, but passing it as `selected` still proves the
    // walking chip's `selected` flag is driven by the comparison rather
    // than always true.
    await tester.pumpWidget(host(selected: TravelMode.shuttle));

    final chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip));
    expect(chip.selected, isFalse);
  });

  testWidgets('tapping the chip fires onChanged with that mode', (
    tester,
  ) async {
    TravelMode? changedTo;
    await tester.pumpWidget(
      host(selected: TravelMode.walking, onChanged: (mode) => changedTo = mode),
    );

    await tester.tap(find.byType(ChoiceChip));

    expect(changedTo, TravelMode.walking);
  });
}
