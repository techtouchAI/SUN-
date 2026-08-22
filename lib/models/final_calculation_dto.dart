import 'load_model.dart';
import 'system_result_model.dart';
import 'system_settings_model.dart';

class FinalCalculationDto {
  final String projectName;
  final DateTime generatedAt;
  final String appVersion;
  final String calculationVersion;
  final List<LoadModel> loads;
  final SystemSettingsModel settings;
  final SystemResultModel result;

  const FinalCalculationDto({
    required this.projectName,
    required this.generatedAt,
    required this.appVersion,
    required this.calculationVersion,
    required this.loads,
    required this.settings,
    required this.result,
  });
}
