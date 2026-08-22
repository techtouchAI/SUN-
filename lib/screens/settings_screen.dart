import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/validation/input_parser.dart';
import '../logic/app_strings.dart';
import '../logic/providers.dart';
import '../repositories/solar_calculation_repository.dart';
import '../models/system_settings_model.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(systemSettingsProvider);
    final settingsError = ref.watch(systemSettingsErrorProvider);
    final notifier = ref.read(systemSettingsProvider.notifier);

    void update(SystemSettingsModel next) {
      try {
        notifier.update(next);
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (settingsError != null)
            Card(
              color: Colors.red.shade50,
              child: ListTile(
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: const Text('تعذر تحميل أو حفظ الإعدادات'),
                subtitle: Text(settingsError),
              ),
            ),
          SwitchListTile(
            title: const Text(AppStrings.darkModeToggle),
            value: ref.watch(themeModeProvider) == ThemeMode.dark,
            onChanged: (value) => ref.read(themeModeProvider.notifier).state =
                value ? ThemeMode.dark : ThemeMode.light,
          ),
          const Divider(),
          _sectionTitle('بيانات المشروع'),
          _textInput(
            context,
            label: 'اسم المشروع',
            value: settings.projectName,
            onChanged: (value) => update(settings.copyWith(projectName: value)),
            keyboard: TextInputType.text,
          ),
          _sectionTitle(AppStrings.pricingSettingsTitle),
          _numberInput(
            settings,
            'سعر الواط الشمسي (دولار)',
            settings.solarWattPrice,
            (value) => update(settings.copyWith(solarWattPrice: value)),
          ),
          _numberInput(
            settings,
            'سعر أمبير البطارية (دولار)',
            settings.batteryAmperePrice,
            (value) => update(settings.copyWith(batteryAmperePrice: value)),
          ),
          _numberInput(
            settings,
            'سعر القاطع (دولار)',
            settings.breakerPrice,
            (value) => update(settings.copyWith(breakerPrice: value)),
          ),
          _numberInput(
            settings,
            'تكلفة الأسلاك الإجمالية (دولار)',
            settings.wiringCost,
            (value) => update(settings.copyWith(wiringCost: value)),
          ),
          _numberInput(
            settings,
            'سعر الصرف (IQD)',
            settings.iqdExchangeRate,
            (value) => update(settings.copyWith(iqdExchangeRate: value)),
            suffix: ' IQD',
          ),
          _sectionTitle('المتغيرات الهندسية'),
          _numberInput(
            settings,
            'جهد الشبكة (V)',
            settings.gridVoltage,
            (value) => update(settings.copyWith(gridVoltage: value)),
            suffix: ' V',
          ),
          _numberInput(
            settings,
            'جهد النظام (V)',
            settings.systemVoltage,
            (value) => update(settings.copyWith(systemVoltage: value)),
            suffix: ' V',
          ),
          _numberInput(
            settings,
            'ساعات الذروة (PSH)',
            settings.peakSunHours,
            (value) => update(settings.copyWith(peakSunHours: value)),
            suffix: ' ساعات',
          ),
          _numberInput(
            settings,
            'نسبة الفقد (%)',
            settings.energyLossPercentage,
            (value) => update(settings.copyWith(energyLossPercentage: value)),
            suffix: ' %',
          ),
          _numberInput(
            settings,
            'أيام الاستقلالية',
            settings.daysOfAutonomy,
            (value) => update(settings.copyWith(daysOfAutonomy: value)),
            suffix: ' أيام',
          ),
          _sectionTitle('إعدادات الألواح'),
          _numberInput(
            settings,
            'قدرة اللوح (W)',
            settings.panelCapacity,
            (value) => update(
              settings.copyWith(
                panelCapacity: value,
                panelIsc: SolarCalculationRepository.getInterpolatedIsc(value),
              ),
            ),
            suffix: ' W',
          ),
          _numberInput(
            settings,
            'تيار القصر Isc (A)',
            settings.panelIsc,
            (value) => update(settings.copyWith(panelIsc: value)),
            suffix: ' A',
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('تصميم وبرمجة كنان الصائغ'),
            trailing: const Icon(Icons.telegram),
            onTap: () async {
              final url = Uri.parse('https://t.me/techtouch7');
              if (!await launchUrl(url, mode: LaunchMode.externalApplication) &&
                  context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تعذر فتح الرابط.')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 12),
    child: Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
  );

  Widget _textInput(
    BuildContext context, {
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    required TextInputType keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        key: ValueKey('$label-$value'),
        initialValue: value,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _numberInput(
    SystemSettingsModel settings,
    String label,
    double value,
    ValueChanged<double> onChanged, {
    String suffix = '',
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        key: ValueKey('$label-$value'),
        initialValue: value.toString(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          border: const OutlineInputBorder(),
        ),
        onChanged: (raw) {
          final parsed = InputParser.doubleOrNull(raw);
          if (parsed != null && parsed.isFinite) onChanged(parsed);
        },
      ),
    );
  }
}
