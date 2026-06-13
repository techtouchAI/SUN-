import re

with open('lib/screens/dashboard_screen.dart', 'r') as f:
    content = f.read()

# 1. DashboardScreen scrollable fix: Wrap Column in SingleChildScrollView. Make GridView unscrollable.
content = content.replace('''Column(
              children: [''', '''SingleChildScrollView(
              child: Column(
                children: [''')

content = content.replace('''GridView.count(
                      crossAxisCount: 2,''', '''GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,''')

content = content.replace('''                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 14, color: Colors.black87),
                          children: [
                            TextSpan(
                              text: "💡 ملاحظة هندسية حول تقليل الألواح:\\n",
                              style: GoogleFonts.amiri(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const TextSpan(
                              text: "يمكنك تقليل عدد الألواح المقترحة، ولكن تذكر أن الألواح هي المصدر الأساسي لتوفير الأمبير نهاراً. في حال كان إنتاج الألواح أقل من استهلاك الحمل، ستقوم المنظومة بتعويض العجز عن طريق سحب التيار من البطاريات نهاراً. هذا السحب المستمر سيمنع البطاريات من الوصول للامتلاء، ويزيد من دورات التفريغ (Cycle Life)، مما يقلل من عمرها الافتراضي.",
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        "شكل توضيحي للربط",
                        style: GoogleFonts.amiri(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/photoi.png',
                            fit: BoxFit.contain,
                            height: 200,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),''', '''                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        "شكل توضيحي للربط",
                        style: GoogleFonts.amiri(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/photoi.png',
                            fit: BoxFit.contain,
                            height: 200,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.image_not_supported, size: 100, color: Colors.grey),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ),''')

# 2. In DashboardScreen, move the Engineering Note into the _showExplanationModal specifically for Solar Panels.
content = content.replace(''''${AppStrings.panelsDaytime}: ${result.panelsForDaytime} لوح',
                        if (!isDaytimeOnly) '${AppStrings.panelsBattery}: ${result.panelsForBatteries} لوح',
                        if (result.gridContributionPercent > 0) 'بما أن الوطنية متوفرة، سيتم شحن البطاريات منها بنسبة ${result.gridContributionPercent.toStringAsFixed(0)}% مما يقلل الحاجة لألواح شحن إضافية.',
                        if (result.panelsSavedByGrid > 0) 'عدد الألواح التي تم توفيرها بسبب وجود الوطنية: ${result.panelsSavedByGrid} لوح',
                        'المجموع الكلي: ${result.requiredPanels} لوح',
                      ]),''', ''''${AppStrings.panelsDaytime}: ${result.panelsForDaytime} لوح',
                        if (!isDaytimeOnly) '${AppStrings.panelsBattery}: ${result.panelsForBatteries} لوح',
                        if (result.gridContributionPercent > 0) 'بما أن الوطنية متوفرة، سيتم شحن البطاريات منها بنسبة ${result.gridContributionPercent.toStringAsFixed(0)}% مما يقلل الحاجة لألواح شحن إضافية.',
                        if (result.panelsSavedByGrid > 0) 'عدد الألواح التي تم توفيرها بسبب وجود الوطنية: ${result.panelsSavedByGrid} لوح',
                        'المجموع الكلي: ${result.requiredPanels} لوح',
                        '\\n💡 ملاحظة هندسية حول تقليل الألواح:\\nيمكنك تقليل عدد الألواح المقترحة، ولكن تذكر أن الألواح هي المصدر الأساسي لتوفير الأمبير نهاراً. في حال كان إنتاج الألواح أقل من استهلاك الحمل، ستقوم المنظومة بتعويض العجز عن طريق سحب التيار من البطاريات نهاراً. هذا السحب المستمر سيمنع البطاريات من الوصول للامتلاء، ويزيد من دورات التفريغ (Cycle Life)، مما يقلل من عمرها الافتراضي.',
                      ]),''')

# UX Enhancements Step 2 & 3: Fix Result Cards FittedBox and empty state.
content = content.replace('''            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, color: color, fontWeight: FontWeight.bold),
              ),
            ),''', '''            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.bold),
            ),''')

content = content.replace('''final result = ref.watch(systemResultProvider);
    final isDaytimeOnly = ref.watch(isDaytimeOnlyProvider);

    return Scaffold(''', '''final result = ref.watch(systemResultProvider);
    final isDaytimeOnly = ref.watch(isDaytimeOnlyProvider);
    final loads = ref.watch(loadListProvider);

    return Scaffold(''')

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
