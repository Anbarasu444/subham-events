import 'package:get/get.dart';
import 'package:user_app/core/auth/session_service.dart';
import 'package:user_app/core/error/failure.dart';
import 'package:user_app/core/error/result.dart';
import 'package:user_app/core/money/money.dart';
import 'package:user_app/features/event_vendors/domain/event_vendor.dart';
import 'package:user_app/features/explore/domain/listing.dart';
import 'package:user_app/features/reminders/domain/reminder.dart';
import 'package:user_app/features/wishlist/domain/wishlist.dart';

import 'fake_reminders.dart';
import 'package:user_app/features/wishlist/presentation/controllers/wishlist_controller.dart';

/// In-memory event vendors following the server rules (enough for widgets).
class FakeEventVendorsRepository implements EventVendorsRepository {
  FakeEventVendorsRepository({
    this.listings = const [],
    this.readOnlyEvents = const {},
    this.onChanged,
  });

  final List<ListingCard> listings;
  final Set<String> readOnlyEvents;
  final void Function()? onChanged;
  final Map<String, List<EventVendor>> byEvent = {};
  final List<String> calls = [];
  final List<String> idempotencyKeys = [];
  Failure? failNext;
  int _seq = 0;

  Result<T>? _failure<T>() {
    final f = failNext;
    failNext = null;
    return f == null ? null : Err(f);
  }

  EventVendor _with(
    EventVendor v, {
    EventVendorStatus? status,
    String? Function()? notes,
    List<Enquiry>? enquiries,
    List<Quotation>? quotations,
    Booking? Function()? booking,
    required bool editable,
  }) {
    final next = enquiries ?? v.enquiries;
    final s = status ?? v.status;
    final b = booking == null ? v.booking : booking();
    return EventVendor(
      id: v.id,
      status: s,
      notes: notes == null ? v.notes : notes(),
      listing: v.listing,
      isAvailable: v.isAvailable,
      enquiries: next,
      canEnquire:
          editable &&
          v.isAvailable &&
          (b == null || b.status == BookingStatus.cancelled) &&
          !next.any((e) => e.status.isLive),
      version: v.version + 1,
      quotations: quotations ?? v.quotations,
      booking: b,
    );
  }

  /// Plays the vendor (M33 later): sends a quote on the vendor's enquiry.
  Quotation sendQuote(
    String eventId,
    String eventVendorId,
    String amount, {
    bool expired = false,
    DateTime? validUntil,
  }) {
    final v = byEvent[eventId]!.firstWhere((e) => e.id == eventVendorId);
    final quote = Quotation(
      id: 'q-${++_seq}',
      status: expired ? QuotationStatus.expired : QuotationStatus.sent,
      amount: Money.parse(amount, 'INR'),
      description: 'Full day coverage',
      validUntil: validUntil ?? DateTime(2026, 12, 1),
      revisionNo: v.quotations.length + 1,
    );
    _replace(
      eventId,
      _with(
        v,
        status: EventVendorStatus.quoted,
        quotations: [quote, ...v.quotations],
        editable: true,
      ),
    );
    return quote;
  }

  Booking _booking(
    Booking? from, {
    required BookingStatus status,
    Money? amount,
    String? reason,
    bool canComplete = false,
  }) => Booking(
    id: from?.id ?? 'b-${++_seq}',
    status: status,
    agreedAmount: amount ?? from!.agreedAmount,
    paid: Money.parse('0.00', 'INR'),
    serviceDate: from?.serviceDate ?? DateTime(2026, 11, 7),
    cancelledBy: reason == null ? null : 'USER',
    cancelReason: reason,
    canCancel: status == BookingStatus.confirmed,
    canComplete: canComplete && status == BookingStatus.confirmed,
  );

  /// Lets the booking be marked completed (its service date has come).
  void serviceDateReached(String eventId, String eventVendorId) {
    final v = byEvent[eventId]!.firstWhere((e) => e.id == eventVendorId);
    _replace(
      eventId,
      _with(
        v,
        booking: () => _booking(
          v.booking,
          status: BookingStatus.confirmed,
          canComplete: true,
        ),
        editable: true,
      ),
    );
  }

