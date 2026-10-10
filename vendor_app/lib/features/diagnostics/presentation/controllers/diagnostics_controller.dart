import 'package:get/get.dart';

import '../../../../app/config/app_config.dart';
import '../../../../core/error/result.dart';
import '../../../../core/state/view_state.dart';
import '../../domain/entities/backend_health.dart';
import '../../domain/repositories/health_repository.dart';

/// Staging-only diagnostics: proves App → Dio → NestJS → PostgreSQL end to end.
class DiagnosticsController extends GetxController {
  DiagnosticsController(this._repository, this.config);

  final HealthRepository _repository;
  final AppConfig config;

  final state = Rx<ViewState<BackendHealth>>(const Loading());

  @override
  void onInit() {
    super.onInit();
    check();
  }

  Future<void> check() async {
    state.value = const Loading();
    final result = await _repository.checkReady();
    state.value = switch (result) {
      Ok(:final value) => Content(value),
      Err(:final failure) => Failed(failure),
    };
  }
}
