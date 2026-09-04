import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/navigation_models.dart';
import '../theme/app_theme.dart';

const _navy = Color(0xFF001A3D);
const _yellow = Color(0xFFFFCB05);

class DestinationDetailsScreen extends StatefulWidget {
  const DestinationDetailsScreen({super.key, this.destination});
  final NaviDestination? destination;
  @override
  State<DestinationDetailsScreen> createState() =>
      _DestinationDetailsScreenState();
}

class _DestinationDetailsScreenState extends State<DestinationDetailsScreen> {
  int entrance = 0;
  @override
  Widget build(BuildContext context) {
    final name = widget.destination?.name ?? 'College of Business';
    return Scaffold(
      backgroundColor: const Color(0xFFE9ECEC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Campus Map',
          style: TextStyle(fontWeight: FontWeight.w700, color: _navy),
        ),
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _CampusBlocksPainter())),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _navy,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '▦ CBA',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: _yellow,
                  child: Icon(
                    Icons.location_on_outlined,
                    color: _navy,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: .58,
            minChildSize: .52,
            maxChildSize: .82,
            builder: (context, controller) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: AppShadows.card,
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC7CAD2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: _navy,
                          ),
                        ),
                      ),
                      _pill(
                        '● Open',
                        const Color(0xFFE6F8EC),
                        const Color(0xFF08752B),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'CBA   •   Room 234',
                    style: TextStyle(color: Color(0xFF555861)),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7F8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E3E7)),
                    ),
                    child: const Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Color(0xFFDDE9FF),
                          child: Icon(Icons.directions_walk, color: _navy),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: _Metric(label: 'EST. TIME', value: '8 min'),
                        ),
                        VerticalDivider(),
                        Expanded(
                          child: _Metric(label: 'DISTANCE', value: '0.4 mi'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 14),
                  const Text(
                    'Select Entrance',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _entrance(
                    0,
                    'Nearest Entrance (North)',
                    'Stairs required. Closest path from your current location.',
                    null,
                  ),
                  const SizedBox(height: 12),
                  _entrance(
                    1,
                    'Accessible Entrance (East)',
                    'Ramp access. Automatic doors. +2 min walk.',
                    Icons.accessible,
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _notice(context, 'Destination saved locally.'),
                          icon: const Icon(Icons.bookmark_border),
                          label: const Text('Save'),
                          style: _outline(),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: () => context.pop(true),
                          icon: const Icon(Icons.directions_outlined),
                          label: const Text('Directions'),
                          style: _filled(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _entrance(
    int value,
    String title,
    String subtitle,
    IconData? trailing,
  ) => InkWell(
    onTap: () => setState(() => entrance = value),
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: entrance == value ? const Color(0xFFFFFBF0) : Colors.white,
        border: Border.all(
          color: entrance == value ? _yellow : const Color(0xFFE2E3E7),
          width: entrance == value ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            entrance == value
                ? Icons.radio_button_checked
                : Icons.radio_button_off,
            color: entrance == value ? _yellow : const Color(0xFF747780),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF62656D),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) Icon(trailing, color: Colors.blue),
        ],
      ),
    ),
  );
}

