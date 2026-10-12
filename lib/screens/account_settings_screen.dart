import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widget_previews.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../data/avatar_draft_controller.dart';
import '../data/profile_gateway.dart';
import '../theme/app_theme.dart';
import '../widgets/profile_avatar.dart';
import 'avatar_crop_screen.dart';

const _navy = Color(0xFF001A3D);
const _page = Color(0xFFFAFAFA);

String _roleLabel(String? role) => switch (role) {
  'student' => 'Student',
  'professor' => 'Professor',
  _ => 'Role not set',
};

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.activeUser;
    final name = user?.name.isNotEmpty == true ? user!.name : 'Khoi Do';
    final email = user?.email.isNotEmpty == true
        ? user!.email
        : 'khoi.do@student.csulb.edu';
    return Scaffold(
      backgroundColor: _page,
      appBar: _appBar(context, 'Profile & Settings'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 48),
        children: [
          Center(child: _AccountAvatar(name: name)),
          const SizedBox(height: 18),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _roleLabel(user?.role),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Color(0xFF555861)),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Color(0xFF555861)),
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              onPressed: () => context.push('/account/edit'),
              style: _outlineStyle(),
              child: const Text('Edit Profile'),
            ),
          ),
          const SizedBox(height: 48),
          _SettingsCard(
            title: 'ACCOUNT',
            items: [
              _SettingsItem(
                Icons.person_outline,
                'Your Profile',
                () => context.push('/account/edit'),
              ),
              _SettingsItem(
                Icons.manage_accounts_outlined,
                'Manage Account',
                () => context.push('/account/manage'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _SettingsCard(
            title: 'SETTINGS',
            items: [
              _SettingsItem(
                Icons.accessible_forward,
                'Navigation & Accessibility',
                () => context.push('/account/accessibility'),
              ),
              _SettingsItem(
                Icons.volume_up_outlined,
                'Voice and Haptics',
                () => _prototypeNotice(context),
              ),
              _SettingsItem(
                Icons.notifications_none,
                'Notifications',
                () => _prototypeNotice(context),
              ),
              _SettingsItem(
                Icons.language,
                'Language',
                () => _prototypeNotice(context),
                trailing: 'English',
              ),
              _SettingsItem(
                Icons.cloud_download_outlined,
                'Offline Campus Map',
                () => _prototypeNotice(context),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _SettingsCard(
            title: 'PRIVACY & SUPPORT',
            items: [
              _SettingsItem(
                Icons.lock_outline,
                'Privacy & Permissions',
                () => context.push('/account/privacy'),
              ),
              _SettingsItem(
                Icons.help_outline,
                'Help & Feedback',
                () => _prototypeNotice(context),
              ),
              _SettingsItem(
                Icons.info_outline,
                'About Navipet',
                () => _prototypeNotice(context),
              ),
            ],
          ),
          const SizedBox(height: 56),
          OutlinedButton(
            onPressed: () => _prototypeNotice(
              context,
              'Sign out will be connected by the backend team.',
            ),
            style: _outlineStyle(foreground: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, this.pickImage});

  /// Injected by widget tests; defaults to the photo library.
  final Future<XFile?> Function()? pickImage;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _name;
  String? _role;

  /// Null when the avatar cannot be edited (guest session or no backend).
  AvatarDraftController? _avatar;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    final current = appState.activeUser?.name;
    _name = TextEditingController(
      text: current?.isNotEmpty == true ? current : 'Khoi Do',
    );
    final savedRole = appState.activeUser?.role;
    _role = savedRole == 'student' || savedRole == 'professor'
        ? savedRole
        : null;
    final gateway = appState.profileGateway;
    if (gateway != null && appState.canEditAvatar) {
      _avatar = AvatarDraftController(gateway)..addListener(_onAvatarChanged);
    }
  }

  void _onAvatarChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    // Leaving without saving discards the pending upload (fire-and-forget).
    _avatar
      ?..removeListener(_onAvatarChanged)
      ..dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final avatar = _avatar;
    if (avatar == null || _saving) return;
    final bytes = await pickAndCropAvatar(context, pickImage: widget.pickImage);
    if (bytes == null || !mounted) return;
    final error = await avatar.upload(bytes, 'avatar.png');
    if (error != null && mounted) _prototypeNotice(context, error);
  }

  Future<void> _save() async {
    if (_role == null) {
      _prototypeNotice(context, 'Choose a role before saving your profile.');
      return;
    }
    final appState = context.read<AppState>();
    final avatar = _avatar;
    final user = appState.activeUser;
    if (avatar == null || user == null) {
      _prototypeNotice(
        context,
        'Profile changes saved locally for this prototype.',
      );
      context.pop();
      return;
    }
    final name = _name.text.trim();
    if (name.isEmpty) {
      _prototypeNotice(context, 'Display name cannot be blank.');
      return;
    }
    final nameChanged = name != user.name;
    if (avatar.isUploading) return;
    final roleChanged = _role != user.role;
    if (!nameChanged && !roleChanged && avatar.pendingUploadId == null) {
      context.pop();
      return;
    }

    setState(() => _saving = true);
    final uploadId = avatar.takeForCommit();
    try {
      await appState.saveProfile(
        displayName: nameChanged ? name : null,
        avatarUploadId: uploadId,
        role: roleChanged ? _role : null,
      );
      if (!mounted) return;
      _prototypeNotice(context, 'Profile saved.');
      context.pop();
    } on ProfileApiException catch (error) {
      final expired = error.statusCode == 404 && uploadId != null;
      if (uploadId != null) {
        avatar.restoreAfterFailedCommit(uploadId, expired: expired);
      }
      if (!mounted) return;
      _prototypeNotice(
        context,
        expired
            ? AvatarDraftController.expiredMessage
            : error.statusCode == 0 || error.statusCode == 408
            ? error.message
            : 'Could not save your profile. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final email = appState.activeUser?.email ?? 'khoi.do@student.csulb.edu';
    final fetchedRole = appState.activeUser?.role;
    if (_role == null &&
        (fetchedRole == 'student' || fetchedRole == 'professor')) {
      _role = fetchedRole;
    }
    final avatar = _avatar;
    final uploading = avatar?.isUploading ?? false;
    final previewUrl = avatar?.previewUrl;
    return Scaffold(
      backgroundColor: _page,
      appBar: _appBar(context, 'Edit Profile'),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FilledButton.icon(
            // Saving mid-upload would commit the previous (or no) photo.
            onPressed: _saving || uploading ? null : _save,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Save Changes'),
            style: _filledStyle(),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 4),
          Center(
            child: _EditableAvatar(
              editable: avatar != null,
              busy: uploading,
              onEdit: _saving ? null : _pickAvatar,
              avatar: _Avatar(
                name: _name.text,
                color: AppColors.blue,
                radius: 48,
                imageUrl: previewUrl ?? appState.activeUser?.avatarUrl,
                // A failed preview is not the saved avatar; refetching the
                // profile would not help it.
                onImageError: previewUrl == null
                    ? appState.reportAvatarLoadFailed
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _label('Display Name'),
          TextField(
            controller: _name,
            inputFormatters: [LengthLimitingTextInputFormatter(80)],
            decoration: _fieldDecoration(Icons.badge_outlined),
          ),
          const SizedBox(height: 16),
          _label('CSULB Email'),
          TextFormField(
            enabled: false,
            initialValue: email,
            decoration: _fieldDecoration(Icons.mail_outline),
          ),
          const SizedBox(height: 16),
          _label('Role *'),
          DropdownButtonFormField<String>(
            key: ValueKey('profile-role-$_role'),
            initialValue: _role,
            hint: const Text('Select a role'),
            decoration: _fieldDecoration(Icons.school_outlined),
            items: const [
              DropdownMenuItem(value: 'student', child: Text('Student')),
              DropdownMenuItem(value: 'professor', child: Text('Professor')),
            ],
            onChanged: (v) => setState(() => _role = v),
          ),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: _navy),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your profile information is private and used to personalize your campus navigation experience.',
                    style: TextStyle(color: Color(0xFF555861), height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ManageAccountScreen extends StatelessWidget {
  const ManageAccountScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.activeUser;
    final name = user?.name.isNotEmpty == true ? user!.name : 'Khoi Do';
    final email = user?.email.isNotEmpty == true
        ? user!.email
        : 'khoi.do@student.csulb.edu';
    return Scaffold(
      backgroundColor: _page,
      appBar: _appBar(context, 'Manage Account'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _plainCard(
            Row(
              children: [
                _Avatar(
                  name: name,
                  color: user?.avatarColor,
                  radius: 30,
                  imageUrl: user?.avatarUrl,
                  onImageError: appState.reportAvatarLoadFailed,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _navy,
                        ),
                      ),
                      Text(
                        email,
                        style: const TextStyle(color: Color(0xFF555861)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          _sectionTitle('ACCOUNT STATUS'),
          _plainCard(
            Column(
              children: [
                _KeyValue(
                  label: 'Campus Role',
                  value: _roleLabel(user?.role),
                  valueColor: Color(0xFFDCE9FF),
                ),
                const Divider(height: 1),
                const _KeyValue(
                  label: 'Status',
                  value: 'Active',
                  valueColor: Color(0xFFFFE28A),
                ),
                const Divider(height: 1),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.verified_outlined,
                    color: Color(0xFF0BAD85),
                  ),
                  title: Text('Connected with CSULB SSO'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          _sectionTitle('SETTINGS'),
          _plainCard(
            Column(
              children: [
                _ManageTile(
                  Icons.link,
                  'Manage connected campus account',
                  () => _prototypeNotice(context),
                ),
                const Divider(height: 1),
                _ManageTile(
                  Icons.download_outlined,
                  'Export Navipet data',
                  () => _prototypeNotice(context),
                ),
                const Divider(height: 1),
                _ManageTile(
                  Icons.logout,
                  'Sign Out',
                  () => _prototypeNotice(
                    context,
                    'Sign out will be connected by the backend team.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 46),
          const Text(
            '⚠ DANGER ZONE',
            style: TextStyle(
              color: Color(0xFFD71920),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFFFB8B8)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  'Deleting your account will permanently remove all associated Navipet data, including saved routes and preferences. This action requires secondary confirmation.',
                  style: TextStyle(color: Color(0xFF555861), height: 1.45),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showDeleteDialog(context),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete Navipet Account'),
                    style: _outlineStyle(foreground: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AccessibilityScreen extends StatefulWidget {
  const AccessibilityScreen({super.key});
  @override
  State<AccessibilityScreen> createState() => _AccessibilityScreenState();
}

class _AccessibilityScreenState extends State<AccessibilityScreen> {
  final Map<String, bool> values = {};
  Widget group(String title, List<(String, String?)> rows) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionTitle(title),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFDDDEE2)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              SwitchListTile(
                value: values[rows[i].$1] ?? false,
                onChanged: (v) => setState(() => values[rows[i].$1] = v),
                activeThumbColor: _navy,
                title: Text(rows[i].$1),
                subtitle: rows[i].$2 == null ? null : Text(rows[i].$2!),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
              ),
              if (i != rows.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ),
      const SizedBox(height: 32),
    ],
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _page,
    appBar: _appBar(context, 'Accessibility'),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        group('MOBILITY', const [
          ('Accessible routes', 'Prioritize wheelchair and ramp access'),
          ('Avoid stairs', null),
          ('Prefer elevators', null),
          ('Avoid steep slopes', null),
        ]),
        group('GUIDANCE', const [
          ('Voice guidance', 'Spoken turn-by-turn directions'),
          ('Haptic turn alerts', null),
        ]),
        group('VISUALS', const [
          ('High-contrast map', null),
          ('Larger map labels', null),
          ('Reduce motion', null),
          ('Screen-reader optimized directions', null),
        ]),
        FilledButton.icon(
          onPressed: () => _prototypeNotice(context),
          icon: const Icon(Icons.report_gmailerrorred),
          label: const Text('Report an accessibility issue'),
          style: _filledStyle(),
        ),
        const SizedBox(height: 12),
      ],
    ),
  );
}

class PrivacyPermissionsScreen extends StatefulWidget {
  const PrivacyPermissionsScreen({super.key});
  @override
  State<PrivacyPermissionsScreen> createState() =>
      _PrivacyPermissionsScreenState();
}

class _PrivacyPermissionsScreenState extends State<PrivacyPermissionsScreen> {
  bool precise = true;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _page,
    appBar: _appBar(context, 'Privacy & Permissions'),
    bottomNavigationBar: const SafeArea(
      child: Padding(
        padding: EdgeInsets.all(22),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.policy_outlined, size: 17, color: _navy),
            SizedBox(width: 5),
            Text(
              'Privacy Policy',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _navy,
              ),
            ),
          ],
        ),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Manage how NaviPet uses your data to provide campus navigation. We prioritize your privacy and only use data essential for your experience.',
          style: TextStyle(fontSize: 16, color: Color(0xFF555861), height: 1.5),
        ),
        const SizedBox(height: 28),
        const Text(
          'App Permissions',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _navy,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFC9CED8)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              const _PermissionTile(
                Icons.location_on_outlined,
                'Location While Using',
                'Used for map guidance',
                'Always',
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: precise,
                onChanged: (v) => setState(() => precise = v),
                activeTrackColor: AppColors.yellow,
                title: const Text(
                  'Precise Location',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Required for turn-by-turn'),
                secondary: const Icon(Icons.gps_fixed, color: _navy),
              ),
              const Divider(height: 1),
              const _PermissionTile(
                Icons.camera_alt_outlined,
                'Camera for Indoor AR',
                'Required to scan signs',
                'Enabled',
              ),
              const Divider(height: 1),
              const _PermissionTile(
                Icons.explore_outlined,
                'Motion and Orientation',
                null,
                'Enabled',
              ),
              const Divider(height: 1),
              const _PermissionTile(
                Icons.notifications_none,
                'Notifications',
                null,
                'On',
              ),
              const Divider(height: 1),
              const _PermissionTile(
                Icons.calendar_today_outlined,
                'Calendar Access',
                'Used to find class locations',
                'Disabled',
              ),
            ],
          ),
        ),
        const SizedBox(height: 38),
        const Text(
          'Activity History',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _navy,
          ),
        ),
        const SizedBox(height: 14),
        _historyCard(
          context,
          Icons.history,
          'Recent Search History',
          "Manage or delete locations you've recently searched for on campus.",
          'Clear Recent Searches',
        ),
        const SizedBox(height: 16),
        _historyCard(
          context,
          Icons.route_outlined,
          'Navigation History',
          "Manage or delete records of routes you've navigated using NaviPet.",
          'Clear Navigation History',
        ),
      ],
    ),
  );
}

PreferredSizeWidget _appBar(BuildContext context, String title) => AppBar(
  backgroundColor: _page,
  surfaceTintColor: _page,
  centerTitle: true,
  elevation: 0,
  scrolledUnderElevation: 0,
  title: Text(
    title,
    style: const TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.w700,
      color: _navy,
    ),
  ),
  leading: IconButton(
    onPressed: () => context.canPop() ? context.pop() : context.go('/map'),
    icon: const Icon(Icons.arrow_back, color: _navy),
  ),
);
ButtonStyle _outlineStyle({Color foreground = _navy}) =>
    OutlinedButton.styleFrom(
      foregroundColor: foreground,
      side: BorderSide(color: foreground),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: const StadiumBorder(),
    );
ButtonStyle _filledStyle() => FilledButton.styleFrom(
  backgroundColor: _navy,
  foregroundColor: Colors.white,
  padding: const EdgeInsets.symmetric(vertical: 15),
  shape: const StadiumBorder(),
);
Widget _label(String value) => Padding(
  padding: const EdgeInsets.only(bottom: 5),
  child: Text(
    value,
    style: const TextStyle(fontSize: 13, color: Color(0xFF555861)),
  ),
);
InputDecoration _fieldDecoration(IconData icon) => InputDecoration(
  prefixIcon: Icon(icon),
  filled: true,
  fillColor: const Color(0xFFF3F3F4),
  border: OutlineInputBorder(
    borderSide: BorderSide.none,
    borderRadius: BorderRadius.circular(8),
  ),
);
Widget _sectionTitle(String value) => Padding(
  padding: const EdgeInsets.only(left: 8, bottom: 8),
  child: Text(
    value,
    style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: Color(0xFF454852),
      letterSpacing: .2,
    ),
  ),
);
Widget _plainCard(Widget child) => Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    boxShadow: AppShadows.soft,
  ),
  child: child,
);

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.name,
    this.color,
    this.radius = 46,
    this.imageUrl,
    this.onImageError,
  });
  final String name;
  final Color? color;
  final double radius;
  final String? imageUrl;
  final ValueChanged<String>? onImageError;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius + 2,
    backgroundColor: _navy,
    child: ProfileAvatar(
      name: name,
      color: color ?? AppColors.blue,
      size: radius * 2,
      imageUrl: imageUrl,
      onImageError: onImageError,
      initialStyle: TextStyle(
        fontSize: radius * .72,
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// An avatar with a progress overlay and, when [editable], a pencil badge.
class _EditableAvatar extends StatelessWidget {
  const _EditableAvatar({
    required this.avatar,
    required this.editable,
    this.busy = false,
    this.onEdit,
  });
  final Widget avatar;
  final bool editable;
  final bool busy;

  /// Null disables the badge (e.g. while saving).
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      avatar,
      if (busy)
        const Positioned.fill(
          child: Center(child: CircularProgressIndicator()),
        ),
      if (editable)
        Positioned(
          right: -4,
          bottom: -4,
          child: IconButton.filled(
            tooltip: 'Change profile photo',
            onPressed: busy ? null : onEdit,
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              backgroundColor: _navy,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF7A8699),
              disabledForegroundColor: Colors.white,
              side: const BorderSide(color: Colors.white, width: 2),
            ),
            icon: const Icon(Icons.edit, size: 18),
          ),
        ),
    ],
  );
}

/// The Profile & Settings avatar. There is no Save step on that screen, so a
/// cropped photo is uploaded and committed straight away.
class _AccountAvatar extends StatefulWidget {
  const _AccountAvatar({required this.name});
  final String name;
  @override
  State<_AccountAvatar> createState() => _AccountAvatarState();
}

class _AccountAvatarState extends State<_AccountAvatar> {
  /// Created on first use; disposing it discards an upload still in flight
  /// when the user leaves the screen.
  AvatarDraftController? _draft;
  bool _busy = false;

  @override
  void dispose() {
    _draft?.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    final appState = context.read<AppState>();
    final gateway = appState.profileGateway;
    if (gateway == null || !appState.canEditAvatar || _busy) return;
    final bytes = await pickAndCropAvatar(context);
    if (bytes == null || !mounted) return;
    final draft = _draft ??= AvatarDraftController(gateway);
    setState(() => _busy = true);
    try {
      final error = await draft.upload(bytes, 'avatar.png');
      if (error != null) {
        if (mounted) _prototypeNotice(context, error);
        return;
      }
      final uploadId = draft.takeForCommit();
      if (uploadId == null) return;
      try {
        await appState.saveProfile(avatarUploadId: uploadId);
      } on ProfileApiException catch (error) {
        // After a timeout or lost connection the update may still have
        // committed the upload, and a committed upload must never be
        // discarded; the server clears a stranded one after 24 hours.
        final ambiguous = error.statusCode == 0 || error.statusCode == 408;
        if (!ambiguous) gateway.discardAvatarUpload(uploadId).ignore();
        if (mounted) {
          _prototypeNotice(
            context,
            ambiguous
                ? error.message
                : 'Could not update your profile photo. Please try again.',
          );
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.activeUser;
    return _EditableAvatar(
      editable: appState.canEditAvatar,
      busy: _busy,
      onEdit: _change,
      avatar: _Avatar(
        name: widget.name,
        color: user?.avatarColor,
        imageUrl: user?.avatarUrl,
        onImageError: appState.reportAvatarLoadFailed,
      ),
    );
  }
}

class _SettingsItem {
  const _SettingsItem(this.icon, this.label, this.onTap, {this.trailing});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailing;
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.items});
  final String title;
  final List<_SettingsItem> items;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: AppShadows.card,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF454852),
            letterSpacing: .5,
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < items.length; i++) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(items[i].icon, color: _navy, size: 23),
            title: Text(items[i].label, style: const TextStyle(fontSize: 16)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (items[i].trailing != null)
                  Text(
                    items[i].trailing!,
                    style: const TextStyle(color: Color(0xFF666872)),
                  ),
                const Icon(Icons.chevron_right, color: Color(0xFFC4C7CE)),
              ],
            ),
            onTap: items[i].onTap,
          ),
          if (i != items.length - 1) const Divider(height: 1),
        ],
      ],
    ),
  );
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({
    required this.label,
    required this.value,
    required this.valueColor,
  });
  final String label, value;
  final Color valueColor;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: valueColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(value),
        ),
      ],
    ),
  );
}

