import 'package:get/get.dart';

import '../../../../core/auth/session_service.dart';
import '../../../../core/crash/crash_reporter.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/platform/external_actions.dart';
import '../../../../core/platform/photo_picker.dart';
import '../../../media/data/imagekit_uploader.dart';
import '../../../media/data/media_remote_data_source.dart';
import '../../../media/data/media_repository_impl.dart';
import '../../../media/domain/media_repository.dart';
import '../../../budget/data/budget_repository_impl.dart';
import '../../../budget/domain/budget.dart';
import '../../../checklist/data/datasources/checklist_remote_data_source.dart';
import '../../../checklist/data/repositories/checklist_repository_impl.dart';
import '../../../checklist/domain/repositories/checklist_repository.dart';
import '../../../events/data/datasources/events_remote_data_source.dart';
import '../../../events/data/repositories/events_repository_impl.dart';
import '../../../events/domain/repositories/events_repository.dart';
import '../../../events/presentation/controllers/my_events_controller.dart';
import '../../../event_vendors/data/event_vendors_repository_impl.dart';
import '../../../event_vendors/data/payments_repository_impl.dart';
import '../../../event_vendors/domain/event_vendor.dart';
import '../../../event_vendors/domain/payment.dart';
import '../../../explore/data/discovery_repository_impl.dart';
import '../../../explore/domain/listing.dart';
import '../../../explore/presentation/controllers/explore_controller.dart';
import '../../../../app/config/app_config.dart';
import '../../../../core/storage/secure_store.dart';
import '../../../home/data/empty_section_source.dart';
import '../../../notifications/data/notifications_repository_impl.dart';
import '../../../notifications/data/push_messaging.dart';
import '../../../notifications/domain/app_notification.dart';
import '../../../notifications/presentation/controllers/push_service.dart';
import '../../../reminders/data/reminders_repository_impl.dart';
import '../../../reminders/domain/reminder.dart';
import '../../../wishlist/data/wishlist_repository_impl.dart';
import '../../../wishlist/domain/wishlist.dart';
import '../../../wishlist/presentation/controllers/wishlist_controller.dart';
import '../../../home/presentation/controllers/home_controller.dart';

import '../controllers/shell_controller.dart';
import '../controllers/shell_tab.dart';

class ShellBinding extends Bindings {
  @override
  void dependencies() {
    // Events (M8): shared by My Events and the Home dashboard.
    Get.lazyPut<EventsRepository>(
      () => EventsRepositoryImpl(EventsRemoteDataSource(Get.find<ApiClient>())),
      fenix: true,
    );
    // Event cover photos (M10): upload via ImageKit, device picker, and
    // hand-offs to Maps / the share sheet.
    Get.lazyPut<MediaRepository>(
      () => MediaRepositoryImpl(
        MediaRemoteDataSource(Get.find<ApiClient>()),
        ImageKitUploader(),
      ),
      fenix: true,
    );
    Get.lazyPut<PhotoPicker>(ImagePickerPhotoPicker.new, fenix: true);
    Get.lazyPut<ExternalActions>(
      () => const PlatformExternalActions(),
      fenix: true,
    );
    // Budget (M11): changes refresh Home and event screens.
    Get.lazyPut<BudgetRepository>(
      () => BudgetRepositoryImpl(
        Get.find<ApiClient>(),
        Get.find<EventsRepository>().notifyChanged,
      ),
      fenix: true,
    );
    // Checklist (M9): changes refresh event progress everywhere.
    Get.lazyPut<ChecklistRepository>(
      () => ChecklistRepositoryImpl(
        ChecklistRemoteDataSource(Get.find<ApiClient>()),
        Get.find<EventsRepository>().notifyChanged,
      ),
      fenix: true,
    );
    // Vendor discovery (M12): public reads; Explore keeps its filters for
    // the session so Home can open it with a preset.
    Get.lazyPut<DiscoveryRepository>(
      () => DiscoveryRepositoryImpl(Get.find<ApiClient>()),
      fenix: true,
    );
    Get.lazyPut(
      () => ExploreController(
        Get.find<DiscoveryRepository>(),
        Get.find<EventsRepository>(),
        Get.find<SessionService>(),
      ),
      fenix: true,
    );
    // Saved vendors and event vendors / enquiries (M14).
    Get.lazyPut<WishlistRepository>(
      () => WishlistRepositoryImpl(Get.find<ApiClient>()),
      fenix: true,
    );
    Get.lazyPut(
      () => WishlistController(
        Get.find<WishlistRepository>(),
        Get.find<SessionService>(),
      ),
      fenix: true,
    );
    Get.lazyPut<EventVendorsRepository>(
      () => EventVendorsRepositoryImpl(
        Get.find<ApiClient>(),
        Get.find<EventsRepository>().notifyChanged,
      ),
      fenix: true,
    );
    // Payment notes (M16): changes refresh budgets and event screens.
    Get.lazyPut<PaymentsRepository>(
      () => PaymentsRepositoryImpl(
        Get.find<ApiClient>(),
        Get.find<EventsRepository>().notifyChanged,
      ),
      fenix: true,
    );
    // Notification Center and phone pushes (M18).
    Get.lazyPut<NotificationsRepository>(
      () => NotificationsRepositoryImpl(Get.find<ApiClient>()),
      fenix: true,
    );
    Get.lazyPut<PushMessaging>(FirebasePushMessaging.new, fenix: true);
    Get.lazyPut(
      () => PushService(
        Get.find<NotificationsRepository>(),
        Get.find<PushMessaging>(),
        Get.find<SessionService>(),
        Get.find<SecureStore>(),
        appVersion: Get.find<AppConfig>().appVersion,
      ),
      fenix: true,
    );
    // Reminders (M17).
    Get.lazyPut<RemindersRepository>(
      () => RemindersRepositoryImpl(Get.find<ApiClient>()),
      fenix: true,
    );
    Get.lazyPut(
      () => MyEventsController(
        Get.find<EventsRepository>(),
        Get.find<SessionService>(),
      ),
    );
    // Home tab dashboard (M7); sections are filled by later milestones.
    Get.lazyPut(
      () => HomeController(
        Get.find<SessionService>(),
        buildDashboardSources(
          Get.find<EventsRepository>(),
          Get.find<ChecklistRepository>(),
          Get.find<BudgetRepository>(),
          Get.find<DiscoveryRepository>(),
        ),
        reporter: Get.find<CrashReporter>(),
      ),
    );
    Get.lazyPut(
      () =>
          ShellController(initialTab: ShellTab.fromName(Get.parameters['tab'])),
    );
  }
}
