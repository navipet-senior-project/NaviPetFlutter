import 'package:flutter/material.dart';

import '../data/campus_place.dart';
import '../data/campus_search_controller.dart';
import '../data/navigation_flow_controller.dart';
import '../data/navigation_flow_state.dart';
import '../theme/app_theme.dart';
import 'campus_search_result_tile.dart';

/// Full-height search surface drawn over the live map.
class SearchOverlay extends StatefulWidget {
  const SearchOverlay({super.key, required this.controller});

  final NavigationFlowController controller;

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay> {
  final _field = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    final state = widget.controller.state;
    if (state is FlowSearching && state.query.isNotEmpty) {
      _field.text = state.query;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = widget.controller.search;
    final padding = MediaQuery.paddingOf(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    // Material, not ColoredBox: CampusSearchResultTile's ListTile paints its
    // background and ink splashes on the nearest Material ancestor, and a
    // plain ColoredBox in between blocks that (Flutter raises "ListTile
    // background color or ink splashes may be invisible" otherwise).
    return Material(
      color: AppColors.screenBg,
      child: Column(
        children: [
          SizedBox(height: padding.top + AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Semantics(
                  label: 'Close search',
                  button: true,
                  child: IconButton(
                    onPressed: widget.controller.back,
                    icon: const Icon(Icons.arrow_back, color: AppColors.navy),
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _field,
                    focusNode: _focus,
                    onChanged: (value) {
                      widget.controller.queryChanged(value);
                      setState(() {});
                    },
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(color: AppColors.navy),
                    decoration: InputDecoration(
                      hintText: 'Search campus',
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      suffixIcon: _field.text.isEmpty
                          ? null
                          : Semantics(
                              label: 'Clear search',
                              button: true,
                              child: IconButton(
                                onPressed: () {
                                  _field.clear();
                                  widget.controller.queryChanged('');
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close),
                              ),
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (search.status == CampusSearchStatus.loading ||
              search.status == CampusSearchStatus.typing)
            const LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.yellow,
            ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: _body(search),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(CampusSearchController search) {
    switch (search.status) {
      case CampusSearchStatus.initial:
        return _recents();
      case CampusSearchStatus.typing:
      case CampusSearchStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case CampusSearchStatus.results:
        return _results(search.results);
      case CampusSearchStatus.noResults:
        return _message(
          "No campus places match '${search.query}'. "
          'NaviPet searches CSULB only.',
        );
      case CampusSearchStatus.offline:
        return _message('Campus search is offline.', onRetry: search.retry);
      case CampusSearchStatus.apiError:
        return _message(
          search.message ?? 'Campus search failed.',
          onRetry: search.retry,
        );
      case CampusSearchStatus.unauthorized:
        return _message('Sign in again to search campus.');
      case CampusSearchStatus.permissionRequired:
        return _message('Turn on location to search near you.');
      case CampusSearchStatus.locationUnavailable:
        return _message('We could not read your location.');
    }
  }

  Widget _results(List<CampusPlace> places) {
    final groups = <CampusDestinationType, List<CampusPlace>>{};
    for (final place in places) {
      groups.putIfAbsent(place.type, () => []).add(place);
    }

    return Semantics(
      liveRegion: true,
      label: '${places.length} campus results',
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          for (final entry in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                _groupLabel(entry.key),
                style: const TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (final place in entry.value)
              CampusSearchResultTile(
                place: place,
                onTap: () {
                  FocusScope.of(context).unfocus();
                  widget.controller.selectPlace(place);
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget _recents() {
    final recents = widget.controller.recents;
    if (recents.isEmpty) {
      return _message('Search a building, parking lot, or campus service.');
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent searches',
                style: TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextButton(
                onPressed: widget.controller.clearRecents,
                child: const Text('Clear all'),
              ),
            ],
          ),
        ),
        for (final place in recents)
          CampusSearchResultTile(
            place: place,
            onTap: () {
              FocusScope.of(context).unfocus();
              widget.controller.selectPlace(place);
            },
          ),
      ],
    );
  }

  Widget _message(String text, {VoidCallback? onRetry}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    ),
  );

  static String _groupLabel(CampusDestinationType type) => switch (type) {
    CampusDestinationType.building => 'Buildings',
    CampusDestinationType.room => 'Rooms',
    CampusDestinationType.entrance => 'Entrances',
    CampusDestinationType.parking => 'Parking',
    CampusDestinationType.dining => 'Dining',
    CampusDestinationType.service => 'Services',
    CampusDestinationType.amenity => 'Amenities',
    CampusDestinationType.transit => 'Transit',
    CampusDestinationType.housing => 'Housing',
    CampusDestinationType.landmark => 'Landmarks',
    CampusDestinationType.external => 'Other places',
  };
}
