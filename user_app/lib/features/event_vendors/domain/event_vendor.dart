import '../../../core/error/result.dart';
import '../../explore/domain/listing.dart';

enum EventVendorStatus {
  added('Added'),
  enquired('Enquiry sent'),
  quoted('Quote received'),
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
}
