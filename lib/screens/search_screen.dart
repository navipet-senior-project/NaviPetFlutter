import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../data/course_class.dart';
import '../data/mapbox_config.dart';
import '../data/mapbox_navigation_service.dart';
import '../data/navigation_models.dart';
import '../data/search_history_store.dart';
import '../theme/app_theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final MapboxNavigationService _service;
  final _historyStore = SearchHistoryStore();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = const [];
  List<NaviDestination> _recent = const [];
  bool _loading = false;
  String? _error;

  static const _campusDestinations = [
    NaviDestination(
      name: 'University Student Union',
      address: 'Food, events, services & lounge',
      coordinate: NavigationCoordinate(latitude: 33.7812, longitude: -118.1128),
    ),
    NaviDestination(
      name: 'University Library',
      address: 'Study spaces, computers & research',
      coordinate: NavigationCoordinate(latitude: 33.7789, longitude: -118.1140),
    ),
    NaviDestination(
      name: 'Student Recreation Center',
      address: 'Fitness, recreation & wellness',
      coordinate: NavigationCoordinate(latitude: 33.7854, longitude: -118.1107),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _service = MapboxNavigationService(accessToken: mapboxPublicToken);
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final recent = await _historyStore.load();
      if (mounted) setState(() => _recent = recent);
    } catch (_) {
      // A malformed old preference should never prevent destination search.
      await _historyStore.clear();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _service.dispose();
    super.dispose();
  }

  NavigationCoordinate _anchor() {
    final courses = context.read<AppState>().classes;
    if (courses.isEmpty) {
      return const NavigationCoordinate(
        latitude: csulbLat,
        longitude: csulbLng,
      );
    }
    return NavigationCoordinate(
      latitude:
          courses.map((course) => course.latitude).reduce((a, b) => a + b) /
          courses.length,
      longitude:
          courses.map((course) => course.longitude).reduce((a, b) => a + b) /
          courses.length,
    );
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    setState(() {});
    if (value.trim().length < 2) {
      setState(() {
        _suggestions = const [];
        _error = null;
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final suggestions = await _service.suggestPlaces(
        query,
        proximity: _anchor(),
      );
      if (!mounted || query != _controller.text) return;
      setState(() => _suggestions = suggestions);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final destination = await _service.retrievePlace(suggestion);
      await _finish(destination);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _finish(NaviDestination destination) async {
    _recent = await _historyStore.add(destination);
    if (mounted) context.pop(destination);
  }

  Future<void> _clearHistory() async {
    await _historyStore.clear();
    if (mounted) setState(() => _recent = const []);
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _controller.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.screenBg,
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        titleSpacing: 0,
        title: Container(
          height: 46,
          margin: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            onChanged: _onQueryChanged,
            onSubmitted: (_) {
              if (!_loading && _suggestions.isNotEmpty) {
                _selectSuggestion(_suggestions.first);
              }
            },
            textInputAction: TextInputAction.search,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Where to, explorer?',
              prefixIcon: const Icon(Icons.search, size: 21),
              suffixIcon: hasQuery
                  ? IconButton(
                      onPressed: () {
                        _controller.clear();
                        _onQueryChanged('');
                      },
                      icon: const Icon(Icons.close, size: 20),
                    )
                  : const Icon(Icons.mic_none, size: 20),
              contentPadding: EdgeInsets.zero,
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: const BorderSide(
                  color: AppColors.amber,
                  width: 1.4,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: const BorderSide(color: AppColors.amber, width: 2),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_loading)
            const LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.yellow,
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          Expanded(child: hasQuery ? _results() : _discovery()),
        ],
      ),
    );
  }

  Widget _results() {
    if (_controller.text.trim().length < 2) {
      return const Center(child: Text('Type at least two characters.'));
    }
    if (!_loading && _suggestions.isEmpty) {
      return const Center(child: Text('No destinations found.'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
          child: Text(
            'Search results',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
            itemCount: _suggestions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final suggestion = _suggestions[index];
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: _loading ? null : () => _selectSuggestion(suggestion),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppColors.accentSoft,
                          child: Icon(
                            Icons.location_on_outlined,
                            color: AppColors.amberInk,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                suggestion.name,
                                style: const TextStyle(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (suggestion.description.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  suggestion.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 15,
                          color: AppColors.faint,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _discovery() {
    final courses = context.watch<AppState>().classes;
    final anchor = _anchor();
    final popular = [..._campusDestinations]
      ..sort(
        (a, b) => _distance(
          anchor,
          a.coordinate,
        ).compareTo(_distance(anchor, b.coordinate)),
      );
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        Row(
          children: [
            Image.asset(
              'assets/images/shark_side.png',
              width: 48,
              height: 48,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Find your way,',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.petInk,
                  ),
                ),
                Text(
                  'Your companion is ready to lead!',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 22),
        _sectionHeader(
          'Recent Searches',
          _recent.isEmpty ? null : 'Clear All',
          _clearHistory,
        ),
        const SizedBox(height: 10),
        if (_recent.isEmpty) _emptyRecent() else ..._recent.map(_recentCard),
        const SizedBox(height: 22),
        _sectionHeader('Popular Locations', null, null),
        const SizedBox(height: 10),
        _popularCard(
          popular.first,
          _distance(anchor, popular.first.coordinate),
        ),
        const SizedBox(height: 8),
        _sectionHeader('Near Your Classes', null, null),
        const SizedBox(height: 10),
        if (courses.isEmpty)
          _addClassesHint()
        else
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: courses.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, index) => _classCard(courses[index]),
            ),
          ),
      ],
    );
  }

  Widget _sectionHeader(String title, String? action, VoidCallback? onTap) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.petInk,
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onTap,
              child: Text(
                action,
                style: const TextStyle(
                  color: AppColors.accentDark,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      );

  Widget _emptyRecent() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: AppShadows.soft,
    ),
    child: const Text(
      'Your last 3 destinations will appear here.',
      style: TextStyle(color: AppColors.muted, fontSize: 12),
    ),
  );

  Widget _recentCard(NaviDestination item) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: ListTile(
        onTap: () => _finish(item),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFF1F5F9),
          child: Icon(Icons.history, color: AppColors.petInk, size: 19),
        ),
        title: Text(item.name, style: const TextStyle(fontSize: 13)),
        subtitle: Text(
          item.address,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10),
        ),
      ),
    ),
  );

  Widget _popularCard(NaviDestination item, double miles) => InkWell(
    onTap: () => _finish(item),
    borderRadius: BorderRadius.circular(14),
    child: Container(
      height: 148,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF00376E),
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.yellow,
            child: Icon(
              Icons.school_outlined,
              color: AppColors.petInk,
              size: 19,
            ),
          ),
          const Spacer(),
          Text(
            item.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            item.address,
            style: const TextStyle(color: Color(0xFFD9E6F4), fontSize: 11),
          ),
          const SizedBox(height: 8),
          Text(
            '⌖ ${miles.toStringAsFixed(1)} miles from your classes',
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    ),
  );

  Widget _classCard(CourseClass course) => InkWell(
    onTap: () => _finish(course.destination),
    borderRadius: BorderRadius.circular(14),
    child: Container(
      width: 196,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFFE9EAEC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.account_balance_outlined,
              color: AppColors.petInk,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  course.locationLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  course.courseCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Class location',
                    style: TextStyle(fontSize: 8, color: AppColors.amberInk),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _addClassesHint() => InkWell(
    onTap: () => context.push('/checklist'),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: const Row(
        children: [
          Icon(Icons.add_circle_outline, color: AppColors.petInk),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Add your classes to see nearby destinations here.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    ),
  );

  double _distance(NavigationCoordinate a, NavigationCoordinate b) {
    const radiusMiles = 3958.8;
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final deltaLat = (b.latitude - a.latitude) * pi / 180;
    final deltaLng = (b.longitude - a.longitude) * pi / 180;
    final value =
        sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1) * cos(lat2) * sin(deltaLng / 2) * sin(deltaLng / 2);
    return radiusMiles * 2 * atan2(sqrt(value), sqrt(1 - value));
  }
}
