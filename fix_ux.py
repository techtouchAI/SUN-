with open('lib/screens/dashboard_screen.dart', 'r') as f:
    content = f.read()

content = content.replace('''      body: result.totalDailyConsumptionWh == 0 && result.requiredInverterCapacityW == 0
          ? const Center(
              child: Text(
                AppStrings.noLoadDataAvailable,
                style: TextStyle(fontSize: 18),
              ),
            )
          : Column(''', '''      body: loads.isEmpty
          ? const Center(
              child: Text(
                "الرجاء إضافة أحمال أولاً",
                style: TextStyle(fontSize: 18),
              ),
            )
          : SingleChildScrollView(
              child: Column(''')

with open('lib/screens/dashboard_screen.dart', 'w') as f:
    f.write(content)
