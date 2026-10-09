import '../../reviews/domain/review.dart';
import '../../../core/error/result.dart';
import '../../../core/money/money.dart';
import '../../explore/domain/listing.dart';

enum EventVendorStatus {
  added('Added'),
  enquired('Enquiry sent'),
  quoted('Quote waiting'),
  booked('Booked'),
  completed('Completed'),
  cancelled('Cancelled'),
  removed('Removed');

  const EventVendorStatus(this.label);
  final String label;

  static EventVendorStatus fromApi(String value) =>
      EventVendorStatus.values.byName(value.toLowerCase());
}

enum EnquiryStatus {
  open('Sent'),
  quoted('Quoted'),
  declined('Declined'),
  closed('Closed');

  const EnquiryStatus(this.label);
  final String label;

  bool get isLive => this == open || this == quoted;

  static EnquiryStatus fromApi(String value) =>
      EnquiryStatus.values.byName(value.toLowerCase());
}

enum QuotationStatus {
  sent('Waiting for you'),
  expired('Expired'),
  accepted('Accepted'),
  rejected('Declined'),
  superseded('Replaced by a newer quote'),
  withdrawn('Withdrawn by the vendor');

  const QuotationStatus(this.label);
  final String label;

  static QuotationStatus fromApi(String value) =>
      QuotationStatus.values.byName(value.toLowerCase());
}

/// A vendor's price offer (M15, R3). EXPIRED comes from the server.
class Quotation {
  const Quotation({
    required this.id,
    required this.status,
    required this.amount,
    required this.description,
    required this.validUntil,
    required this.revisionNo,
  });

  final String id;
  final QuotationStatus status;
  final Money amount;
  final String? description;

  /// Last day it can be accepted.
  final DateTime validUntil;
  final int revisionNo;
}

enum BookingStatus {
  confirmed('Booked'),
  cancelled('Cancelled'),
  completed('Completed');

  const BookingStatus(this.label);
  final String label;

  static BookingStatus fromApi(String value) =>
      BookingStatus.values.byName(value.toLowerCase());
}

/// A confirmed engagement (M15, A7). [agreedAmount] comes from the accepted
/// quote and never changes.
class Booking {
  const Booking({
    required this.id,
    required this.status,
    required this.agreedAmount,
    this.paid,
    required this.serviceDate,
    required this.cancelledBy,
    required this.cancelReason,
    required this.canCancel,
    required this.canComplete,
    this.review,
    this.canReview = false,
  });

  final String id;
  final BookingStatus status;
  final Money agreedAmount;

  /// Sum of the user's payment notes (M16); null in older responses.
  final Money? paid;
  final DateTime serviceDate;
  final String? cancelledBy;
  final String? cancelReason;
  final bool canCancel;
  final bool canComplete;

  /// The user's review of this booking (M20), if sent.
  final BookingReview? review;

  /// Completed, from the service date, not yet reviewed (A5, A12).
  final bool canReview;
}

class BookingReview {
  const BookingReview({required this.rating, required this.commentStatus});

  final int rating;
  final CommentStatus commentStatus;
}

class Enquiry {
  const Enquiry({
    required this.id,
    required this.status,
    required this.message,
    required this.preferredDate,
    required this.closedBy,
    required this.createdAt,
  });

  final String id;
  final EnquiryStatus status;
  final String message;
  final DateTime? preferredDate;

  /// USER, VENDOR or SYSTEM when closed.
  final String? closedBy;
  final DateTime createdAt;
}

/// A listing engaged for an event (M14). No amounts: agreed amounts come
/// with bookings (M15).
class EventVendor {
  const EventVendor({
    required this.id,
    required this.status,
    required this.notes,
    required this.listing,
    required this.isAvailable,
    required this.enquiries,
    required this.canEnquire,
    required this.version,
    this.quotations = const [],
    this.booking,
  });

  final String id;
  final EventVendorStatus status;

  /// Private to the user (never shown to the vendor).
  final String? notes;
  final ListingCard listing;
  final bool isAvailable;

  /// Newest first.
  final List<Enquiry> enquiries;
  final bool canEnquire;
  final int version;

  /// Newest first (all revisions).
  final List<Quotation> quotations;

  /// The active booking, else the latest cancelled one.
  final Booking? booking;

  /// The latest quote, when it still matters (waiting or expired).
  Quotation? get openQuote {
    final latest = quotations.firstOrNull;
    return latest != null &&
            (latest.status == QuotationStatus.sent ||
                latest.status == QuotationStatus.expired)
        ? latest
        : null;
  }

  Enquiry? get liveEnquiry =>
      enquiries.where((e) => e.status.isLive).firstOrNull;
}

class EventVendorList {
  const EventVendorList({
    required this.eventId,
    required this.isEditable,
    required this.vendors,
  });

  final String eventId;
  final bool isEditable;
  final List<EventVendor> vendors;
}

class EnquiryInput {
  const EnquiryInput({required this.message, this.preferredDate});

  final String message;
  final DateTime? preferredDate;

  @override
  bool operator ==(Object other) =>
      other is EnquiryInput &&
      other.message == message &&
      other.preferredDate == preferredDate;

  @override
  int get hashCode => Object.hash(message, preferredDate);
}

/// An event's vendors and enquiries (api-contracts.md Part B, M14).
abstract class EventVendorsRepository {
  Future<Result<EventVendorList>> list(String eventId);

  /// Adding a listing already on the event returns the existing vendor.
  Future<Result<EventVendor>> add(String eventId, String listingId);
  Future<Result<EventVendor>> updateNotes(
    String eventId,
    EventVendor vendor,
    String? notes,
  );
  Future<Result<void>> remove(String eventId, String eventVendorId);
  Future<Result<EventVendor>> enquire(
    String eventId,
    String eventVendorId,
    EnquiryInput input, {
    required String idempotencyKey,
  });
  Future<Result<EventVendor>> closeEnquiry(
    String eventId,
    String eventVendorId,
    String enquiryId,
  );

  /// Books the vendor at the quoted amount (server copies it; M15).
  Future<Result<EventVendor>> acceptQuotation(
    String eventId,
    String eventVendorId,
    String quotationId, {
    required String idempotencyKey,
  });
  Future<Result<EventVendor>> rejectQuotation(
    String eventId,
    String eventVendorId,
    String quotationId,
  );
  Future<Result<EventVendor>> cancelBooking(
    String eventId,
    String eventVendorId,
    String reason,
  );
  Future<Result<EventVendor>> completeBooking(
    String eventId,
    String eventVendorId,
  );
}
