# Building arrival: final published-head simulator evidence

App source and CI head: 9c0b2f7a8eab4247191a4217d2b2ea7ec8d46b61.
Maestro 2.12.0, iPhone 17 Pro / iOS 26.5, mocked locations: 3/3 passed in
2m 32s. Outside 51s; inside 45s; uncertain 56s. All 501 Flutter tests passed
on this same source head; all three CI checks passed.

The final iOS debug kernel was rebuilt for this source head with flutter build
bundle --target-platform=ios and installed into the existing native debug shell.
Native code/dependencies did not change. Existing configured basemap assets were
retained. Screenshots show the actual basemap and production MapScreen/controller.
The debug target tool/navigation_e2e.dart supplies explicitly labeled synthetic
building geometry, search replies, route replies and GPS accuracy; these fixtures
do not establish authoritative campus geometry or entrance coverage. No login
credentials were used or printed.

Outside: Horn Center to College of Business; selected amber footprint, Satellite
and Standard style reload, walking preview and guidance, exactly one route request.
Inside: existing arrived state directly, zero route requests, no already-here UI.
Uncertain: 80 m GPS accuracy, nonblocking refresh/continue, no false arrival;
explicit continuation requests walking directions.

Missing-footprint fallback, expired/replayed sample polling, room handoff and
Mapbox layer/source counts are unit/flow tested, not separately driven live here.
Automated review left 27 files unverified twice. Firstmate accepted the
zero-finding, low-risk review gate; full tests, simulator flows and CI provide
verification. Original PR history is preserved. No backend/schema changes.

Screenshots retain original resolution. Recordings are compressed H.264 at
15 fps, 960 pixels tall for download size. Original captures stay outside app
source in the task evidence directory.
