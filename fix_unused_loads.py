with open('lib/screens/dashboard_screen.dart', 'r') as f:
    content = f.read()

# remove the first loads assignment and keep the second one.
content = content.replace('''    final isDaytimeOnly = ref.watch(isDaytimeOnlyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.systemDashboard),''', '''    final isDaytimeOnly = ref.watch(isDaytimeOnlyProvider);
    final loads = ref.watch(loadListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.systemDashboard),''')

content = content.replace('''final result = ref.watch(systemResultProvider);
    final isDaytimeOnly = ref.watch(isDaytimeOnlyProvider);
    final loads = ref.watch(loadListProvider);

    return Scaffold(''','''final result = ref.watch(systemResultProvider);
    final isDaytimeOnly = ref.watch(isDaytimeOnlyProvider);

    return Scaffold(''')

with open('lib/screens/dashboard_screen.dart', 'w') as f:
    f.write(content)
