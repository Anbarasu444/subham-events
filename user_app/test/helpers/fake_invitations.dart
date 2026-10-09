import 'dart:ui' show Color;

import 'package:user_app/core/error/failure.dart';
import 'package:user_app/core/error/result.dart';
import 'package:user_app/features/invitations/domain/invitation.dart';

const testTemplates = [
  InvitationTemplate(
    code: 'classic',
    name: 'Classic',
    background: Color(0xFFFBF6EE),
    surface: Color(0xFFFFFFFF),
    text: Color(0xFF3A2E1F),
    accent: Color(0xFFB08D57),
    headingFont: 'serif',
    ornament: 'lines',
  ),
  InvitationTemplate(
    code: 'festive',
    name: 'Festive',
    background: Color(0xFF7A1F2B),
    surface: Color(0xFFFFF4E0),
    text: Color(0xFF3B1418),
    accent: Color(0xFFE0A526),
    headingFont: 'script',
    ornament: 'diya',
  ),
];

/// In-memory invitations following the server rules (enough for widgets).
class FakeInvitationsRepository implements InvitationsRepository {
  FakeInvitationsRepository({this.eventDate});

  final DateTime? eventDate;
  final Map<String, Invitation> invitations = {};
  final Map<String, RsvpList> replies = {};
  final Map<String, String> links = {};
  final List<String> calls = [];
  Failure? failNext;
  int _seq = 0;

  Result<T>? _failure<T>() {
    final f = failNext;
    failNext = null;
    return f == null ? null : Err(f);
  }

  Invitation _copy(
    Invitation i, {
    InvitationInput? input,
    InvitationStatus? status,
    bool? rsvpOpen,
  }) => Invitation(
    id: i.id,
    eventId: i.eventId,
    templateCode: input?.templateCode ?? i.templateCode,
    title: input?.title ?? i.title,
    message: input == null ? i.message : input.message,
    hostNames: input == null ? i.hostNames : input.hostNames,
    eventDate: i.eventDate,
    startTime: i.startTime,
    venueName: i.venueName,
    venueAddress: i.venueAddress,
    status: status ?? i.status,
    rsvpOpen: rsvpOpen ?? i.rsvpOpen,
    rsvpClosesOn: i.rsvpClosesOn,
    totals: replies[i.eventId]?.totals ?? i.totals,
  );

  /// Seeds an invitation directly (no call recorded).
  Invitation seed(
    String eventId, {
    InvitationStatus status = InvitationStatus.draft,
    String? link,
    RsvpList? rsvps,
  }) {
    final date = eventDate ?? DateTime(2026, 12, 12);
    if (rsvps != null) replies[eventId] = rsvps;
    final inv = Invitation(
      id: 'inv-${++_seq}',
      eventId: eventId,
      templateCode: 'classic',
      title: 'Asha & Ravi',
      message: 'Join us',
      hostNames: 'The Kumars',
      eventDate: date,
      startTime: '18:30',
      venueName: 'Lotus Hall',
      venueAddress: null,
      status: status,
      rsvpOpen: true,
      rsvpClosesOn: date.add(const Duration(days: 1)),
      totals: rsvps?.totals ?? RsvpTotals.zero,
    );
    invitations[eventId] = inv;
    if (link != null) links[inv.id] = link;
    return inv;
  }

  @override
  Future<Result<List<InvitationTemplate>>> templates() async =>
      const Ok(testTemplates);

  @override
  Future<Result<Invitation?>> get(String eventId) async {
    calls.add('get:$eventId');
    return _failure() ?? Ok(invitations[eventId]);
  }

  @override
  Future<Result<Invitation>> save(String eventId, InvitationInput input) async {
    calls.add('save:${input.templateCode}:${input.title}');
    final f = _failure<Invitation>();
    if (f != null) return f;
    final existing = invitations[eventId] ?? seed(eventId);
    return Ok(invitations[eventId] = _copy(existing, input: input));
  }

  PublishedInvitation _issue(String eventId) {
    final inv = invitations[eventId] = _copy(
      invitations[eventId]!,
      status: InvitationStatus.published,
    );
    final link = 'http://localhost:3000/api/v1/i/token-${++_seq}';
    links[inv.id] = link;
    return PublishedInvitation(invitation: inv, link: link);
  }

  @override
  Future<Result<PublishedInvitation>> publish(String eventId) async {
    calls.add('publish');
    return _failure() ?? Ok(_issue(eventId));
  }

  @override
  Future<Result<PublishedInvitation>> newLink(String eventId) async {
    calls.add('newLink');
    return _failure() ?? Ok(_issue(eventId));
  }

  @override
  Future<Result<Invitation>> setRsvpOpen(String eventId, bool open) async {
    calls.add('rsvpOpen:$open');
    final f = _failure<Invitation>();
    if (f != null) return f;
    return Ok(
      invitations[eventId] = _copy(invitations[eventId]!, rsvpOpen: open),
    );
  }

  @override
  Future<Result<Invitation>> revoke(String eventId) async {
    calls.add('revoke');
    final f = _failure<Invitation>();
    if (f != null) return f;
    final inv = invitations[eventId] = _copy(
      invitations[eventId]!,
      status: InvitationStatus.revoked,
    );
    links.remove(inv.id);
    return Ok(inv);
  }

  @override
  Future<Result<RsvpList>> rsvps(String eventId) async {
    calls.add('rsvps');
    return _failure() ??
        Ok(
          replies[eventId] ??
              const RsvpList(totals: RsvpTotals.zero, rsvps: []),
        );
  }

  @override
  Future<String?> savedLink(String invitationId) async => links[invitationId];

  @override
  Future<void> saveLink(String invitationId, String link) async =>
      links[invitationId] = link;
}
