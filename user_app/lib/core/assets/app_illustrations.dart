/// ─────────────────────────────────────────────────────────────────────────
///  ALL ILLUSTRATIONS — ONE FILE (M22, user request 2026-10-09)
///
///  Every picture in the app is referenced only through these constants.
///  To replace a picture, put the new file in `assets/illustrations/` and
///  change its path here (any name, PNG/JPEG/WebP). A missing file shows a
///  coloured icon instead, so nothing breaks while pictures are swapped.
/// ─────────────────────────────────────────────────────────────────────────
abstract final class AppIllustrations {
  static const _dir = 'assets/illustrations';

  // Home quick-action grid.
  static const menuChecklist = '$_dir/menu_checklist.jpeg';
  static const menuBudget = '$_dir/menu_budget.jpeg';
  static const menuVendors = '$_dir/menu_vendor.png';
  static const menuSchedule = '$_dir/menu_schedule.png';
  static const menuEvents = '$_dir/menu_events.png';
  static const menuInvitation = '$_dir/menu_invitation.png';
  static const menuExplore = '$_dir/menu_explore.png';
  static const menuReviews = '$_dir/menu_reviews.png';

  /// Supplied for a future Messages feature (hidden until a chat milestone).
  static const menuMessages = '$_dir/message.jpeg';

  // Event pictures (used when an event has no cover photo).
  static const eventWedding = '$_dir/event_wedding.png';
  static const eventEngagement = '$_dir/event_engagement.png';
  static const eventBirthday = '$_dir/event_birthday.png';
  static const eventHousewarming = '$_dir/event_housewarming.png';
  static const eventBabyShower = '$_dir/event_baby_shower.png';
  static const eventCorporate = '$_dir/event_corporate.png';
  static const eventOther = '$_dir/event_other.png';

  // Empty screens.
  static const emptyEvents = '$_dir/empty_events.png';
  static const emptyChecklist = '$_dir/empty_checklist.png';
  static const emptyBudget = '$_dir/empty_budget.png';
  static const emptyVendors = '$_dir/empty_vendors.png';
  static const emptyNotifications = '$_dir/empty_notifications.png';
  static const emptyReviews = '$_dir/empty_reviews.png';
  static const emptyRsvps = '$_dir/empty_rsvps.png';
  static const emptySearch = '$_dir/empty_search.png';

  // Other.
  static const signInSecure = '$_dir/signin_secure.png';
  static const avatarPlaceholder = '$_dir/avatar_placeholder.png';
  static const invitationBanner = '$_dir/invitation_banner.png';
  static const appLogo = '$_dir/app_logo.png';
  static const errorOffline = '$_dir/error_offline.png';

  /// Picture for an event type (free text, so matched by keywords).
  static String forEventType(String eventType) {
    final t = eventType.toLowerCase();
    if (t.contains('wedding') || t.contains('marriage')) return eventWedding;
    if (t.contains('engage')) return eventEngagement;
    if (t.contains('birthday')) return eventBirthday;
    if (t.contains('house')) return eventHousewarming;
    if (t.contains('baby') || t.contains('shower')) return eventBabyShower;
    if (t.contains('corporate') || t.contains('office')) return eventCorporate;
    return eventOther;
  }

  /// Every path above (checked by a test so a typo is caught early).
  static const all = [
    menuChecklist,
    menuBudget,
    menuVendors,
    menuSchedule,
    menuEvents,
    menuInvitation,
    menuExplore,
    menuReviews,
    menuMessages,
    eventWedding,
    eventEngagement,
    eventBirthday,
    eventHousewarming,
    eventBabyShower,
    eventCorporate,
    eventOther,
    emptyEvents,
    emptyChecklist,
    emptyBudget,
    emptyVendors,
    emptyNotifications,
    emptyReviews,
    emptyRsvps,
    emptySearch,
    signInSecure,
    avatarPlaceholder,
    invitationBanner,
    appLogo,
    errorOffline,
  ];
}