  @override
  Future<Result<EventVendor>> acceptQuotation(
    String eventId,
    String eventVendorId,
    String quotationId, {
    required String idempotencyKey,
  }) async {
    calls.add('accept:$quotationId');
    idempotencyKeys.add(idempotencyKey);
    final f = _failure<EventVendor>();
    if (f != null) return f;
    final v = byEvent[eventId]!.firstWhere((e) => e.id == eventVendorId);
    final quote = v.quotations.firstWhere((q) => q.id == quotationId);
    final next = _with(
      v,
      status: EventVendorStatus.booked,
      quotations: [
        for (final q in v.quotations)
          q.id == quotationId
              ? Quotation(
                  id: q.id,
                  status: QuotationStatus.accepted,
                  amount: q.amount,
                  description: q.description,
                  validUntil: q.validUntil,
                  revisionNo: q.revisionNo,
                )
              : q,
      ],
      booking: () =>
          _booking(null, status: BookingStatus.confirmed, amount: quote.amount),
      editable: true,
    );
    _replace(eventId, next);
    onChanged?.call();
    return Ok(next);
  }

  @override
  Future<Result<EventVendor>> rejectQuotation(
    String eventId,
    String eventVendorId,
    String quotationId,
  ) async {
    calls.add('reject:$quotationId');
    final v = byEvent[eventId]!.firstWhere((e) => e.id == eventVendorId);
    final next = _with(
      v,
      status: EventVendorStatus.enquired,
      quotations: [
        for (final q in v.quotations)
          q.id == quotationId
              ? Quotation(
                  id: q.id,
                  status: QuotationStatus.rejected,
                  amount: q.amount,
                  description: q.description,
                  validUntil: q.validUntil,
                  revisionNo: q.revisionNo,
                )
              : q,
      ],
      editable: true,
    );
    _replace(eventId, next);
    onChanged?.call();
    return Ok(next);
  }

  @override
  Future<Result<EventVendor>> cancelBooking(
    String eventId,
    String eventVendorId,
    String reason,
  ) async {
    calls.add('cancelBooking:$eventVendorId:$reason');
    final v = byEvent[eventId]!.firstWhere((e) => e.id == eventVendorId);
    final next = _with(
      v,
      status: EventVendorStatus.cancelled,
      booking: () =>
          _booking(v.booking, status: BookingStatus.cancelled, reason: reason),
      editable: true,
    );
    _replace(eventId, next);
    onChanged?.call();
    return Ok(next);
  }

  @override
  Future<Result<EventVendor>> completeBooking(
    String eventId,
    String eventVendorId,
  ) async {
    calls.add('complete:$eventVendorId');
    final v = byEvent[eventId]!.firstWhere((e) => e.id == eventVendorId);
    final next = _with(
      v,
      status: EventVendorStatus.completed,
      booking: () => _booking(v.booking, status: BookingStatus.completed),
      editable: true,
    );
    _replace(eventId, next);
    onChanged?.call();
    return Ok(next);
  }

  void _replace(String eventId, EventVendor v) {
    final list = byEvent[eventId]!;
    list[list.indexWhere((e) => e.id == v.id)] = v;
  }

  EventVendor seed(String eventId, ListingCard listing) {
    final v = EventVendor(
      id: 'ev-${++_seq}',
      status: EventVendorStatus.added,
      notes: null,
      listing: listing,
      isAvailable: true,
      enquiries: const [],
      canEnquire: !readOnlyEvents.contains(eventId),
      version: 1,
    );
    (byEvent[eventId] ??= []).add(v);
    return v;
  }

  @override
  Future<Result<EventVendorList>> list(String eventId) async {
    calls.add('list:$eventId');
    return _failure() ??
        Ok(
          EventVendorList(
            eventId: eventId,
            isEditable: !readOnlyEvents.contains(eventId),
            vendors: [...?byEvent[eventId]],
          ),
        );
  }

  @override
  Future<Result<EventVendor>> add(String eventId, String listingId) async {
    calls.add('add:$eventId:$listingId');
    final f = _failure<EventVendor>();
    if (f != null) return f;
    final existing = byEvent[eventId]?.where((v) => v.listing.id == listingId);
    if (existing != null && existing.isNotEmpty) return Ok(existing.first);
    final listing = listings.firstWhere((l) => l.id == listingId);
    final v = seed(eventId, listing);
    onChanged?.call();
    return Ok(v);
  }

  @override
  Future<Result<EventVendor>> updateNotes(
    String eventId,
    EventVendor vendor,
    String? notes,
  ) async {
    calls.add('notes:${vendor.id}:$notes');
    final f = _failure<EventVendor>();
    if (f != null) return f;
    final next = _with(vendor, notes: () => notes, editable: true);
    _replace(eventId, next);
    onChanged?.call();
    return Ok(next);
  }

