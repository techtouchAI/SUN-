enum SafetyCircuitType { pvDc, batteryDc, acOutput, groundingProtection }

extension SafetyCircuitTypeLabels on SafetyCircuitType {
  String get labelAr => switch (this) {
    SafetyCircuitType.pvDc => 'دارة الألواح الشمسية DC',
    SafetyCircuitType.batteryDc => 'دارة البطارية DC',
    SafetyCircuitType.acOutput => 'خرج العاكس AC',
    SafetyCircuitType.groundingProtection => 'التأريض والحماية',
  };
}

class SafetyDesignInput {
  final String value;
  final String source;

  const SafetyDesignInput({this.value = '', this.source = ''});

  bool get hasValue => value.trim().isNotEmpty;
  bool get hasSource => source.trim().isNotEmpty;
  bool get isDocumented => hasValue && hasSource;

  SafetyDesignInput copyWith({String? value, String? source}) {
    return SafetyDesignInput(
      value: value ?? this.value,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() => {'value': value, 'source': source};

  factory SafetyDesignInput.fromJson(Map<String, dynamic> json) {
    return SafetyDesignInput(
      value: _string(json['value']),
      source: _string(json['source']),
    );
  }
}

class SafetyInputDefinition {
  final String id;
  final String labelAr;
  final String sectionAr;
  final SafetyCircuitType? circuit;
  final bool requiredForAudit;

  const SafetyInputDefinition({
    required this.id,
    required this.labelAr,
    required this.sectionAr,
    this.circuit,
    this.requiredForAudit = true,
  });
}

/// Safety Engine v1 only stores design data and its provenance.
/// It intentionally contains no electrical code tables or recommendation values.
class SafetyDesignModel {
  final Map<String, SafetyDesignInput> inputs;

  const SafetyDesignModel({this.inputs = const {}});

  SafetyDesignInput inputFor(String id) =>
      inputs[id] ?? const SafetyDesignInput();

  SafetyDesignModel updateInput(String id, {String? value, String? source}) {
    final next = Map<String, SafetyDesignInput>.from(inputs);
    next[id] = inputFor(id).copyWith(value: value, source: source);
    return SafetyDesignModel(inputs: Map.unmodifiable(next));
  }

  Map<String, dynamic> toJson() => {
    'inputs': inputs.map((key, value) => MapEntry(key, value.toJson())),
  };

  factory SafetyDesignModel.fromJson(Map<String, dynamic> json) {
    final rawInputs = json['inputs'];
    if (rawInputs is! Map) return const SafetyDesignModel();
    final next = <String, SafetyDesignInput>{};
    for (final entry in rawInputs.entries) {
      if (entry.key is! String || entry.value is! Map) continue;
      next[entry.key as String] = SafetyDesignInput.fromJson(
        Map<String, dynamic>.from(entry.value as Map),
      );
    }
    return SafetyDesignModel(inputs: Map.unmodifiable(next));
  }

  static final List<SafetyInputDefinition> definitions = List.unmodifiable([
    const SafetyInputDefinition(
      id: 'context.country',
      labelAr: 'الدولة',
      sectionAr: 'سياق المشروع والقواعد',
      requiredForAudit: false,
    ),
    const SafetyInputDefinition(
      id: 'context.jurisdiction',
      labelAr: 'الاختصاص أو المدينة/المحافظة',
      sectionAr: 'سياق المشروع والقواعد',
      requiredForAudit: false,
    ),
    const SafetyInputDefinition(
      id: 'context.authority',
      labelAr: 'الجهة المراجعة أو السلطة المختصة',
      sectionAr: 'سياق المشروع والقواعد',
      requiredForAudit: false,
    ),
    const SafetyInputDefinition(
      id: 'rules.standard',
      labelAr: 'معيار التصميم المعتمد',
      sectionAr: 'سياق المشروع والقواعد',
      requiredForAudit: false,
    ),
    const SafetyInputDefinition(
      id: 'rules.edition',
      labelAr: 'إصدار المعيار',
      sectionAr: 'سياق المشروع والقواعد',
      requiredForAudit: false,
    ),
    const SafetyInputDefinition(
      id: 'rules.rulesetId',
      labelAr: 'معرّف ملف القواعد المعتمد',
      sectionAr: 'سياق المشروع والقواعد',
      requiredForAudit: false,
    ),
    const SafetyInputDefinition(
      id: 'rules.rulesetSource',
      labelAr: 'مصدر أو ترخيص ملف القواعد',
      sectionAr: 'سياق المشروع والقواعد',
      requiredForAudit: false,
    ),
    const SafetyInputDefinition(
      id: 'topology.dcAc',
      labelAr: 'وصف طوبولوجيا ومسارات DC/AC',
      sectionAr: 'طوبولوجيا الحماية',
    ),
    const SafetyInputDefinition(
      id: 'protection.existingDevices',
      labelAr: 'أجهزة الحماية والفصل الحالية أو المخططة',
      sectionAr: 'طوبولوجيا الحماية',
    ),
    const SafetyInputDefinition(
      id: 'equipment.pvModuleModel',
      labelAr: 'الشركة والموديل الدقيق للوح PV',
      sectionAr: 'بيانات معدات PV',
    ),
    const SafetyInputDefinition(
      id: 'pv.voc',
      labelAr: 'Voc للوح',
      sectionAr: 'بيانات معدات PV',
      circuit: SafetyCircuitType.pvDc,
    ),
    const SafetyInputDefinition(
      id: 'pv.vmp',
      labelAr: 'Vmp للوح',
      sectionAr: 'بيانات معدات PV',
      circuit: SafetyCircuitType.pvDc,
    ),
    const SafetyInputDefinition(
      id: 'pv.isc',
      labelAr: 'Isc للوح',
      sectionAr: 'بيانات معدات PV',
      circuit: SafetyCircuitType.pvDc,
    ),
    const SafetyInputDefinition(
      id: 'pv.imp',
      labelAr: 'Imp للوح',
      sectionAr: 'بيانات معدات PV',
      circuit: SafetyCircuitType.pvDc,
    ),
    const SafetyInputDefinition(
      id: 'pv.vocTemperatureCoefficient',
      labelAr: 'معامل درجة حرارة Voc',
      sectionAr: 'بيانات معدات PV',
      circuit: SafetyCircuitType.pvDc,
    ),
    const SafetyInputDefinition(
      id: 'pv.maxSeriesFuse',
      labelAr: 'الحد الأقصى لفيوز السلسلة في اللوح',
      sectionAr: 'بيانات معدات PV',
      circuit: SafetyCircuitType.pvDc,
    ),
    const SafetyInputDefinition(
      id: 'pv.maxSystemVoltage',
      labelAr: 'الحد الأقصى لجهد منظومة اللوح',
      sectionAr: 'بيانات معدات PV',
      circuit: SafetyCircuitType.pvDc,
    ),
    const SafetyInputDefinition(
      id: 'pv.modulesPerString',
      labelAr: 'عدد الألواح على التوالي في كل سلسلة',
      sectionAr: 'تكوين السلاسل وMPPT',
      circuit: SafetyCircuitType.pvDc,
    ),
    const SafetyInputDefinition(
      id: 'pv.parallelStrings',
      labelAr: 'عدد السلاسل المتوازية',
      sectionAr: 'تكوين السلاسل وMPPT',
      circuit: SafetyCircuitType.pvDc,
    ),
    const SafetyInputDefinition(
      id: 'equipment.inverterModel',
      labelAr: 'الشركة والموديل الدقيق للعاكس',
      sectionAr: 'بيانات العاكس',
    ),
    const SafetyInputDefinition(
      id: 'inverter.mpptCount',
      labelAr: 'عدد مداخل MPPT',
      sectionAr: 'تكوين السلاسل وMPPT',
      circuit: SafetyCircuitType.pvDc,
    ),
    const SafetyInputDefinition(
      id: 'inverter.mpptVoltageRange',
      labelAr: 'مدى جهد MPPT',
      sectionAr: 'تكوين السلاسل وMPPT',
      circuit: SafetyCircuitType.pvDc,
    ),
    const SafetyInputDefinition(
      id: 'inverter.maxPvVoltage',
      labelAr: 'أقصى جهد PV مسموح للعاكس',
      sectionAr: 'تكوين السلاسل وMPPT',
      circuit: SafetyCircuitType.pvDc,
    ),
    const SafetyInputDefinition(
      id: 'inverter.maxPvCurrent',
      labelAr: 'أقصى تيار PV مسموح للعاكس',
      sectionAr: 'تكوين السلاسل وMPPT',
      circuit: SafetyCircuitType.pvDc,
    ),
    const SafetyInputDefinition(
      id: 'equipment.batteryModel',
      labelAr: 'الشركة والموديل الدقيق للبطارية/ESS',
      sectionAr: 'بيانات البطارية وBMS',
    ),
    const SafetyInputDefinition(
      id: 'battery.voltageRange',
      labelAr: 'مدى جهد البطارية',
      sectionAr: 'بيانات البطارية وBMS',
      circuit: SafetyCircuitType.batteryDc,
    ),
    const SafetyInputDefinition(
      id: 'battery.maxChargeCurrent',
      labelAr: 'أقصى تيار شحن مستمر للبطارية',
      sectionAr: 'بيانات البطارية وBMS',
      circuit: SafetyCircuitType.batteryDc,
    ),
    const SafetyInputDefinition(
      id: 'battery.maxDischargeCurrent',
      labelAr: 'أقصى تيار تفريغ مستمر للبطارية',
      sectionAr: 'بيانات البطارية وBMS',
      circuit: SafetyCircuitType.batteryDc,
    ),
    const SafetyInputDefinition(
      id: 'battery.shortCircuitCapability',
      labelAr: 'بيان تيار القصر/قدرة القطع المتاحة للبطارية',
      sectionAr: 'بيانات البطارية وBMS',
      circuit: SafetyCircuitType.batteryDc,
    ),
    const SafetyInputDefinition(
      id: 'battery.bmsLimits',
      labelAr: 'حدود BMS والحماية الموصى بها من المصنع',
      sectionAr: 'بيانات البطارية وBMS',
      circuit: SafetyCircuitType.batteryDc,
    ),
    const SafetyInputDefinition(
      id: 'inverter.batteryInputLimits',
      labelAr: 'حدود دخل البطارية في العاكس',
      sectionAr: 'بيانات العاكس',
      circuit: SafetyCircuitType.batteryDc,
    ),
    const SafetyInputDefinition(
      id: 'inverter.acOutputPower',
      labelAr: 'قدرة خرج العاكس المستمرة',
      sectionAr: 'بيانات العاكس',
      circuit: SafetyCircuitType.acOutput,
    ),
    const SafetyInputDefinition(
      id: 'inverter.acOutputVoltage',
      labelAr: 'جهد خرج العاكس',
      sectionAr: 'بيانات العاكس',
      circuit: SafetyCircuitType.acOutput,
    ),
    const SafetyInputDefinition(
      id: 'inverter.acPhaseCount',
      labelAr: 'عدد أطوار خرج العاكس',
      sectionAr: 'بيانات العاكس',
      circuit: SafetyCircuitType.acOutput,
    ),
    const SafetyInputDefinition(
      id: 'inverter.acOutputCurrent',
      labelAr: 'تيار خرج العاكس المستمر/المسموح',
      sectionAr: 'بيانات العاكس',
      circuit: SafetyCircuitType.acOutput,
    ),
    const SafetyInputDefinition(
      id: 'inverter.terminalTemperatureRating',
      labelAr: 'تصنيف حرارة أطراف العاكس',
      sectionAr: 'بيانات العاكس',
      circuit: SafetyCircuitType.acOutput,
    ),
    const SafetyInputDefinition(
      id: 'pv.routeLength',
      labelAr: 'طول مسار كابل PV أحادي الاتجاه',
      sectionAr: 'مسار وتمديد PV DC',
      circuit: SafetyCircuitType.pvDc,
    ),
    const SafetyInputDefinition(
      id: 'pv.conductorMaterial',
      labelAr: 'مادة موصل PV (Cu/Al)',
      sectionAr: 'مسار وتمديد PV DC',
      circuit: SafetyCircuitType.pvDc,
    ),
    const SafetyInputDefinition(
      id: 'pv.insulationType',
      labelAr: 'نوع العزل وتصنيف حرارته لمسار PV',
      sectionAr: 'مسار وتمديد PV DC',
      circuit: SafetyCircuitType.pvDc,
    ),
    const SafetyInputDefinition(
      id: 'pv.installationMethod',
      labelAr: 'طريقة تمديد مسار PV',
      sectionAr: 'مسار وتمديد PV DC',
      circuit: SafetyCircuitType.pvDc,
    ),
    const SafetyInputDefinition(
      id: 'pv.ambientTemperature',
      labelAr: 'أقصى حرارة محيطة لمسار PV',
      sectionAr: 'مسار وتمديد PV DC',
      circuit: SafetyCircuitType.pvDc,
    ),
    const SafetyInputDefinition(
      id: 'pv.currentCarryingConductors',
      labelAr: 'عدد الموصلات الحاملة للتيار في مسار PV',
      sectionAr: 'مسار وتمديد PV DC',
      circuit: SafetyCircuitType.pvDc,
    ),
    const SafetyInputDefinition(
      id: 'battery.routeLength',
      labelAr: 'طول مسار كابل البطارية أحادي الاتجاه',
      sectionAr: 'مسار وتمديد البطارية DC',
      circuit: SafetyCircuitType.batteryDc,
    ),
    const SafetyInputDefinition(
      id: 'battery.conductorMaterial',
      labelAr: 'مادة موصل البطارية (Cu/Al)',
      sectionAr: 'مسار وتمديد البطارية DC',
      circuit: SafetyCircuitType.batteryDc,
    ),
    const SafetyInputDefinition(
      id: 'battery.insulationType',
      labelAr: 'نوع العزل وتصنيف حرارته لمسار البطارية',
      sectionAr: 'مسار وتمديد البطارية DC',
      circuit: SafetyCircuitType.batteryDc,
    ),
    const SafetyInputDefinition(
      id: 'battery.installationMethod',
      labelAr: 'طريقة تمديد مسار البطارية',
      sectionAr: 'مسار وتمديد البطارية DC',
      circuit: SafetyCircuitType.batteryDc,
    ),
    const SafetyInputDefinition(
      id: 'battery.ambientTemperature',
      labelAr: 'أقصى حرارة محيطة لمسار البطارية',
      sectionAr: 'مسار وتمديد البطارية DC',
      circuit: SafetyCircuitType.batteryDc,
    ),
    const SafetyInputDefinition(
      id: 'battery.currentCarryingConductors',
      labelAr: 'عدد الموصلات الحاملة للتيار في مسار البطارية',
      sectionAr: 'مسار وتمديد البطارية DC',
      circuit: SafetyCircuitType.batteryDc,
    ),
    const SafetyInputDefinition(
      id: 'ac.routeLength',
      labelAr: 'طول مسار كابل AC أحادي الاتجاه',
      sectionAr: 'مسار وتمديد AC',
      circuit: SafetyCircuitType.acOutput,
    ),
    const SafetyInputDefinition(
      id: 'ac.conductorMaterial',
      labelAr: 'مادة موصل AC (Cu/Al)',
      sectionAr: 'مسار وتمديد AC',
      circuit: SafetyCircuitType.acOutput,
    ),
    const SafetyInputDefinition(
      id: 'ac.insulationType',
      labelAr: 'نوع العزل وتصنيف حرارته لمسار AC',
      sectionAr: 'مسار وتمديد AC',
      circuit: SafetyCircuitType.acOutput,
    ),
    const SafetyInputDefinition(
      id: 'ac.installationMethod',
      labelAr: 'طريقة تمديد مسار AC',
      sectionAr: 'مسار وتمديد AC',
      circuit: SafetyCircuitType.acOutput,
    ),
    const SafetyInputDefinition(
      id: 'ac.ambientTemperature',
      labelAr: 'أقصى حرارة محيطة لمسار AC',
      sectionAr: 'مسار وتمديد AC',
      circuit: SafetyCircuitType.acOutput,
    ),
    const SafetyInputDefinition(
      id: 'ac.currentCarryingConductors',
      labelAr: 'عدد الموصلات الحاملة للتيار في مسار AC',
      sectionAr: 'مسار وتمديد AC',
      circuit: SafetyCircuitType.acOutput,
    ),
    const SafetyInputDefinition(
      id: 'grounding.topology',
      labelAr: 'وصف نظام التأريض والربط',
      sectionAr: 'التأريض والحماية',
      circuit: SafetyCircuitType.groundingProtection,
    ),
    const SafetyInputDefinition(
      id: 'grounding.route',
      labelAr: 'مسار موصل التأريض والربط',
      sectionAr: 'التأريض والحماية',
      circuit: SafetyCircuitType.groundingProtection,
    ),
    const SafetyInputDefinition(
      id: 'grounding.conductorMaterial',
      labelAr: 'مادة موصل التأريض',
      sectionAr: 'التأريض والحماية',
      circuit: SafetyCircuitType.groundingProtection,
    ),
    const SafetyInputDefinition(
      id: 'grounding.protectionDevices',
      labelAr: 'تفاصيل الحماية المرتبطة بمسار التأريض',
      sectionAr: 'التأريض والحماية',
      circuit: SafetyCircuitType.groundingProtection,
    ),
  ]);

  static SafetyInputDefinition? definitionFor(String id) {
    for (final definition in definitions) {
      if (definition.id == id) return definition;
    }
    return null;
  }
}

String _string(dynamic value) => value is String ? value : '';
