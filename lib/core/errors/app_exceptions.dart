class AppException implements Exception {
  final String code;
  final String message;
  final String? field;

  const AppException(this.code, this.message, {this.field});

  @override
  String toString() => message;
}

class InvalidEngineeringInput extends AppException {
  const InvalidEngineeringInput(String message, {super.field})
    : super('invalid_engineering_input', message);
}

class InvalidLoadInput extends AppException {
  const InvalidLoadInput(String message, {super.field})
    : super('invalid_load_input', message);
}

class CalculationFailure extends AppException {
  const CalculationFailure(String message)
    : super('calculation_failure', message);
}

class PersistenceFailure extends AppException {
  const PersistenceFailure(String message)
    : super('persistence_failure', message);
}

class UpdateFailure extends AppException {
  const UpdateFailure(String message) : super('update_failure', message);
}
