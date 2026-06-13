with open('lib/repositories/solar_calculation_repository.dart', 'r') as f:
    content = f.read()

content = content.replace('static const double gridVoltage = 220.0;', '')
content = content.replace('double _convertToWatts(LoadModel load)', 'double _convertToWatts(LoadModel load, double gridVoltage)')
content = content.replace('return load.powerValue * gridVoltage;', 'return load.powerValue * gridVoltage;')

content = content.replace('Map<String, double> calculateConsumptionDetails(List<LoadModel> loads, {double nightUsageFraction = 0.6}) {', 'Map<String, double> calculateConsumptionDetails(List<LoadModel> loads, double gridVoltage, {double nightUsageFraction = 0.6}) {')
content = content.replace('double watts = _convertToWatts(load);', 'double watts = _convertToWatts(load, gridVoltage);')

content = content.replace('Map<String, double> calculateInverterDetails(List<LoadModel> loads)', 'Map<String, double> calculateInverterDetails(List<LoadModel> loads, double gridVoltage)')

content = content.replace('  SystemResultModel calculateSystem(List<LoadModel> loads, {', '  SystemResultModel calculateSystem(List<LoadModel> loads, {\n    required double gridVoltage,')

content = content.replace('''      final consumptionDetails = calculateConsumptionDetails(loads);''', '''      final consumptionDetails = calculateConsumptionDetails(loads, gridVoltage);''')

content = content.replace('''      final inverterDetails = calculateInverterDetails(loads);''', '''      final inverterDetails = calculateInverterDetails(loads, gridVoltage);''')

with open('lib/repositories/solar_calculation_repository.dart', 'w') as f:
    f.write(content)
