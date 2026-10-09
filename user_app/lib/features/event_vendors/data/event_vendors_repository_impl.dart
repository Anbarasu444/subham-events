import '../../../core/error/result.dart';
import '../../../core/money/money.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/utils/date_format.dart';
import '../../explore/data/discovery_repository_impl.dart';
import '../../reviews/domain/review.dart';
import '../domain/event_vendor.dart';

/// Network-only (server-owned state). Every change calls [_onChanged] so
/// event screens refresh.
class EventVendorsRepositoryImpl implements EventVendorsRepository {
  EventVendorsRepositoryImpl(this._api, this._onChanged);

  final ApiClient _api;
  final void Function() _onChanged;

  String _path(String eventId) => '/events/$eventId/vendors';

  @override
  Future<Result<EventVendorList>> list(String eventId) async {
    final result = await _api.get(
      _path(eventId),
      decode: (json) {
        final map = json as Map<String, dynamic>;
        return EventVendorList(
          eventId: map['eventId'] as String,
          isEditable: map['isEditable'] as bool,
          vendors: (map['vendors'] as List<dynamic>)
              .map(vendorFromJson)
              .toList(growable: false),
        );
      },
    );
    return _data(result, notify: false);
  }

  @override
  Future<Result<EventVendor>> add(String eventId, String listingId) async =>
      _data(
        await _api.post(
          _path(eventId),
          body: {'listingId': listingId},
          decode: vendorFromJson,
        ),
      );

  @override
  Future<Result<EventVendor>> updateNotes(
    String eventId,
    EventVendor vendor,
    String? notes,
  ) async => _data(
    await _api.patch(
      '${_path(eventId)}/${vendor.id}',
      body: {'notes': notes, 'version': vendor.version},
      decode: vendorFromJson,
    ),
  );

  @override
  Future<Result<void>> remove(String eventId, String eventVendorId) async =>
      _data(
        await _api.delete('${_path(eventId)}/$eventVendorId', decode: (_) {}),
      );

  @override
  Future<Result<EventVendor>> enquire(
    String eventId,
    String eventVendorId,
    EnquiryInput input, {
    required String idempotencyKey,
  }) async => _data(
    await _api.post(
      '${_path(eventId)}/$eventVendorId/enquiries',
      body: {
        'message': input.message,
        'preferredDate': input.preferredDate == null
            ? null
            : formatApiDate(input.preferredDate!),
      },
      idempotencyKey: idempotencyKey,
      decode: vendorFromJson,
    ),
  );

  @override
  Future<Result<EventVendor>> closeEnquiry(
    String eventId,
    String eventVendorId,
    String enquiryId,
  ) async => _data(
    await _api.post(
      '${_path(eventId)}/$eventVendorId/enquiries/$enquiryId/close',
      decode: vendorFromJson,
    ),
  );

  @override
  Future<Result<EventVendor>> acceptQuotation(
    String eventId,
    String eventVendorId,
    String quotationId, {
    required String idempotencyKey,
  }) async => _data(
    await _api.post(
      '${_path(eventId)}/$eventVendorId/quotations/$quotationId/accept',
      idempotencyKey: idempotencyKey,
      decode: vendorFromJson,
    ),
  );

  @override
  Future<Result<EventVendor>> rejectQuotation(
    String eventId,
    String eventVendorId,
    String quotationId,
  ) async => _data(
    await _api.post(
      '${_path(eventId)}/$eventVendorId/quotations/$quotationId/reject',
      decode: vendorFromJson,
    ),
  );

  @override
  Future<Result<EventVendor>> cancelBooking(
    String eventId,
    String eventVendorId,
    String reason,
  ) async => _data(
    await _api.post(
      '${_path(eventId)}/$eventVendorId/booking/cancel',
      body: {'reason': reason},
      decode: vendorFromJson,
    ),
  );

  @override
  Future<Result<EventVendor>> completeBooking(
    String eventId,
    String eventVendorId,
  ) async => _data(
    await _api.post(
      '${_path(eventId)}/$eventVendorId/booking/complete',
      decode: vendorFromJson,
    ),
  );

  Result<T> _data<T>(Result<ApiResponse<T>> result, {bool notify = true}) {
    switch (result) {
      case Ok(:final value):
        if (notify) _onChanged();
        return Ok(value.data);
      case Err(:final failure):
        return Err(failure);
    }
  }

  static EventVendor vendorFromJson(Object? json) {
    final map = json as Map<String, dynamic>;
    return EventVendor(
      id: map['id'] as String,
      status: EventVendorStatus.fromApi(map['status'] as String),
      notes: map['notes'] as String?,
      listing: DiscoveryRepositoryImpl.listingFromJson(
        map['listing'] as Map<String, dynamic>,
      ),
      isAvailable: map['isAvailable'] as bool,
      enquiries: (map['enquiries'] as List<dynamic>)
          .map((raw) {
            final e = raw as Map<String, dynamic>;
            final preferred = e['preferredDate'] as String?;
            return Enquiry(
              id: e['id'] as String,
              status: EnquiryStatus.fromApi(e['status'] as String),
              message: e['message'] as String,
              preferredDate: preferred == null ? null : parseApiDate(preferred),
              closedBy: e['closedBy'] as String?,
              createdAt: DateTime.parse(e['createdAt'] as String),
            );
          })
          .toList(growable: false),
      canEnquire: map['canEnquire'] as bool,
      version: map['version'] as int,
      quotations: ((map['quotations'] as List<dynamic>?) ?? const [])
          .map((raw) {
            final q = raw as Map<String, dynamic>;
            return Quotation(
              id: q['id'] as String,
              status: QuotationStatus.fromApi(q['status'] as String),
              amount: Money.fromJson(q['amount'] as Map<String, dynamic>),
              description: q['description'] as String?,
              validUntil: parseApiDate(q['validUntil'] as String),
              revisionNo: q['revisionNo'] as int,
            );
          })
          .toList(growable: false),
      booking: switch (map['booking']) {
        final Map<String, dynamic> b => Booking(
          id: b['id'] as String,
          status: BookingStatus.fromApi(b['status'] as String),
          agreedAmount: Money.fromJson(
            b['agreedAmount'] as Map<String, dynamic>,
          ),
          paid: b['paid'] == null
              ? null
              : Money.fromJson(b['paid'] as Map<String, dynamic>),
          serviceDate: parseApiDate(b['serviceDate'] as String),
          cancelledBy: b['cancelledBy'] as String?,
          cancelReason: b['cancelReason'] as String?,
          canCancel: b['canCancel'] as bool,
          canComplete: b['canComplete'] as bool,
          review: switch (b['review']) {
            final Map<String, dynamic> r => BookingReview(
              rating: r['rating'] as int,
              commentStatus: CommentStatus.fromApi(
                r['commentStatus'] as String,
              ),
            ),
            _ => null,
          },
          canReview: b['canReview'] as bool? ?? false,
        ),
        _ => null,
      },
    );
  }
}
