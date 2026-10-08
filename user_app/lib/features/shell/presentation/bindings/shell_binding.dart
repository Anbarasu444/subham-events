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
import '../../../home/data/empty_section_source.dart';
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