class OutdoorNavigationScreen extends StatelessWidget {
  const OutdoorNavigationScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Color(0xFFF6F1DF))),
        Positioned.fill(child: CustomPaint(painter: _RoutePainter())),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _instruction(
                  Icons.turn_right,
                  'Turn right after the Library',
                  'in 0.1 mi',
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: FloatingActionButton.small(
                      heroTag: 'off-route',
                      backgroundColor: Colors.white,
                      foregroundColor: _navy,
                      onPressed: () => context.push('/navigation/off-route'),
                      child: const Badge(child: Icon(Icons.pets)),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text(
                            '8',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                              color: _navy,
                            ),
                          ),
                          const Text(' min'),
                          const Spacer(),
                          FilledButton(
                            onPressed: () => context.go('/map'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFFFDADA),
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Exit'),
                          ),
                        ],
                      ),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '0.4 mi  •  12:45 PM',
                          style: TextStyle(color: Color(0xFF62656D)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () =>
                              context.push('/navigation/campus-arrival'),
                          child: const Text('Continue to building →'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class OffRouteScreen extends StatelessWidget {
  const OffRouteScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Container(
          width: double.infinity,
          color: const Color(0xFFFFDADA),
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top + 16,
            20,
            16,
          ),
          child: const Row(
            children: [
              CircleAvatar(
                backgroundColor: Color(0xFFC71920),
                child: Icon(Icons.priority_high, color: Colors.white),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "You're off route",
                    style: TextStyle(
                      fontSize: 20,
                      color: Color(0xFFC71920),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Recalculating your path...',
                    style: TextStyle(color: Color(0xFFC71920)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Expanded(
          child: ColoredBox(
            color: Color(0xFFD5E6F0),
            child: Center(
              child: Icon(Icons.route, size: 100, color: Color(0x33001A3D)),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(0xFFF2F3F4),
                    child: Icon(Icons.sync, color: _navy),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recalculating path...',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text('Finding the best route to Student Union'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Row(
                      children: [
                        Text('◷ New ETA'),
                        Spacer(),
                        Text(
                          '12 mins',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Text('♿ Extra Distance'),
                        Spacer(),
                        Text('+0.2 miles'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.route),
                  label: const Text('Resume Route'),
                  style: _filled(),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/map'),
                child: const Text('Cancel Navigation'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class CampusArrivalScreen extends StatelessWidget {
  const CampusArrivalScreen({super.key});
  @override
  Widget build(BuildContext context) => _IndoorBackdrop(
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    onPressed: () => context.go('/map'),
                    icon: const Icon(Icons.close),
                  ),
                ),
                const Spacer(),
                _pill('NaviPet', Colors.white, _navy),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppShadows.card,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "You've arrived!",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    "Great job. Now, let's head inside to find Room 140.",
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF62656D),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Color(0xFFFFF4C8),
                      child: Icon(
                        Icons.check_circle_outline,
                        color: Color(0xFF8B7000),
                      ),
                    ),
                    title: Text(
                      'Outdoor leg complete',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('Room 140 is still inside'),
                  ),
                  const Divider(),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => context.push('/navigation/localize'),
                      icon: const Icon(Icons.view_in_ar_outlined),
                      label: const Text('Continue Indoors (AR)'),
                      style: _filled(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'ⓘ  Indoor AR positioning requires temporary access to your camera and motion sensors. GPS is inaccurate indoors.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF555861),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class LocalizationScreen extends StatefulWidget {
  const LocalizationScreen({super.key});
  @override
  State<LocalizationScreen> createState() => _LocalizationScreenState();
}

class _LocalizationScreenState extends State<LocalizationScreen> {
  double progress = .4;
  void scan() {
    setState(() => progress = (progress + .3).clamp(0, 1));
    if (progress >= .7) {
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        if (mounted) context.pushReplacement('/navigation/indoor');
      });
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: scan,
    child: _IndoorBackdrop(
      dark: true,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0x553B4652),
                    child: IconButton(
                      onPressed: context.pop,
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'NaviPet',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  CircleAvatar(
                    backgroundColor: const Color(0x553B4652),
                    child: IconButton(
                      onPressed: () => context.go('/map'),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0x66707880),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _yellow,
                      child: Icon(Icons.pets, color: _navy),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stop walking.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Scan a room sign or landmark to localize.',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Icon(Icons.crop_free, color: Colors.white, size: 210),
              const SizedBox(height: 30),
              Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    color: _yellow,
                    backgroundColor: Colors.white30,
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'LOCATING...  Tap to scan',
                style: TextStyle(color: Colors.white),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    ),
  );
}

class IndoorNavigationScreen extends StatelessWidget {
  const IndoorNavigationScreen({super.key});
  @override
  Widget build(BuildContext context) => _IndoorBackdrop(
    child: SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: _instruction(
              Icons.turn_left,
              'Continue down this hallway',
              '80 ft to Room 140',
            ),
          ),
          const Positioned(
            top: 180,
            left: 35,
            child: Chip(
              label: Text('● HIGH CONFIDENCE'),
              backgroundColor: Color(0xAA555555),
              labelStyle: TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.keyboard_arrow_down, color: _yellow, size: 46),
                Icon(Icons.keyboard_arrow_down, color: _yellow, size: 46),
                Icon(Icons.keyboard_arrow_down, color: _yellow, size: 46),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Row(
              children: [
                FloatingActionButton(
                  onPressed: () => _notice(context, 'Map view stays in 3D.'),
                  backgroundColor: Colors.white,
                  foregroundColor: _navy,
                  child: const Icon(Icons.map_outlined),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => context.push('/navigation/elevator'),
                  style: _filled(),
                  child: const Text('Next: Elevator'),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  heroTag: 'exit-ar',
                  onPressed: () => context.go('/map'),
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class ElevatorTransitionScreen extends StatelessWidget {
  const ElevatorTransitionScreen({super.key});
  @override
  Widget build(BuildContext context) => _IndoorBackdrop(
    dark: true,
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconButton(
                  onPressed: context.pop,
                  icon: const Icon(Icons.arrow_back, color: _navy),
                ),
                const Expanded(
                  child: Text(
                    'Beach Navigator',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _notice(context),
                  icon: const Icon(Icons.settings_outlined, color: _navy),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFDFDFE),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: _navy,
                      child: Icon(Icons.elevator_outlined, color: Colors.white),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Take Elevator to Floor 2',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _navy,
                            ),
                          ),
                          Text(
                            'Distance: 15 ft',
                            style: TextStyle(color: Color(0xFF62656D)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    avatar: Icon(Icons.accessible, size: 16),
                    label: Text('Step-Free Route'),
                    backgroundColor: Color(0xFFFFF1C7),
                  ),
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Expanded(
                      child: _FloorCard(label: 'CURRENT', value: 'Floor 1'),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _FloorCard(label: 'DESTINATION', value: 'Floor 2'),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () =>
                        context.pushReplacement('/navigation/final'),
                    style: _filled(),
                    child: const Text("I'm on the next floor  →"),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _notice(context),
                    style: _outline(),
                    child: const Text('Choose another connector'),
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.sync, color: _navy),
                SizedBox(width: 12),
                Expanded(
                  child: LinearProgressIndicator(
                    value: .65,
                    color: _yellow,
                    backgroundColor: Color(0xFFF0F0F0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class FinalArrivalScreen extends StatelessWidget {
  const FinalArrivalScreen({super.key});
  @override
  Widget build(BuildContext context) => _IndoorBackdrop(
    dark: true,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Spacer(),
            Image.asset('assets/images/shark_side.png', width: 120),
            Transform.translate(
              offset: const Offset(0, -10),
              child: const CircleAvatar(
                backgroundColor: _yellow,
                child: Icon(Icons.location_on_outlined, color: _navy),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                children: [
                  const Text(
                    "You've arrived!",
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Expanded(
                        child: Text(
                          'College of\nBusiness',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text('•'),
                      Expanded(
                        child: Text(
                          'Floor\n2',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text('•'),
                      Expanded(
                        child: Text(
                          'Room\n140',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _pill(
                    '◷ 8 min   |   〽 0.4 miles',
                    const Color(0xFFF0F0F2),
                    const Color(0xFF555861),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => context.go('/map'),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('End Navigation'),
                      style: _filled(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _notice(context, 'Destination saved locally.'),
                      icon: const Icon(Icons.bookmark_border),
                      label: const Text('Save Destination'),
                      style: _outline(),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _notice(context),
                    child: const Text('⚠ Report Incorrect Room'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _IndoorBackdrop extends StatelessWidget {
  const _IndoorBackdrop({required this.child, this.dark = false});
  final Widget child;
  final bool dark;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF8F969C), Color(0xFF394653)]
              : const [Color(0xFFE6E0D5), Color(0xFFD7E1E4), Color(0xFFB9C4C9)],
        ),
      ),
      child: child,
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 10, color: Color(0xFF7A7D86)),
      ),
      Text(
        value,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _navy,
        ),
      ),
    ],
  );
}

class _FloorCard extends StatelessWidget {
  const _FloorCard({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F7F8),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: const Color(0xFFE8E8EA)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10)),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _navy,
          ),
        ),
      ],
    ),
  );
}

Widget _instruction(IconData icon, String title, String subtitle) => Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    boxShadow: AppShadows.card,
  ),
  child: Row(
    children: [
      Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: _navy,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: _navy,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 16, color: Color(0xFF555861)),
            ),
          ],
        ),
      ),
    ],
  ),
);
Widget _pill(String text, Color color, Color foreground) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
  decoration: BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(20),
  ),
  child: Text(
    text,
    style: TextStyle(
      color: foreground,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
  ),
);
ButtonStyle _filled() => FilledButton.styleFrom(
  backgroundColor: _navy,
  foregroundColor: Colors.white,
  padding: const EdgeInsets.symmetric(vertical: 15),
  shape: const StadiumBorder(),
);
ButtonStyle _outline() => OutlinedButton.styleFrom(
  foregroundColor: _navy,
  side: const BorderSide(color: _navy),
  padding: const EdgeInsets.symmetric(vertical: 14),
  shape: const StadiumBorder(),
);
void _notice(
  BuildContext context, [
  String message = 'This control is ready for integration.',
]) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));

class _CampusBlocksPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFF9F9FA)
      ..style = PaintingStyle.fill;
    final line = Paint()
      ..color = const Color(0xFF35577D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final r in [
      Rect.fromLTWH(size.width * .25, size.height * .12, 120, 80),
      Rect.fromLTWH(size.width * .50, size.height * .32, 150, 100),
      Rect.fromLTWH(size.width * .08, size.height * .48, 130, 95),
    ]) {
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)), p);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(6)),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = const Color(0x44FFFFFF)
      ..strokeWidth = 58
      ..strokeCap = StrokeCap.round;
    final route = Paint()
      ..color = const Color(0xFF00366C)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * .58, size.height * .78)
      ..lineTo(size.width * .47, size.height * .56)
      ..lineTo(size.width * .29, size.height * .40);
    canvas.drawPath(path, road);
    canvas.drawPath(path, route);
    canvas.drawCircle(
      Offset(size.width * .58, size.height * .78),
      13,
      Paint()..color = const Color(0xFF2878E5),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
