import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserAccount {
  const UserAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarColor,
    required this.gems,
    required this.level,
    this.isAnonymous = false,
    this.avatarUrl,
    this.role,
  });

  final String id;
  final String name;
  final String email;
  final Color avatarColor;
  final int gems;
  final int level;
  final bool isAnonymous;

  /// Signed avatar URL from the NaviPet backend; it expires after about an
  /// hour. `null` means show the initials avatar instead.
  final String? avatarUrl;
  final String? role;

  factory UserAccount.fromSupabase(
    User user, {
    Map<String, dynamic>? profile,
    String? avatarUrl,
  }) {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final name = (profile?['display_name'] ?? metadata['display_name'] ?? '')
        .toString()
        .trim();
    final avatarValue =
        int.tryParse((profile?['avatar_color'] ?? '').toString()) ??
        _colorFor(user.id).toARGB32();

    return UserAccount(
      id: user.id,
      name: name.isEmpty
          ? (user.isAnonymous ? 'Guest Explorer' : _emailName(user.email))
          : name,
      email: user.email ?? (user.isAnonymous ? 'Anonymous guest' : ''),
      avatarColor: Color(avatarValue),
      gems: _asInt(profile?['gems']),
      level: _asInt(profile?['level'], fallback: 1),
      isAnonymous: user.isAnonymous,
      avatarUrl: avatarUrl,
      role: profile?['role']?.toString(),
    );
  }

  /// [avatarUrl] is a getter so callers can clear it by returning `null`.
  UserAccount copyWith({
    String? name,
    String? Function()? avatarUrl,
    String? role,
  }) => UserAccount(
    id: id,
    name: name ?? this.name,
    email: email,
    avatarColor: avatarColor,
    gems: gems,
    level: level,
    isAnonymous: isAnonymous,
    avatarUrl: avatarUrl == null ? this.avatarUrl : avatarUrl(),
    role: role ?? this.role,
  );

  static String _emailName(String? email) {
    final value = email?.split('@').first.trim() ?? '';
    if (value.isEmpty) return 'NaviPet Explorer';
    return value
        .split(RegExp(r'[._-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static Color _colorFor(String seed) {
    const colors = [
      Color(0xFFFFB000),
      Color(0xFF0EA5A4),
      Color(0xFF2F80ED),
      Color(0xFF8B5CF6),
      Color(0xFFEF476F),
    ];
    return colors[seed.hashCode.abs() % colors.length];
  }
}
