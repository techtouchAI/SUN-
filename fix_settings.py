with open('lib/screens/settings_screen.dart', 'r') as f:
    content = f.read()

insert_string = '''
              const SizedBox(height: 16),
              _buildPriceInput(
                context: context,
                ref: ref,
                label: 'سعر الصرف (IQD)',
                provider: iqdExchangeRateProvider,
                suffix: ' IQD',
              ),
              const SizedBox(height: 16),
              _buildPriceInput(
                context: context,
                ref: ref,
                label: 'جهد الشبكة (V)',
                provider: gridVoltageProvider,
                suffix: ' V',
              ),'''

content = content.replace('''              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'المتغيرات الهندسية',''', insert_string + '''
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'المتغيرات الهندسية',''')

with open('lib/screens/settings_screen.dart', 'w') as f:
    f.write(content)
