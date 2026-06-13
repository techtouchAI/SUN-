with open('lib/logic/providers.dart', 'r') as f:
    content = f.read()

insert_string = '''
// Providers for Grid Voltage and IQD
final gridVoltageProvider = StateProvider<double>((ref) => 220.0);
final iqdExchangeRateProvider = StateProvider<double>((ref) => 1500.0);

// System Error Provider
final systemErrorProvider = StateProvider<String?>((ref) => null);

// Derived provider for the calculation results'''

content = content.replace('// Derived provider for the calculation results', insert_string)

with open('lib/logic/providers.dart', 'w') as f:
    f.write(content)
