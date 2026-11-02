import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NavigationAlertFrequency { everyTurn, every20Feet }

/// Device-local navigation preferences used by settings and live guidance.
class NavigationAccessibilityPreferences extends ChangeNotifier {
  NavigationAccessibilityPreferences({SharedPreferences? preferences})
    : _preferences = preferences;

  SharedPreferences? _preferences;
  final Map<String, bool> _values = {
    'Accessible routes': false,
    'Avoid stairs': false,
    'Prefer elevators': false,
    'Avoid steep slopes': false,
    'Voice guidance': true,
    'Haptic turn alerts': true,
    'High-contrast map': false,
    'Larger map labels': false,
    'Reduce motion': false,
    'Screen-reader optimized directions': false,
  };
  NavigationAlertFrequency _frequency = NavigationAlertFrequency.everyTurn;

  bool value(String label) => _values[label] ?? false;
  NavigationAlertFrequency get frequency => _frequency;

  Future<void> load() async {
    _preferences ??= await SharedPreferences.getInstance();
    for (final key in _values.keys.toList()) {
      _values[key] = _preferences!.getBool('navigation.accessibility.$key') ??
          _values[key]!;
    }
    _frequency = NavigationAlertFrequency.values[
      (_preferences!.getInt('navigation.accessibility.frequency') ?? 0)
          .clamp(0, NavigationAlertFrequency.values.length - 1)
          .toInt()
    ];
    notifyListeners();
  }

  Future<void> setValue(String label, bool value) async {
    if (!_values.containsKey(label) || _values[label] == value) return;
    _values[label] = value;
    notifyListeners();
    _preferences ??= await SharedPreferences.getInstance();
    await _preferences!.setBool('navigation.accessibility.$label', value);
  }

  Future<void> setFrequency(NavigationAlertFrequency value) async {
    if (_frequency == value) return;
    _frequency = value;
    notifyListeners();
    _preferences ??= await SharedPreferences.getInstance();
    await _preferences!.setInt('navigation.accessibility.frequency', value.index);
  }
}
