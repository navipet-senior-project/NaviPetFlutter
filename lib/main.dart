import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/app_config.dart';
import 'data/app_state.dart';
import 'data/mapbox_config.dart';
import 'data/registration_gateway.dart';
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

  runApp(
    NaviPetApp(
      appState: AppState(
        supabase: supabase,
        registrationGateway: registrationGateway,
      ),
    ),
  );
}

class NaviPetApp extends StatefulWidget {
  const NaviPetApp({super.key, required this.appState});

  final AppState appState;

  @override
  State<NaviPetApp> createState() => _NaviPetAppState();
}

class _NaviPetAppState extends State<NaviPetApp> {
  late final _router = createAppRouter(widget.appState);

  @override
  void dispose() {
    _router.dispose();
    widget.appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.appState,
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
