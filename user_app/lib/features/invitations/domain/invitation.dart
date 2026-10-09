import 'dart:ui' show Color;

import '../../../core/error/result.dart';

/// A design from the server catalogue (M19 answer 3; more added later).
class InvitationTemplate {
  const InvitationTemplate({
    required this.code,
    required this.name,
    required this.background,
    required this.surface,
    required this.text,
    required this.accent,
    required this.headingFont,
    required this.ornament,
  });

  final String code;
  final String name;
  final Color background;
  final Color surface;
  final Color text;
  final Color accent;

  /// serif, sans or script.
  final String headingFont;

  /// none, lines, floral, diya or stars.
  final String ornament;
}

enum InvitationStatus {
  draft('Draft'),
  published('Published'),
  revoked('Link turned off');

  const InvitationStatus(this.label);
  final String label;

  static InvitationStatus fromApi(String value) =>
      InvitationStatus.values.byName(value.toLowerCase());
}

class RsvpTotals {
  const RsvpTotals({
    required this.attending,
    required this.maybe,
    required this.notAttending,
    required this.guests,
  });

  static const zero = RsvpTotals(
    attending: 0,
    maybe: 0,
    notAttending: 0,
    guests: 0,
  );

  final int attending;
  final int maybe;
  final int notAttending;

  /// People coming (sum of "attending" guest counts).
  final int guests;

  int get replies => attending + maybe + notAttending;
}

/// An event's e-invitation (M19, R9). One per event.
class Invitation {
  const Invitation({
    required this.id,
    required this.eventId,
    required this.templateCode,
    required this.title,
    required this.message,
    required this.hostNames,
    required this.eventDate,
    required this.startTime,
    required this.venueName,
    required this.venueAddress,
    required this.status,
    required this.rsvpOpen,
    required this.rsvpClosesOn,
    required this.totals,
  });

  final String id;
  final String eventId;
  final String templateCode;
  final String title;
  final String? message;
  final String? hostNames;
  final DateTime eventDate;

  /// "HH:MM" or null.
  final String? startTime;
  final String? venueName;
  final String? venueAddress;
  final InvitationStatus status;
  final bool rsvpOpen;
  final DateTime rsvpClosesOn;
  final RsvpTotals totals;
}

class InvitationInput {
  const InvitationInput({
    required this.templateCode,
    required this.title,
    this.message,
    this.hostNames,
  });

  final String templateCode;
  final String title;
  final String? message;
  final String? hostNames;
}

enum RsvpResponse {
  attending('Coming'),
  maybe('Maybe'),
  notAttending('Not coming');

  const RsvpResponse(this.label);
  final String label;

  static RsvpResponse fromApi(String value) => switch (value) {
    'ATTENDING' => attending,
    'MAYBE' => maybe,
    _ => notAttending,
  };
}

class Rsvp {
  const Rsvp({
    required this.id,
    required this.guestName,
    required this.response,
    required this.guestCount,
    required this.message,
    required this.updatedAt,
  });

  final String id;
  final String guestName;
  final RsvpResponse response;
  final int guestCount;
  final String? message;
  final DateTime updatedAt;
}

class RsvpList {
  const RsvpList({required this.totals, required this.rsvps});

  final RsvpTotals totals;
  final List<Rsvp> rsvps;
}

/// A published invitation and its link (returned only when issued).
class PublishedInvitation {
  const PublishedInvitation({required this.invitation, required this.link});

  final Invitation invitation;
  final String link;
}

/// Invitations (api-contracts.md Part B, M19).
abstract class InvitationsRepository {
  Future<Result<List<InvitationTemplate>>> templates();
  Future<Result<Invitation?>> get(String eventId);
  Future<Result<Invitation>> save(String eventId, InvitationInput input);
  Future<Result<PublishedInvitation>> publish(String eventId);
  Future<Result<PublishedInvitation>> newLink(String eventId);
  Future<Result<Invitation>> setRsvpOpen(String eventId, bool open);
  Future<Result<Invitation>> revoke(String eventId);
  Future<Result<RsvpList>> rsvps(String eventId);

  /// The link is only returned when issued: kept on this phone (M19).
  Future<String?> savedLink(String invitationId);
  Future<void> saveLink(String invitationId, String link);
}
