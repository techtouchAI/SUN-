class AppStrings {
  static const String appTitle = 'حاسبة الطاقة الشمسية';

  // Load Input Screen
  static const String addElectricalLoads = 'إضافة الأحمال الكهربائية';
  static const String deviceName = 'اسم الجهاز';
  static const String pleaseEnterName = 'الرجاء إدخال اسم الجهاز';
  static const String powerCapacity = 'القدرة/الاستهلاك';
  static const String enterValue = 'أدخل القيمة';
  static const String dailyUsageHours = 'الاستهلاك اليومي (ساعات)';
  static const String enterHours = 'أدخل الساعات';
  static const String isInverterAC = 'هل المكيف إنفرتر؟';
  static const String addLoadButton = 'إضافة الحمل';
  static const String noLoadsAddedYet = 'لم تتم إضافة أي أحمال بعد.';
  static const String hrsDay = 'ساعات/يوم';

  // Unit localized names
  static const String unitAmpere = 'Ampere (أمبير)';
  static const String unitWatt = 'Watt (واط)';
  static const String unitTon = 'Ton (طن)';

  // Tab Navigation & Quick Input & Grid
  static const String tabDetailedInput = 'إدخال مفصل';
  static const String tabQuickInput = 'إدخال سريع';
  static const String quickLoadTitle = 'حمل كلي مجمع';
  static const String gridSettingsTitle = 'إعدادات شبكة الكهرباء الوطنية';
  static const String gridOnHours = 'ساعات التوفر';
  static const String gridOffHours = 'ساعات الانقطاع';
  static const String offGridMode = 'غير متوفرة نهائياً (Off-Grid)';
  static const String editLoad = 'تعديل الحمل';
  static const String saveChanges = 'حفظ التعديلات';
  static const String save = 'حفظ التعديلات';
  static const String cancel = 'إلغاء';
  static const String batteryType = 'نوع البطارية';
  static const String batteryLithium = 'ليثيوم نسبة تفريغ 80%';
  static const String batteryGel = 'جل/رصاص نسبة تفريغ 50%';

  // Dashboard Screen
  static const String systemDashboard = 'لوحة تحكم النظام';
  static const String noLoadDataAvailable =
      'لا تتوفر بيانات أحمال. الرجاء إضافة الأحمال.';
  static const String totalConsumption = 'الاستهلاك الإجمالي';
  static const String requiredInverter = 'الإنفرتر المطلوب';
  static const String batteryBank = 'بنك البطاريات';
  static const String solarPanels = 'الألواح الشمسية';
  static const String panelsUnit = 'ألواح';
  static const String panelCapacityWatts = 'قدرة اللوح الشمسي (واط)';
  static const String panelIsc = 'تيار القصر للوح (Isc) أمبير';
  static const String daytimeOnlyMode = 'تشغيل نهاري بدون بطاريات';
  static const String upsMode = 'بطاريات + وطنية بدون ألواح';
  static const String gridAndBatterySettings =
      'إعدادات البطاريات والكهرباء الوطنية';
  static const String interactiveHint =
      '💡 ملاحظة: اضغط على أي عنصر لعرض التفاصيل والشروحات الهندسية.';

  // Settings Screen
  static const String settingsTitle = 'الإعدادات';
  static const String darkModeToggle = 'الوضع الليلي';
  static const String pricingSettingsTitle = 'إعدادات التسعير (السوق العراقي)';
  static const String solarWattPriceLabel = 'سعر الواط الشمسي (دولار)';
  static const String batteryAmperePriceLabel = 'سعر أمبير البطارية (دولار)';
  static const String breakerPriceLabel = 'سعر قاطع الدائرة "الجوزة" (دولار)';
  static const String wiringCostLabel =
      'التكلفة الإجمالية لأسلاك الربط (دولار)';

  // Pricing Result
  static const String estimatedSystemCost = 'التكلفة التقديرية للمنظومة';
  static const String costInUsd = 'دولار';
  static const String costInWarqa = 'ورقة';
  static const String costInIqd = 'دينار عراقي';
  static const String pricingDisclaimer =
      'ملاحظة: هذا السعر تقريبي مبني على إعداداتك. لم يتم حساب أسعار الجوزات وأسلاك الربط إلا إذا قمت بإضافتها يدوياً من شاشة الإعدادات، لكونها متغيرة حسب النوع والطول.';
  static const String isOffGridSystem = 'نظام بدون تيار وطني';

  // Explanations
  static const String batteryExplanationTitle = 'تفاصيل البطاريات';
  static const String batteryExplanationBody =
      'تم حساب هذه السعة بناءً على الاستهلاك الليلي، مع أخذ نسبة تفريغ آمنة للحفاظ على عمر البطاريات لتغطية فترات غياب الشمس.';
  static const String panelsExplanationTitle = 'تفاصيل الألواح الشمسية';
  static const String consumptionExplanationTitle = 'تفاصيل الاستهلاك';
  static const String inverterExplanationTitle = 'تفاصيل الإنفرتر';
  static const String safetyMargin = 'هامش الأمان';
  static const String peakLoad = 'الحمل الأقصى اللحظي';
  static const String daytimeConsumption = 'الاستهلاك النهاري';
  static const String nighttimeConsumption = 'الاستهلاك الليلي';
  static const String panelsDaytime = 'ألواح للتشغيل المباشر';
  static const String panelsBattery = 'ألواح لشحن البطاريات';

  // Energy Loss & Brands
  static const String recommendedInverterBrands =
      'الماركات العالمية الموصى بها للعواكس: Deye, Growatt, Huawei, Victron Energy';
  static const String recommendedPanelBrands =
      'المصنعين من فئة (Tier 1) المعتمدة للألواح: Longi, Jinko Solar, JA Solar, Trina Solar';
  static const String energyLossTitle = 'نسبة ضياع الطاقة المتوقعة';
  static const String energyLossExplanationTitle = 'تفاصيل ضياع الطاقة';
  static const String energyLossTemp =
      'عامل الحرارة (Temperature Coefficient): انخفاض كفاءة الخلايا الشمسية عند ارتفاع درجات حرارة الألواح فوق 25 درجة مئوية (وهو عامل حاسم في الصيف).';
  static const String energyLossInverter =
      'كفاءة التحويل (Inverter Efficiency): الفقد الطبيعي أثناء تحويل التيار المستمر (DC) من الألواح إلى تيار متردد (AC) للمنزل (بنسبة تفقد حوالي 3% إلى 5%).';
  static const String energyLossWiring =
      'مقاومة الأسلاك (Wiring/DC Losses): الضياع الناتجة عن المقاومة الكهربائية في الكابلات المسؤولة عن نقل الطاقة من الألواح إلى العاكس ومن العاكس إلى البطاريات.';
  static const String energyLossSoiling =
      'الغبار والأوساخ (Soiling Losses): انخفاض امتصاص الضوء بسبب تراكم الأتربة على سطح الألواح.';

  static const String safetyStandardsTitle = 'معايير السلامة العالمية (NEC)';
  static const String pvBreaker = 'جوزات الألواح (DC Breakers)';
  static const String batteryBreaker = 'جوزات البطاريات (DC Breakers)';
  static const String acBreaker = 'جوزات التيار المتردد (AC Breakers)';
  static const String dcWireSize = 'أحجام الأسلاك (DC Wire Sizing)';
  static const String wireMm2 = 'mm²';

  // Chart Screen
  static const String dailyProductionCurve = 'منحنى الإنتاج اليومي';
  static const String noSolarProductionData =
      'لا توجد بيانات للإنتاج الشمسي. أضف أحمالاً أولاً.';
  static const String estimatedSolarProductionVsTime =
      'الإنتاج الشمسي المقدر عبر الزمن';
  static const String yAxisPowerWatts = 'المحور الصادي: القدرة (واط)';
  static const String dawn = 'الفجر';
  static const String morning = 'الصباح';
  static const String noon = 'الظهيرة';
  static const String afternoon = 'العصر';
  static const String evening = 'المساء';
}
