import 'package:flutter/material.dart';

import '../models/dc_cable_installation_model.dart';
import '../models/pv_array_topology_model.dart';
import '../models/safety_audit_model.dart';

class SafetyAuditDetails extends StatelessWidget {
  final SafetyAuditReport report;
  final ValueChanged<ProtectionResultKind>? onInputRequested;
  final int requiredPanels;
  final double panelIscAmps;
  final PvArrayTopologyModel? savedTopology;
  final DcCableInstallationModel? savedDcCable;
  final ValueChanged<PvArrayTopologyModel>? onTopologySelected;

  const SafetyAuditDetails({
    super.key,
    required this.report,
    this.onInputRequested,
    this.requiredPanels = 0,
    this.panelIscAmps = 0,
    this.savedTopology,
    this.savedDcCable,
    this.onTopologySelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'الحماية الكهربائية',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              for (final result in report.presentationResults)
                _ProtectionResultRow(
                  result: result,
                  onInputRequested: onInputRequested,
                  requiredPanels: requiredPanels,
                  panelIscAmps: panelIscAmps,
                  savedTopology: savedTopology,
                  savedDcCable: savedDcCable,
                  onTopologySelected: onTopologySelected,
                ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.center,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('حسناً'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProtectionResultRow extends StatelessWidget {
  final SafetyProtectionResult result;
  final ValueChanged<ProtectionResultKind>? onInputRequested;
  final int requiredPanels;
  final double panelIscAmps;
  final PvArrayTopologyModel? savedTopology;
  final DcCableInstallationModel? savedDcCable;
  final ValueChanged<PvArrayTopologyModel>? onTopologySelected;

  const _ProtectionResultRow({
    required this.result,
    this.onInputRequested,
    required this.requiredPanels,
    required this.panelIscAmps,
    this.savedTopology,
    this.savedDcCable,
    this.onTopologySelected,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (result.status) {
      ProtectionResultStatus.calculated => Colors.green.shade700,
      ProtectionResultStatus.notApplicable => Colors.grey.shade700,
      ProtectionResultStatus.missingData ||
      ProtectionResultStatus.invalidInput ||
      ProtectionResultStatus.unsupportedConfiguration => Colors.deepOrange,
    };
    final canOpenInput =
        !result.isCalculated &&
        (result.kind == ProtectionResultKind.pvArrayCurrent ||
            result.kind == ProtectionResultKind.dcConductorSize) &&
        onInputRequested != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: canOpenInput ? () => onInputRequested!(result.kind) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      result.kind.labelAr,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    result.conciseStatusAr,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (!result.isCalculated) ...[
                const SizedBox(height: 5),
                Text(
                  result.conciseReasonAr,
                  style: TextStyle(color: color, height: 1.35),
                ),
              ],
              if (canOpenInput) ...[
                const SizedBox(height: 6),
                Text(
                  'اضغط لإدخال البيانات',
                  style: TextStyle(color: color, fontSize: 12),
                ),
              ],
              if (result.kind == ProtectionResultKind.pvArrayCurrent &&
                  requiredPanels > 0 &&
                  panelIscAmps > 0) ...[
                const SizedBox(height: 10),
                _PvTopologyOptions(
                  requiredPanels: requiredPanels,
                  panelIscAmps: panelIscAmps,
                  savedTopology: savedTopology,
                  onSelected: onTopologySelected,
                ),
              ],
              if (result.kind == ProtectionResultKind.dcConductorSize) ...[
                const SizedBox(height: 10),
                _DcCableSummary(cable: savedDcCable),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PvTopologyOptions extends StatelessWidget {
  final int requiredPanels;
  final double panelIscAmps;
  final PvArrayTopologyModel? savedTopology;
  final ValueChanged<PvArrayTopologyModel>? onSelected;

  const _PvTopologyOptions({
    required this.requiredPanels,
    required this.panelIscAmps,
    this.savedTopology,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final options = _topologyOptions(requiredPanels);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'خيارات ترتيب الألواح',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'كل خيار يطابق $requiredPanels لوحاً. اختر التوصيل المنفذ فعلياً فقط.',
            style: const TextStyle(fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 8),
          for (final option in options) ...[
            _TopologyOptionTile(
              option: option,
              panelIscAmps: panelIscAmps,
              isSelected:
                  savedTopology?.modulesPerString == option.modulesPerString &&
                  savedTopology?.parallelStrings == option.parallelStrings,
              onTap: onSelected == null
                  ? null
                  : () => onSelected!(
                      PvArrayTopologyModel(
                        modulesPerString: option.modulesPerString,
                        parallelStrings: option.parallelStrings,
                      ),
                    ),
            ),
            if (option != options.last) const SizedBox(height: 6),
          ],
          const SizedBox(height: 8),
          const Text(
            'هذه خيارات عددية فقط؛ يجب التحقق من Voc/Vmp وحدود MPPT للعاكس قبل اعتماد التوصيل.',
            style: TextStyle(fontSize: 11, height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _TopologyOptionTile extends StatelessWidget {
  final _TopologyOption option;
  final double panelIscAmps;
  final bool isSelected;
  final VoidCallback? onTap;

  const _TopologyOptionTile({
    required this.option,
    required this.panelIscAmps,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final current = panelIscAmps * option.parallelStrings;
    final color = isSelected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.outline;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${option.modulesPerString} على التوالي × ${option.parallelStrings} بالتوازي',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? color : null,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${option.totalModules} لوحاً • تيار المصفوفة ${current.toStringAsFixed(1)} A',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              isSelected
                  ? 'الخيار المستخدم حالياً.'
                  : 'التوالي يحدد ترتيب كل مسار، والتوازي يحدد تيار المصفوفة.',
              style: const TextStyle(fontSize: 11, height: 1.25),
            ),
          ],
        ),
      ),
    );
  }
}

class _DcCableSummary extends StatelessWidget {
  final DcCableInstallationModel? cable;

  const _DcCableSummary({this.cable});

  @override
  Widget build(BuildContext context) {
    if (cable == null || !cable!.isComplete) {
      return const Text(
        'تحتاج بيانات السلك: الطول، المادة، العزل، التمديد، الحرارة، والموصلات الحاملة للتيار.',
        style: TextStyle(fontSize: 12, height: 1.3),
      );
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'خصائص الكابل المستخدمة',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          _CableProperty(
            label: 'الموصل',
            value: _materialLabel(cable!.conductorMaterial),
            reason: 'يؤثر على مقاومة السلك وقدرته الحرارية.',
          ),
          _CableProperty(
            label: 'العزل',
            value: cable!.insulationRating!,
            reason: 'يحدد حد حرارة الموصل المسموح بها.',
          ),
          _CableProperty(
            label: 'التمديد',
            value: _installationLabel(cable!.installationMethod),
            reason: 'يؤثر على تبريد الكابل وسعة التيار.',
          ),
          _CableProperty(
            label: 'الموقع',
            value:
                '${cable!.oneWayLengthMeters!.toStringAsFixed(1)} m، ${cable!.ambientTemperatureCelsius!.toStringAsFixed(0)}°C، ${cable!.loadedConductors} موصلات',
            reason: 'يؤثر على هبوط الجهد والتجميع الحراري.',
          ),
          const SizedBox(height: 5),
          const Text(
            'لا يختار SUN مقطعاً أو نوعاً تجارياً قبل إضافة ملف قواعد وكتالوج كابلات معتمدين.',
            style: TextStyle(fontSize: 11, height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _CableProperty extends StatelessWidget {
  final String label;
  final String value;
  final String reason;

  const _CableProperty({
    required this.label,
    required this.value,
    required this.reason,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Text(
      '$label: $value — $reason',
      style: const TextStyle(fontSize: 12),
    ),
  );
}

class _TopologyOption {
  final int modulesPerString;
  final int parallelStrings;

  const _TopologyOption({
    required this.modulesPerString,
    required this.parallelStrings,
  });

  int get totalModules => modulesPerString * parallelStrings;
}

List<_TopologyOption> _topologyOptions(int totalPanels) => List.unmodifiable([
  for (var series = 1; series <= totalPanels; series++)
    if (totalPanels % series == 0)
      _TopologyOption(
        modulesPerString: series,
        parallelStrings: totalPanels ~/ series,
      ),
]);

String _materialLabel(String? value) => switch (value) {
  'copper' => 'نحاس',
  'aluminum' => 'ألمنيوم',
  _ => value ?? 'غير محدد',
};

String _installationLabel(String? value) => switch (value) {
  'conduit' => 'داخل مواسير',
  'open_air' => 'مكشوف بالهواء',
  'tray' => 'على حاملة كابلات',
  'buried' => 'مدفون',
  _ => value ?? 'غير محدد',
};
