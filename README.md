# Building arrival simulator evidence

Captured with Maestro 2.12.0 on iPhone 17 Pro / iOS 26.5.
All destination geometry, route replies and accuracy readings are explicitly
labeled synthetic fixtures in tool/navigation_e2e.dart. No production geometry,
verified entrance, live account, or credentials are present.

Final Maestro run: 3/3 flows passed in 2m 19s.
Outside: Horn Center to College of Business, one route request, footprint and
route preview, Satellite/Standard reload, then active walking guidance.
Inside: existing arrived state, zero route requests, no already-here UI.
Uncertain: 80 m accuracy, refresh/continue choice, no false arrival; explicit
continuation requests a route.

Original recordings and screenshots remain outside the source checkout in the
task evidence directory. Published recordings are H.264, 15 fps, 960 pixels tall
for download size; screenshots retain their original resolution.
