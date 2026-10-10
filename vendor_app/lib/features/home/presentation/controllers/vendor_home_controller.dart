import 'package:get/get.dart';

import '../../../../app/config/app_config.dart';
import '../../../../core/error/result.dart';
import '../../../../core/state/view_state.dart';
import '../../../diagnostics/domain/entities/backend_health.dart';
import '../../../diagnostics/domain/repositories/health_repository.dart';

/// Placeholder vendor home (M24): proves App → Dio → NestJS → PostgreSQL by
/// checking the backend once on open. Vendor features replace it from M25.
class VendorHomeController extends GetxController {
  VendorHomeController(this._health, this.config);

  final HealthRepository _health;
  final AppConfig config;

  final connection = Rx<ViewState<BackendHealth>>(const Loading());

  @override
  void onInit() {
    super.onInit();
    checkConnection();
  }

  Future<void> checkConnection() async {
    connection.value = const Loading();
    final result = await _health.checkReady();
    connection.value = switch (result) {
      Ok(:final value) => Content(value),
      Err(:final failure) => Failed(failure),
    };
  }
}
