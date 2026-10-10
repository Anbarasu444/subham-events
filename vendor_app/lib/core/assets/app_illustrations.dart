/// ─────────────────────────────────────────────────────────────────────────
///  ALL ILLUSTRATIONS — ONE FILE (Subam Vendor, M24; same pattern as the
///  User App)
///
///  Every picture in the app is referenced only through these constants.
///  To replace a picture, put the new file in `assets/illustrations/` and
///  change its path here (any name, PNG/JPEG/WebP). A missing file shows a
///  coloured icon instead, so nothing breaks while pictures are supplied
///  (the user sends them later — list sent 2026-10-10).
/// ─────────────────────────────────────────────────────────────────────────
abstract final class AppIllustrations {
  static const _dir = 'assets/illustrations';

  // Home quick-action grid (256 × 256).
  static const menuListings = '$_dir/vmenu_listings.png';
  static const menuEnquiries = '$_dir/vmenu_enquiries.png';
  static const menuQuotations = '$_dir/vmenu_quotations.png';
  static const menuBookings = '$_dir/vmenu_bookings.png';
  static const menuPayments = '$_dir/vmenu_payments.png';
  static const menuReviews = '$_dir/vmenu_reviews.png';
  static const menuCalendar = '$_dir/vmenu_calendar.png';
  static const menuProfile = '$_dir/vmenu_profile.png';

  // Status and onboarding (600 × 600).
  static const onboardingWelcome = '$_dir/onboarding_welcome.png';
  static const listingPending = '$_dir/listing_pending.png';
  static const listingApproved = '$_dir/listing_approved.png';
  static const listingRejected = '$_dir/listing_rejected.png';
  static const paymentSuccess = '$_dir/payment_success.png';
  static const paymentFailed = '$_dir/payment_failed.png';

  // Empty screens (600 × 600).
  static const emptyListings = '$_dir/vempty_listings.png';
  static const emptyEnquiries = '$_dir/vempty_enquiries.png';
  static const emptyQuotations = '$_dir/vempty_quotations.png';
  static const emptyBookings = '$_dir/vempty_bookings.png';
  static const emptyPayments = '$_dir/vempty_payments.png';
  static const emptyReviews = '$_dir/vempty_reviews.png';
  static const emptyNotifications = '$_dir/vempty_notifications.png';

  // Other.
  static const signInSecure = '$_dir/vsignin_secure.png';
  static const avatarPlaceholder = '$_dir/vavatar_placeholder.png';
  static const vendorBanner = '$_dir/vendor_banner.png';
  static const appLogo = '$_dir/vendor_logo.png';
  static const errorOffline = '$_dir/verror_offline.png';

  /// Every path above (a test lists which files are still missing).
  static const all = [
    menuListings,
    menuEnquiries,
    menuQuotations,
    menuBookings,
    menuPayments,
    menuReviews,
    menuCalendar,
    menuProfile,
    onboardingWelcome,
    listingPending,
    listingApproved,
    listingRejected,
    paymentSuccess,
    paymentFailed,
    emptyListings,
    emptyEnquiries,
    emptyQuotations,
    emptyBookings,
    emptyPayments,
    emptyReviews,
    emptyNotifications,
    signInSecure,
    avatarPlaceholder,
    vendorBanner,
    appLogo,
    errorOffline,
  ];
}
