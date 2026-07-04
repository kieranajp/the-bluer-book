/// HomeRole mirrors the server-side `home_role` enum.
enum HomeRole {
  owner,
  member;

  static HomeRole fromJson(String v) => switch (v) {
        'owner' => HomeRole.owner,
        'member' => HomeRole.member,
        _ => throw FormatException('Unknown home role: $v'),
      };
}

/// A home (household) the signed-in user belongs to, along with their
/// role in it. Shape matches one element of the `homes` array returned
/// by GET /api/me. Hand-written rather than freezed-generated so this
/// Phase-5 change doesn't depend on running build_runner before CI's
/// `flutter analyze` (which doesn't regenerate codegen) — and the type
/// is small enough that copyWith / equality aren't worth the extra
/// generated files.
class HomeMembership {
  final String uuid;
  final String name;
  final HomeRole role;

  const HomeMembership({
    required this.uuid,
    required this.name,
    required this.role,
  });

  factory HomeMembership.fromJson(Map<String, dynamic> json) {
    return HomeMembership(
      uuid: json['uuid'] as String,
      name: json['name'] as String,
      role: HomeRole.fromJson(json['role'] as String),
    );
  }
}

/// Me is the body of GET /api/me — who the caller is and which home
/// the request was scoped to. Drives the auth provider's signed-in
/// state and the settings screen's account section.
class Me {
  final String? activeHomeId;
  final List<HomeMembership> homes;

  const Me({this.activeHomeId, required this.homes});

  factory Me.fromJson(Map<String, dynamic> json) {
    final raw = json['homes'];
    final list = raw is List
        ? raw
            .whereType<Map<String, dynamic>>()
            .map(HomeMembership.fromJson)
            .toList(growable: false)
        : const <HomeMembership>[];
    return Me(
      activeHomeId: json['active_home_id'] as String?,
      homes: list,
    );
  }

  /// Convenience accessor for the [HomeMembership] matching [activeHomeId].
  HomeMembership? get activeHome {
    if (activeHomeId == null) return null;
    for (final h in homes) {
      if (h.uuid == activeHomeId) return h;
    }
    return null;
  }
}
