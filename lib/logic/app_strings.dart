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

  // Dashboard Screen
  static const String systemDashboard = 'لوحة تحكم النظام';
  static const String noLoadDataAvailable = 'لا تتوفر بيانات أحمال. الرجاء إضافة الأحمال.';
  static const String totalConsumption = 'الاستهلاك الإجمالي';
  static const String requiredInverter = 'الإنفرتر المطلوب';
  static const String batteryBank = 'بنك البطاريات';
  static const String solarPanels = 'الألواح الشمسية';
  static const String panelsUnit = 'ألواح';
  static const String panelCapacityWatts = 'قدرة اللوح الشمسي (واط)';
  static const String daytimeOnlyMode = 'تشغيل نهاري المباشر فقط (بدون بطاريات)';
  static const String gridAndBatterySettings = 'إعدادات البطاريات والكهرباء الوطنية';
  static const String isOffGridSystem = 'نظام بدون تيار وطني (Off-grid)';

  // Explanations
  static const String batteryExplanationTitle = 'تفاصيل البطاريات';
  static const String batteryExplanationBody = 'تم حساب هذه السعة بناءً على الاستهلاك الليلي، مع أخذ نسبة تفريغ آمنة (DoD 50%) للحفاظ على عمر البطاريات لتغطية فترات غياب الشمس.';
  static const String panelsExplanationTitle = 'تفاصيل الألواح الشمسية';
  static const String consumptionExplanationTitle = 'تفاصيل الاستهلاك';
  static const String inverterExplanationTitle = 'تفاصيل الإنفرتر';
  static const String safetyMargin = 'هامش الأمان';
  static const String peakLoad = 'الحمل الأقصى اللحظي';
  static const String daytimeConsumption = 'الاستهلاك النهاري';
  static const String nighttimeConsumption = 'الاستهلاك الليلي';
  static const String panelsDaytime = 'ألواح للتشغيل المباشر';
  static const String panelsBattery = 'ألواح لشحن البطاريات';

  // Chart Screen
  static const String dailyProductionCurve = 'منحنى الإنتاج اليومي';
  static const String noSolarProductionData = 'لا توجد بيانات للإنتاج الشمسي. أضف أحمالاً أولاً.';
  static const String estimatedSolarProductionVsTime = 'الإنتاج الشمسي المقدر عبر الزمن';
  static const String yAxisPowerWatts = 'المحور الصادي: القدرة (واط)';
  static const String dawn = 'الفجر';
  static const String morning = 'الصباح';
  static const String noon = 'الظهيرة';
  static const String afternoon = 'العصر';
  static const String evening = 'المساء';
}