  @override
  Future<Result<void>> remove(String eventId, String eventVendorId) async {
    calls.add('remove:$eventVendorId');
    final f = _failure<void>();
    if (f != null) return f;
    byEvent[eventId]?.removeWhere((v) => v.id == eventVendorId);
    onChanged?.call();
    return const Ok(null);
  }

  @override
  Future<Result<EventVendor>> enquire(
    String eventId,
    String eventVendorId,
    EnquiryInput input, {
    required String idempotencyKey,
  }) async {
    calls.add('enquire:$eventVendorId');
    idempotencyKeys.add(idempotencyKey);
    final f = _failure<EventVendor>();
    if (f != null) return f;
    final v = byEvent[eventId]!.firstWhere((e) => e.id == eventVendorId);
    final next = _with(
      v,
      status: EventVendorStatus.enquired,
      enquiries: [
        Enquiry(
          id: 'enq-${++_seq}',
          status: EnquiryStatus.open,
          message: input.message,
          preferredDate: input.preferredDate,
          closedBy: null,
          createdAt: DateTime.utc(2026, 10, 8),
        ),
        ...v.enquiries,
      ],
      editable: true,
    );
    _replace(eventId, next);
    onChanged?.call();
    return Ok(next);
  }

  @override
  Future<Result<EventVendor>> closeEnquiry(
    String eventId,
    String eventVendorId,
    String enquiryId,
  ) async {
    calls.add('close:$enquiryId');
    final f = _failure<EventVendor>();
    if (f != null) return f;
    final v = byEvent[eventId]!.firstWhere((e) => e.id == eventVendorId);
    final next = _with(
      v,
      status: EventVendorStatus.added,
      enquiries: [
        for (final e in v.enquiries)
          e.id == enquiryId
              ? Enquiry(
                  id: e.id,
                  status: EnquiryStatus.closed,
                  message: e.message,
                  preferredDate: e.preferredDate,
                  closedBy: 'USER',
                  createdAt: e.createdAt,
                )
              : e,
      ],
      editable: true,
    );
    _replace(eventId, next);
    onChanged?.call();
    return Ok(next);
  }
}

class FakeWishlistRepository implements WishlistRepository {
  FakeWishlistRepository({this.listings = const []});

  final List<ListingCard> listings;
  final List<String> saved = [];
  final List<String> calls = [];
  Failure? failNext;

  @override
  Future<Result<Set<String>>> ids() async => Ok(saved.toSet());

  @override
  Future<Result<WishlistPage>> list({String? cursor, int limit = 20}) async =>
      Ok(
        WishlistPage(
          items: [
            for (final id in saved.reversed)
              WishlistItem(
                listing: listings.firstWhere((l) => l.id == id),
                isAvailable: true,
                savedAt: DateTime.utc(2026, 10, 8),
              ),
          ],
          nextCursor: null,
        ),
      );

  @override
  Future<Result<void>> save(String listingId) async {
    calls.add('save:$listingId');
    final f = failNext;
    failNext = null;
    if (f != null) return Err(f);
    if (!saved.contains(listingId)) saved.add(listingId);
    return const Ok(null);
  }

  @override
  Future<Result<void>> remove(String listingId) async {
    calls.add('remove:$listingId');
    saved.remove(listingId);
    return const Ok(null);
  }
}

/// Registers wishlist and event-vendor fakes (needs SessionService).
({FakeWishlistRepository wishlist, FakeEventVendorsRepository vendors})
registerEngagement({
  List<ListingCard> listings = const [],
  Set<String> readOnlyEvents = const {},
  void Function()? onChanged,
}) {
  final wishlist =
      Get.put<WishlistRepository>(FakeWishlistRepository(listings: listings))
          as FakeWishlistRepository;
  Get.put(WishlistController(wishlist, Get.find<SessionService>()));
  final vendors =
      Get.put<EventVendorsRepository>(
            FakeEventVendorsRepository(
              listings: listings,
              readOnlyEvents: readOnlyEvents,
              onChanged: onChanged,
            ),
          )
          as FakeEventVendorsRepository;
  if (!Get.isRegistered<RemindersRepository>()) {
    Get.put<RemindersRepository>(
      FakeRemindersRepository(readOnlyEvents: readOnlyEvents),
    );
  }
  return (wishlist: wishlist, vendors: vendors);
}
