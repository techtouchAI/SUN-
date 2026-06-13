with open('lib/screens/dashboard_screen.dart', 'r') as f:
    content = f.read()

content = content.replace('''                      '${result.estimatedCostUsd.toStringAsFixed(2)} ${AppStrings.costInUsd}',
                      '${(result.estimatedCostUsd / 100).toStringAsFixed(2)} ${AppStrings.costInWarqa}',
                      '${(result.estimatedCostUsd * 1500).toStringAsFixed(0)} ${AppStrings.costInIqd}',
                      '\\n${AppStrings.pricingDisclaimer}',''', '''                      '${result.estimatedCostUsd.toStringAsFixed(2)} ${AppStrings.costInUsd}',
                      '${(result.estimatedCostUsd / 100).toStringAsFixed(2)} ${AppStrings.costInWarqa}',
                      '${(result.estimatedCostUsd * ref.watch(iqdExchangeRateProvider)).toStringAsFixed(0)} ${AppStrings.costInIqd}',
                      '\\n${AppStrings.pricingDisclaimer}',''')

content = content.replace('''  @override
  Widget build(BuildContext context, WidgetRef ref) {''', '''  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<String?>(systemErrorProvider, (previous, next) {
      if (next != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });''')

with open('lib/screens/dashboard_screen.dart', 'w') as f:
    f.write(content)
