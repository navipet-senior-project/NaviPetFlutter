# NaviPet Project Map

Use these labels when assigning issues, reviewing pull requests, or deciding
where new code belongs.

## Frontend

Flutter screens, reusable UI, visual styling, routing, and bundled artwork.

| Path | Responsibility |
| --- | --- |
| `lib/screens/` | Complete app screens and user interactions |
| `lib/widgets/` | Reusable Flutter UI components |
| `lib/theme/` | Colors, spacing, typography, and visual tokens |
| `lib/router/` | Routes, redirects, and navigation between screens |
| `assets/` | Images, mascot artwork, and fonts |
| `lib/main.dart` | Flutter app startup and dependency providers |

Typical frontend work includes layouts, accessibility, animations, forms,
navigation flows, and loading or error states.

## Client services and shared models

These files run on the phone. They connect the frontend to external services,
hold app state, and translate API responses into Dart models. They are not a
trusted backend and must never contain service-role keys or server secrets.

| Path | Responsibility |
| --- | --- |
| `lib/data/app_state.dart` | Authentication, classes, tasks, and shared state |
| `lib/data/app_config.dart` | Safe client configuration checks |
| `lib/data/mapbox_config.dart` | Public Mapbox configuration and defaults |
| `lib/data/mapbox_navigation_service.dart` | Mapbox Search and Directions calls |
| `lib/data/search_history_store.dart` | On-device recent-search storage |
| `lib/data/course_class.dart` | Class and generated-task models |
| `lib/data/navigation_models.dart` | Destination, route, and coordinate models |
| `lib/data/user_account.dart` | Signed-in user model |

Typical client-service work includes API integration, caching, state handling,
serialization, and converting backend data for the UI.

## Backend

The external backend repository owns server code and database infrastructure.
Supabase provides authentication, persisted application data, and
authorization.

| Repository or service | Responsibility |
| --- | --- |
| [`Ben2104/NavipetBackend`](https://github.com/Ben2104/NavipetBackend) | Fastify API, Supabase schema, migrations, RLS policies, and server configuration |
| Supabase Authentication | Accounts, sessions, password reset, and anonymous users |
| Supabase project | Hosted PostgreSQL data and backend configuration |

Privileged operations and server-only integrations belong in
`Ben2104/NavipetBackend`, never directly inside `lib/`.

## Platform and build configuration

| Path | Responsibility |
| --- | --- |
| `android/` | Android manifest, Gradle configuration, and native Kotlin code |
| `ios/` | Xcode project, permissions, and native Swift code |
| `pubspec.yaml` | Flutter dependencies, assets, fonts, and app version |
| `analysis_options.yaml` | Dart and Flutter lint rules |
| `test/` | Automated Dart and Flutter tests |

MultiSet integration will eventually touch both Platform and Client Services:
its native SDK belongs under `android/` and `ios/`, while its Flutter-facing
adapter and localization models belong under `lib/data/`.

## Quick ownership guide

| Change | Primary label | Usually touches |
| --- | --- | --- |
| Change a screen design | Frontend | `lib/screens/`, `lib/widgets/`, `lib/theme/` |
| Add a Supabase field or table | Backend | `Ben2104/NavipetBackend/supabase/schema.sql` |
| Display new Supabase data | Client Services + Frontend | `lib/data/`, then UI |
| Change Mapbox routing | Client Services | `lib/data/mapbox_navigation_service.dart` |
| Add Android/iOS permissions | Platform | `android/`, `ios/` |
| Add MultiSet indoor tracking | Platform + Client Services + Frontend | Native SDK, adapter, indoor screen |

## Collaboration rules

1. Never commit `.env`, secret Mapbox download tokens, Supabase service-role
   keys, or MultiSet client secrets.
2. Database changes should be repeatable and include appropriate RLS policies.
3. Keep reusable UI in `widgets`, full pages in `screens`, and API logic out of
   widgets.
4. Run `flutter analyze` and `flutter test` before handing work to another
   collaborator.
