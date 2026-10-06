import 'package:get/get.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/secure_store.dart';
import '../config/app_config.dart';

/// App-wide singletons (architecture/flutter.md §2). Feature controllers are
/// created per route by their own bindings.
class InitialBinding extends Bindings {
  InitialBinding(this.config);

  final AppConfig config;

  @override
  void dependencies() {
    Get.put<AppConfig>(config, permanent: true);
    Get.put<ApiClient>(ApiClient.create(config), permanent: true);
    Get.lazyPut<SecureStore>(EncryptedSecureStore.new, fenix: true);
  }
}
