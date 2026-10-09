/// The signed-in user's platform profile from `/auth/session` or `/me`.
class MeProfile {
  const MeProfile({
    required this.id,
    required this.roles,
    this.displayName,
    this.phone,
    this.email,
    this.photoMediaId,
    this.photoUrl,
    this.photoThumbnailUrl,
    this.createdAt,
  });

  factory MeProfile.fromJson(Object? json) {
    final map = json! as Map<String, dynamic>;
    return MeProfile(
      id: map['id'] as String,
      displayName: map['displayName'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      roles: (map['roles'] as List<dynamic>).cast<String>(),
      photoMediaId: switch (map['photo']) {
        final Map<String, dynamic> p => p['mediaId'] as String,
        _ => null,
      },
      photoUrl: switch (map['photo']) {
        final Map<String, dynamic> p => p['url'] as String,
        _ => null,
      },
      photoThumbnailUrl: switch (map['photo']) {
        final Map<String, dynamic> p => p['thumbnailUrl'] as String,
        _ => null,
      },
      createdAt: switch (map['createdAt']) {
        final String s => DateTime.parse(s).toLocal(),
        _ => null,
      },
    );
  }

  final String id;
  final String? displayName;
  final String? phone;
  final String? email;
  final List<String> roles;

  /// Profile photo (M21): signed, short-lived URLs; null without a photo.
  final String? photoMediaId;
  final String? photoUrl;
  final String? photoThumbnailUrl;
  final DateTime? createdAt;

  /// Best available label for "signed in as".
  String get label => displayName ?? email ?? phone ?? 'Your account';
}

sealed class SessionState {
  const SessionState();
}

/// Not signed in; public screens only.
class GuestSession extends SessionState {
  const GuestSession({this.message});

  /// Why the user was signed out (e.g. session revoked), shown once.
  final String? message;
}

/// Restoring a previous Firebase session on start.
class RestoringSession extends SessionState {
  const RestoringSession();
}

/// Signed in with Firebase, but the backend profile could not be loaded
/// (offline, server error). The session is kept; the app can retry.
class ProfilePendingSession extends SessionState {
  const ProfilePendingSession();
}

class SignedInSession extends SessionState {
  const SignedInSession(this.profile);
  final MeProfile profile;
}
