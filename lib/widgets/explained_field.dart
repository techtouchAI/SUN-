import 'package:flutter/material.dart';

import '../logic/field_help_content.dart';

/// Places an icon-only help button at the trailing edge of its field, with
/// an optional short helper line below. The button follows text direction
/// (left in Arabic) and opens the detailed bullet-point explanation sheet.
/// Used across input screens for consistent placement and accessibility.
class ExplainedField extends StatelessWidget {
  const ExplainedField({
    super.key,
    required this.field,
    required this.explanation,
    this.helperText,
    this.padding = EdgeInsets.zero,
    this.compactWidthThreshold = 220,
  });

  /// Below this available width the help button moves underneath the field
  /// instead of sitting beside it. A 48px trailing button eats most of the
  /// room inside narrow columns (e.g. the three grid-hours fields), which
  /// truncates `labelText` to "ساعات …". Stacking keeps labels fully visible.
  final double compactWidthThreshold;

  /// The field being explained (a [TextFormField], a [DropdownButtonFormField],
  /// a [SwitchListTile], a [Slider], ...).
  final Widget field;

  /// Detailed bullet-point explanation shown in the help sheet.
  final FieldExplanation explanation;

  /// Short one-line clarification rendered directly under the field.
  final String? helperText;

  /// Outer padding applied around the whole block, useful to align the
  /// clarification with dense tiles inside cards.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final helperStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      height: 1.35,
    );

    Widget helpButton({required bool compact}) => IconButton(
      tooltip: 'شرح الحقل: ${explanation.title}',
      onPressed: () => showFieldExplanationSheet(context, explanation),
      icon: const Icon(Icons.help_outline_rounded),
      iconSize: 20,
      color: colorScheme.primary,
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      padding: compact ? EdgeInsets.zero : const EdgeInsets.all(8),
      // Keep a comfortable touch target without a separate text row.
      constraints: BoxConstraints.tightFor(
        width: compact ? 36 : 48,
        height: compact ? 36 : 48,
      ),
    );

    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact =
              constraints.maxWidth.isFinite &&
              constraints.maxWidth < compactWidthThreshold;

          return Column(
            crossAxisAlignment: isCompact
                ? CrossAxisAlignment.stretch
                : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCompact) ...[
                // Narrow column: the field keeps the full width so its label
                // never gets ellipsized, and the help button drops below it.
                field,
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: helpButton(compact: true),
                ),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: field),
                    helpButton(compact: false),
                  ],
                ),
              if (helperText != null && helperText!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(helperText!, style: helperStyle),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Opens the detailed explanation sheet for [explanation].
Future<void> showFieldExplanationSheet(
  BuildContext context,
  FieldExplanation explanation,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (sheetContext) => _FieldExplanationSheet(explanation: explanation),
  );
}

class _FieldExplanationSheet extends StatelessWidget {
  const _FieldExplanationSheet({required this.explanation});

  final FieldExplanation explanation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 24,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      explanation.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              for (final point in explanation.points)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ExplanationBullet(text: point),
                ),
              if (explanation.examples.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        FieldHelpContent.examplesTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final example in explanation.examples)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _ExplanationBullet(
                            text: example,
                            icon: Icons.check_circle_outline_rounded,
                            iconColor: colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(FieldHelpContent.understoodButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExplanationBullet extends StatelessWidget {
  const _ExplanationBullet({
    required this.text,
    this.icon = Icons.circle,
    this.iconColor,
  });

  final String text;
  final IconData icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Icon(
            icon,
            size: 7,
            color: iconColor ?? theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ),
      ],
    );
  }
}
