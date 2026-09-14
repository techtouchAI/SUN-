import 'package:flutter/material.dart';

import '../logic/field_help_content.dart';

/// Wraps a form field together with its clarification, rendered below the
/// field:
///  1. the field itself;
///  2. an optional short helper line describing what to write;
///  3. a tappable trigger sentence that opens a detailed bullet-point
///     explanation sheet.
///
/// Used across the input screens so every ambiguous field is explained in a
/// single, consistent way.
class ExplainedField extends StatelessWidget {
  const ExplainedField({
    super.key,
    required this.field,
    required this.explanation,
    this.helperText,
    this.triggerText = FieldHelpContent.triggerText,
    this.padding = EdgeInsets.zero,
  });

  /// The field being explained (a [TextFormField], a [DropdownButtonFormField],
  /// a [SwitchListTile], a [Slider], ...).
  final Widget field;

  /// Detailed bullet-point explanation shown in the help sheet.
  final FieldExplanation explanation;

  /// Short one-line clarification rendered directly under the field.
  final String? helperText;

  /// Sentence rendered under the field that opens the explanation sheet.
  final String triggerText;

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
    final triggerStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.primary,
      fontWeight: FontWeight.w600,
      height: 1.35,
      decoration: TextDecoration.underline,
      decorationColor: colorScheme.primary.withValues(alpha: 0.45),
    );

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          field,
          if (helperText != null && helperText!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(helperText!, style: helperStyle),
          ],
          const SizedBox(height: 4),
          InkWell(
            onTap: () => showFieldExplanationSheet(context, explanation),
            borderRadius: BorderRadius.circular(6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1.5),
                  child: Icon(
                    Icons.help_outline_rounded,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(triggerText, style: triggerStyle),
                ),
              ],
            ),
          ),
        ],
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
    builder: (sheetContext) => _FieldExplanationSheet(
      explanation: explanation,
    ),
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
