import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/app_config.dart';
import 'data/app_state.dart';
import 'data/auth_token_provider.dart';
import 'data/campus_search_controller.dart';
import 'data/campus_search_gateway.dart';
import 'data/location_service.dart';
import 'data/mapbox_config.dart';
import 'data/mapbox_navigation_service.dart';
import 'data/navigation_flow_controller.dart';
import 'data/recent_searches_gateway.dart';
import 'data/registration_gateway.dart';
import 'data/route_repository.dart';
import 'data/search_history_store.dart';
import 'data/search_location_provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the public Mapbox token (and any other env values) before the app
  // starts. Missing .env is tolerated so the app still boots (the map will be
  // blank until a token is provided) — see README for setup.
  await dotenv.load(fileName: '.env', isOptional: true);

  SupabaseClient? supabase;
  if (AppConfig.hasSupabase) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabasePublishableKey,
    );
    supabase = Supabase.instance.client;
  }

  final registrationGateway = AppConfig.hasBackend
      ? HttpRegistrationGateway(baseUrl: AppConfig.backendBaseUrl)
      : null;

  // Hand the public token to the native Mapbox SDK.
  MapboxOptions.setAccessToken(mapboxPublicToken);

  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

  final authTokenProvider = supabase == null
      ? null
      : SupabaseAuthTokenProvider(supabase.auth);

  runApp(
    NaviPetApp(
      appState: AppState(
        supabase: supabase,
        registrationGateway: registrationGateway,
      ),
      authTokenProvider: authTokenProvider,
    ),
  );
}

class NaviPetApp extends StatefulWidget {
  const NaviPetApp({super.key, required this.appState, this.authTokenProvider});

  final AppState appState;

  /// Null when Supabase is not configured; the flow's gateways fall back to
  /// [AnonymousAuthTokenProvider] rather than requiring one.
  final AuthTokenProvider? authTokenProvider;

  @override
  State<NaviPetApp> createState() => _NaviPetAppState();
}

class _NaviPetAppState extends State<NaviPetApp> {
  late final _router = createAppRouter(widget.appState);
  late final NavigationFlowController _flow = _buildFlow();

  /// The signed-in identity the flow currently reflects, so a later change
  /// (sign-out, sign-in, or a different user signing in on the same device)
  /// can be told apart from any other `AppState` change. `_flow` is
  /// app-scoped and outlives any one session — without this, a new user
  /// would briefly see the previous one's destination, origin, and recent
  /// searches until something happened to overwrite it.
  String? _flowIdentity;

  @override
  void initState() {
    super.initState();
    _flowIdentity = widget.appState.activeUser?.id;
    widget.appState.addListener(_onAppStateChanged);
  }

  void _onAppStateChanged() {
    final identity = widget.appState.activeUser?.id;
    if (identity == _flowIdentity) return;
    _flowIdentity = identity;
    _flow.resetForNewIdentity();
  }

  NavigationFlowController _buildFlow() {
    final auth = widget.authTokenProvider;
    final searchGateway = HttpCampusSearchGateway(
      baseUrl: AppConfig.backendBaseUrl,
      auth: auth,
    );
    final routeGateway = MapboxNavigationService(
      accessToken: mapboxPublicToken,
    );
    final recents = CachedRecentSearches(
      remote: HttpRecentSearchesGateway(
        baseUrl: AppConfig.backendBaseUrl,
        auth: auth ?? AnonymousAuthTokenProvider(),
      ),
      cache: SearchHistoryStore(),
    );
    return NavigationFlowController(
      search: CampusSearchController(
        gateway: searchGateway,
        location: GeolocatorSearchLocationProvider(),
      ),
      searchGateway: searchGateway,
      recentSearches: recents,
      routes: RouteRepository(gateway: routeGateway),
      location: GeolocatorLocationService(),
      // No `map:` — defaults to a no-op until MapScreen.onMapCreated calls
      // attachMap() with the real Mapbox map. The flow is built here, in
      // initState, always before that map exists.
    );
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onAppStateChanged);
    _router.dispose();
    widget.appState.dispose();
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.appState),
        ChangeNotifierProvider.value(value: _flow),
      ],
      child: MaterialApp.router(
        title: 'NaviPet',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          scaffoldBackgroundColor: AppColors.background,
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent),
          fontFamily: 'Plus Jakarta Sans',
          useMaterial3: true,
        ),
        routerConfig: _router,
      ),
    );
  }
}
