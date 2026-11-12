import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/indoor_ar_contract.dart';
import '../data/outdoor_ar_contract.dart';
import '../theme/app_theme.dart';
import 'ar_mode_icon.dart';

typedef OutdoorArLaunch =
    Future<IndoorArResult> Function(OutdoorArRequest request);

class OutdoorArEntryButton extends StatelessWidget {
  const OutdoorArEntryButton({
    super.key,
    required this.onPressed,
    this.available = false,
  });

  final VoidCallback onPressed;

  /// False when this build cannot start outdoor AR at all.
  final bool available;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      label: available ? 'Outdoor AR' : 'Outdoor AR unavailable',
      hint: available
          ? 'Opens the outdoor AR camera view'
          : 'Shows why outdoor AR guidance is not available yet',
      button: true,
      child: Tooltip(
        message: available ? 'Outdoor AR' : 'Outdoor AR unavailable',
        child: Material(
          color: Colors.white,
          elevation: 3,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: const SizedBox(
              width: 112,
              height: 56,
              child: Center(
                child: ExcludeSemantics(
                  child: ArModeIcon(color: AppColors.navy, size: 40),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<bool> requestOutdoorArCamera() async =>
    (await Permission.camera.request()).isGranted;

/// Notice, camera permission, then the AR session. Every path that does not
/// reach AR leaves the map and its active route exactly as they were.
// shortcut: consent is asked on every launch; persist it if that gets tiresome.
Future<void> startOutdoorAr(
  BuildContext context, {
  required OutdoorArRequest request,
  required OutdoorArLaunch launch,
  required Future<bool> Function() requestCamera,
}) async {
  if (await _showDataUseNotice(context) != true) return;
  if (!await requestCamera()) {
    if (context.mounted) {
      await showOutdoorArUnavailableDialog(
        context,
        message:
            'Outdoor AR needs camera access. Your walking route stays active on the map.',
      );
    }
    return;
  }
  final result = await launch(request);
  if (!context.mounted) return;
  switch (result.status) {
    case IndoorArStatus.arrived || IndoorArStatus.cancelled:
      return;
    case IndoorArStatus.unavailable:
      await showOutdoorArUnavailableDialog(context);
    case IndoorArStatus.localizationFailed || IndoorArStatus.error:
      // BAD_REQUEST is how a Unity library without the outdoor scene answers.
      await showOutdoorArUnavailableDialog(
        context,
        message: result.errorCode == 'BAD_REQUEST'
            ? null
            : 'Outdoor AR could not start. Your walking route stays active on the map.',
      );
  }
}

/// Wording and links are the ones Google requires of ARCore Geospatial apps:
/// https://developers.google.com/ar/develop/privacy-requirements
Future<bool?> _showDataUseNotice(BuildContext context) => showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Outdoor AR'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This application runs on Google Play Services for AR (ARCore), '
            'which is provided by Google and governed by the Google Privacy '
            'Policy.\n\n'
            'To power this session, Google will process sensor data (e.g., '
            'camera and location).',
          ),
          TextButton(
            onPressed: () => _open(
              'https://support.google.com/ar?p=how-google-play-services-for-ar-handles-your-data',
            ),
            child: const Text('Learn more'),
          ),
          TextButton(
            onPressed: () => _open('https://policies.google.com/privacy'),
            child: const Text('Google Privacy Policy'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Not now'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(true),
        child: const Text('Agree and continue'),
      ),
    ],
  ),
);

Future<void> _open(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

Future<void> showOutdoorArUnavailableDialog(
  BuildContext context, {
  String? message,
}) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Outdoor AR unavailable'),
    content: Text(
      message ??
          'Outdoor AR guidance is not available yet. Your walking route stays active on the map.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Return to map'),
      ),
    ],
  ),
);