class _ManageTile extends StatelessWidget {
  const _ManageTile(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: const Color(0xFFF2F3F5),
      child: Icon(icon, color: _navy, size: 19),
    ),
    title: Text(label),
    trailing: const Icon(Icons.chevron_right, color: Color(0xFFC4C7CE)),
    onTap: onTap,
  );
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile(this.icon, this.title, this.subtitle, this.value);
  final IconData icon;
  final String title, value;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: _navy),
    title: Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [Text(value), const Icon(Icons.chevron_right, size: 18)],
    ),
  );
}

Widget _historyCard(
  BuildContext context,
  IconData icon,
  String title,
  String description,
  String button,
) => Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    border: Border.all(color: const Color(0xFFC9CED8)),
    borderRadius: BorderRadius.circular(14),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, color: _navy),
          const SizedBox(width: 9),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
      const SizedBox(height: 8),
      Text(description, style: const TextStyle(color: Color(0xFF555861))),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => _prototypeNotice(context, '$title cleared locally.'),
          style: _outlineStyle(),
          child: Text(button),
        ),
      ),
    ],
  ),
);
void _prototypeNotice(
  BuildContext context, [
  String message = 'This control is ready for backend integration.',
]) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));
void _showDeleteDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    title: const Text('Delete Navipet Account?'),
    content: const Text(
      'This prototype does not delete any data. The backend team can connect account deletion here.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialogContext),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(dialogContext),
        child: const Text('Confirm UI'),
      ),
    ],
  ),
);

@Preview(group: 'Avatar', name: 'Pencil badge', size: Size(220, 220))
Widget editableAvatarPreview() => _avatarPreviewFrame(
  _EditableAvatar(
    avatar: const _Avatar(name: 'Jane Doe'),
    editable: true,
    onEdit: () {},
  ),
);

@Preview(group: 'Avatar', name: 'Uploading', size: Size(220, 220))
Widget uploadingAvatarPreview() => _avatarPreviewFrame(
  _EditableAvatar(
    avatar: const _Avatar(name: 'Jane Doe'),
    editable: true,
    busy: true,
    onEdit: () {},
  ),
);

@Preview(group: 'Avatar', name: 'Guest (no pencil)', size: Size(220, 220))
Widget guestAvatarPreview() => _avatarPreviewFrame(
  const _EditableAvatar(avatar: _Avatar(name: 'Guest'), editable: false),
);

Widget _avatarPreviewFrame(Widget child) => Material(
  color: _page,
  child: Center(child: child),
);
