import 'package:get/get.dart';

import '../../../../app/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../diagnostics/data/datasources/health_remote_data_source.dart';
import '../../../diagnostics/data/repositories/health_repository_impl.dart';
import '../../../diagnostics/domain/repositories/health_repository.dart';
import '../controllers/vendor_home_controller.dart';

class VendorHomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HealthRepository>(
      () => HealthRepositoryImpl(HealthRemoteDataSource(Get.find<ApiClient>())),
      fenix: true,
    );
    Get.lazyPut(
      () => VendorHomeController(
        Get.find<HealthRepository>(),
        Get.find<AppConfig>(),
      ),
    );
  }
}
