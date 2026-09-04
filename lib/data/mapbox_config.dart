import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Mapbox configuration for NaviPet, ported from the RN `data/mapbox.ts`.
///
/// The Mapbox *public* token (pk.*) is read from the `.env` file at runtime
/// (key `MAPBOX_PUBLIC_TOKEN`) — the Flutter analog of the RN
/// `EXPO_PUBLIC_MAPBOX_TOKEN`. It is kept out of source control; copy
/// `.env.example` to `.env` and fill in your token. See README for setup.
///
/// Note: the native Mapbox SDK *also* needs a separate secret *download* token
/// (sk.*) configured at build time — that is NOT this value. See README.
String get mapboxPublicToken => dotenv.maybeGet('MAPBOX_PUBLIC_TOKEN') ?? '';

/// Mapbox Standard is the base for the pitched 3D campus experience.
const String mapboxStyle = 'mapbox://styles/mapbox/standard';

/// California State University, Long Beach — campus center. The focus point the
/// map opens on and where the "You" pet marker is dropped.
const double csulbLat = 33.7838;
const double csulbLng = -118.1141;

/// Default zoom level when opening the map on campus.
const double csulbZoom = 15;
