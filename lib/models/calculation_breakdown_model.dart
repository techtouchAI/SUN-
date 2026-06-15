class CalculationBreakdownModel {
  final String daytimePanelsExplanationAr;
  final String daytimePanelsExplanationEn;
  final String batteryPanelsExplanationAr;
  final String batteryPanelsExplanationEn;
  final String inverterExplanationAr;
  final String inverterExplanationEn;
  final String batteryExplanationAr;
  final String batteryExplanationEn;
  final String floatPreservationRecommendationAr;
  final String mpptRecommendationAr;

  const CalculationBreakdownModel({
    required this.daytimePanelsExplanationAr,
    required this.daytimePanelsExplanationEn,
    required this.batteryPanelsExplanationAr,
    required this.batteryPanelsExplanationEn,
    required this.inverterExplanationAr,
    required this.inverterExplanationEn,
    required this.batteryExplanationAr,
    required this.batteryExplanationEn,
    this.floatPreservationRecommendationAr = '',
    this.mpptRecommendationAr = '',
  });

  factory CalculationBreakdownModel.empty() {
    return const CalculationBreakdownModel(
      daytimePanelsExplanationAr: '',
      daytimePanelsExplanationEn: '',
      batteryPanelsExplanationAr: '',
      batteryPanelsExplanationEn: '',
      inverterExplanationAr: '',
      inverterExplanationEn: '',
      batteryExplanationAr: '',
      batteryExplanationEn: '',
    );
  }
}
