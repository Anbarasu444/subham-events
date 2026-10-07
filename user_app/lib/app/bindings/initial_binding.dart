import 'package:get/get.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/session_service.dart';
import '../../core/crash/crash_reporter.dart';
import '../../core/network/api_client.dart';
import '../../core/network/interceptors/auth_interceptor.dart';
import '../../core/storage/secure_store.dart';
import '../../features/auth/data/auth_api.dart';
import '../config/app_config.dart';

/// App-wide singletons (architecture/flutter.md §2). Feature controllers are
/// created per route by their own bindings.
class InitialBinding extends Bindings {
  InitialBinding(this.config, {required this.auth, required this.reporter});

  final AppConfig config;
  final AuthService auth;
  final CrashReporter reporter;

  @override
  void dependencies() {
    Get.put<AppConfig>(config, permanent: true);
    Get.put<CrashReporter>(reporter, permanent: true);
    Get.put<AuthService>(auth, permanent: true);
    Get.lazyPut<SecureStore>(EncryptedSecureStore.new, fenix: true);

    final api = ApiClient.create(
      config,
      authInterceptor: AuthInterceptor(
        tokenProvider: ({bool forceRefresh = false}) =>
            auth.idToken(forceRefresh: forceRefresh),
        // Resolved lazily: SessionService itself depends on the API client.
        onSessionInvalid: (reason) =>
            Get.find<SessionService>().onSessionInvalid(reason),
      ),
    );
    Get.put<ApiClient>(api, permanent: true);
    Get.put<SessionService>(
      SessionService(
        auth: auth,
        api: AuthApi(api),
        store: Get.find<SecureStore>(),
        reporter: reporter,
      ),
      permanent: true,
    ).restore();
  }
}
