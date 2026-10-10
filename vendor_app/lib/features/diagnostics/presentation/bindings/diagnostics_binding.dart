import 'package:get/get.dart';

import '../../../../app/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/health_remote_data_source.dart';
import '../../data/repositories/health_repository_impl.dart';
import '../../domain/repositories/health_repository.dart';
import '../controllers/diagnostics_controller.dart';

class DiagnosticsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HealthRepository>(
      () => HealthRepositoryImpl(HealthRemoteDataSource(Get.find<ApiClient>())),
    );
    Get.lazyPut(
      () => DiagnosticsController(
        Get.find<HealthRepository>(),
        Get.find<AppConfig>(),
      ),
    );
  }
}
