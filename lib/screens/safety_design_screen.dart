import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/providers.dart';
import '../models/safety_design_model.dart';

class SafetyDesignScreen extends ConsumerWidget {
  const SafetyDesignScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final design = ref.watch(systemSettingsProvider).safetyDesign;
    final groups = <String, List<SafetyInputDefinition>>{};
    for (final definition in SafetyDesignModel.definitions) {
      groups.putIfAbsent(definition.sectionAr, () => []).add(definition);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('بيانات تصميم الحماية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            color: Color(0xFFFFF3E0),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Safety Engine v1 لا يختار قواطع أو مقاطع موصلات ولا يطبق NEC أو IEC تلقائياً. اكتب قيمة كل بند ومصدرها الفعلي، مثل datasheet أو دليل المصنع أو معاينة الموقع.',
                style: TextStyle(height: 1.45),
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final group in groups.entries)
            _DesignSection(
              title: group.key,
              definitions: group.value,
              design: design,
              onChanged: (id, value, source) {
                ref
                    .read(systemSettingsProvider.notifier)
                    .updateSafetyDesign(
                      design.updateInput(id, value: value, source: source),
                    );
              },
            ),
        ],
      ),
    );
  }
}

class _DesignSection extends StatelessWidget {
  final String title;
  final List<SafetyInputDefinition> definitions;
  final SafetyDesignModel design;
  final void Function(String id, String? value, String? source) onChanged;

  const _DesignSection({
    required this.title,
    required this.definitions,
    required this.design,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${definitions.length} حقلاً'),
        children: [
          for (final definition in definitions)
            _DesignInputFields(
              definition: definition,
              input: design.inputFor(definition.id),
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}

class _DesignInputFields extends StatelessWidget {
  final SafetyInputDefinition definition;
  final SafetyDesignInput input;
  final void Function(String id, String? value, String? source) onChanged;

  const _DesignInputFields({
    required this.definition,
    required this.input,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final requiredLabel = definition.requiredForAudit
        ? 'مطلوب للتدقيق'
        : 'سياق اختياري';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            definition.labelAr,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            requiredLabel,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: ValueKey('${definition.id}-value-${input.value}'),
            initialValue: input.value,
            decoration: const InputDecoration(
              labelText: 'القيمة',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => onChanged(definition.id, value, null),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('${definition.id}-source-${input.source}'),
            initialValue: input.source,
            decoration: const InputDecoration(
              labelText: 'المصدر (datasheet، دليل المصنع، معاينة موقع…)',
              border: OutlineInputBorder(),
            ),
            onChanged: (source) => onChanged(definition.id, null, source),
          ),
        ],
      ),
    );
  }
}
