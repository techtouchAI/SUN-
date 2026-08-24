import 'package:flutter/material.dart';

class ReactiveTextField extends StatefulWidget {
  final double initialValue;
  final ValueChanged<String> onChanged;
  final String labelText;

  const ReactiveTextField({
    super.key,
    required this.initialValue,
    required this.onChanged,
    required this.labelText,
  });

  @override
  State<ReactiveTextField> createState() => _ReactiveTextFieldState();
}

class _ReactiveTextFieldState extends State<ReactiveTextField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue == 0 ? '' : widget.initialValue.toString(),
    );
  }

  @override
  void didUpdateWidget(ReactiveTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      final newText = widget.initialValue == 0
          ? ''
          : widget.initialValue.toString();
      if (_controller.text != newText) {
        // Only update if text is different to avoid cursor reset
        final currentSelection = _controller.selection;
        _controller.text = newText;
        // Try to restore selection
        if (currentSelection.isValid &&
            currentSelection.end <= newText.length) {
          _controller.selection = currentSelection;
        } else {
          _controller.selection = TextSelection.collapsed(
            offset: newText.length,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: widget.labelText,
        border: const OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: widget.onChanged,
    );
  }
}
