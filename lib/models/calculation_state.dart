import '../core/errors/app_exceptions.dart';
import 'system_result_model.dart';

sealed class CalculationState {
  const CalculationState();
}

class CalculationNoLoads extends CalculationState {
  const CalculationNoLoads();
}

class CalculationInvalidInput extends CalculationState {
  final AppException error;
  const CalculationInvalidInput(this.error);
}

class CalculationFailed extends CalculationState {
  final Object error;
  const CalculationFailed(this.error);
}

class CalculationReady extends CalculationState {
  final SystemResultModel result;
  const CalculationReady(this.result);
}
