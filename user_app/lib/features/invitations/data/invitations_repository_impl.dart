import 'dart:ui' show Color;

import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/storage/secure_store.dart';
import '../../../core/utils/date_format.dart';
import '../domain/invitation.dart';

class InvitationsRepositoryImpl implements InvitationsRepository {
  InvitationsRepositoryImpl(this._api, this._store);

  final ApiClient _api;
  final SecureStore _store;
  List<InvitationTemplate>? _templates;

  String _path(String eventId) => '/events/$eventId/invitation';

  @override
  Future<Result<List<InvitationTemplate>>> templates() async {
    final cached = _templates;
    if (cached != null) return Ok(cached);
    final result = await _api.get(
      '/invitation-templates',
      decode: (json) =>
          (json as List<dynamic>).map(templateFromJson).toList(growable: false),
    );
    return switch (result) {
      Ok(:final value) => Ok(_templates = value.data),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<Invitation?>> get(String eventId) async => _data(
    await _api.get(
      _path(eventId),
      decode: (json) {
        final raw = (json as Map<String, dynamic>)['invitation'];
        return raw == null ? null : fromJson(raw);
      },
    ),
  );

  @override
  Future<Result<Invitation>> save(
    String eventId,
    InvitationInput input,
  ) async => _data(
    await _api.put(
      _path(eventId),
      body: {
        'templateCode': input.templateCode,
        'title': input.title,
        'message': input.message,
        'hostNames': input.hostNames,
      },
      decode: fromJson,
    ),
  );

  @override
  Future<Result<PublishedInvitation>> publish(String eventId) async =>
      _published(
        await _api.post('${_path(eventId)}/publish', decode: _withLink),
      );

  @override
  Future<Result<PublishedInvitation>> newLink(String eventId) async =>
      _published(
        await _api.post('${_path(eventId)}/new-link', decode: _withLink),
      );

  @override
  Future<Result<Invitation>> setRsvpOpen(String eventId, bool open) async =>
      _data(
        await _api.post(
          '${_path(eventId)}/rsvp-open',
          body: {'open': open},
          decode: fromJson,
        ),
      );

  @override
  Future<Result<Invitation>> revoke(String eventId) async =>
      _data(await _api.post('${_path(eventId)}/revoke', decode: fromJson));

  @override
  Future<Result<RsvpList>> rsvps(String eventId) async => _data(
    await _api.get(
      '${_path(eventId)}/rsvps',
      decode: (json) {
        final map = json as Map<String, dynamic>;
        return RsvpList(
          totals: totalsFromJson(map['totals']),
          rsvps: (map['rsvps'] as List<dynamic>)
              .map((raw) {
                final r = raw as Map<String, dynamic>;
                return Rsvp(
                  id: r['id'] as String,
                  guestName: r['guestName'] as String,
                  response: RsvpResponse.fromApi(r['response'] as String),
                  guestCount: r['guestCount'] as int,
                  message: r['message'] as String?,
                  updatedAt: DateTime.parse(r['updatedAt'] as String).toLocal(),
                );
              })
              .toList(growable: false),
        );
      },
    ),
  );

  static String _key(String id) => 'invitation_link_$id';

  @override
  Future<String?> savedLink(String invitationId) =>
      _store.read(_key(invitationId));

  @override
  Future<void> saveLink(String invitationId, String link) =>
      _store.write(_key(invitationId), link);

  Future<Result<PublishedInvitation>> _published(
    Result<ApiResponse<PublishedInvitation>> result,
  ) async {
    final mapped = _data(result);
    if (mapped case Ok(:final value)) {
      await saveLink(value.invitation.id, value.link);
    }
    return mapped;
  }

  static PublishedInvitation _withLink(Object? json) {
    final map = json as Map<String, dynamic>;
    return PublishedInvitation(
      invitation: fromJson(map['invitation']),
      link: map['shareUrl'] as String,
    );
  }

  Result<T> _data<T>(Result<ApiResponse<T>> result) => switch (result) {
    Ok(:final value) => Ok(value.data),
    Err(:final failure) => Err(failure),
  };

  static Color _hex(Object? value) {
    final hex = (value as String).replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  static InvitationTemplate templateFromJson(Object? json) {
    final m = json as Map<String, dynamic>;
    return InvitationTemplate(
      code: m['code'] as String,
      name: m['name'] as String,
      background: _hex(m['background']),
      surface: _hex(m['surface']),
      text: _hex(m['text']),
      accent: _hex(m['accent']),
      headingFont: m['headingFont'] as String,
      ornament: m['ornament'] as String,
    );
  }

  static RsvpTotals totalsFromJson(Object? json) {
    final m = json as Map<String, dynamic>;
    return RsvpTotals(
      attending: m['attending'] as int,
      maybe: m['maybe'] as int,
      notAttending: m['notAttending'] as int,
      guests: m['guests'] as int,
    );
  }

  static Invitation fromJson(Object? json) {
    final m = json as Map<String, dynamic>;
    return Invitation(
      id: m['id'] as String,
      eventId: m['eventId'] as String,
      templateCode: m['templateCode'] as String,
      title: m['title'] as String,
      message: m['message'] as String?,
      hostNames: m['hostNames'] as String?,
      eventDate: parseApiDate(m['eventDate'] as String),
      startTime: m['startTime'] as String?,
      venueName: m['venueName'] as String?,
      venueAddress: m['venueAddress'] as String?,
      status: InvitationStatus.fromApi(m['status'] as String),
      rsvpOpen: m['rsvpOpen'] as bool,
      rsvpClosesOn: parseApiDate(m['rsvpClosesOn'] as String),
      totals: totalsFromJson(m['totals']),
    );
  }
}
