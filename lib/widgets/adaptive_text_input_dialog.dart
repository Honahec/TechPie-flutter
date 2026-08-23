import 'package:flutter/material.dart';

Future<String?> showAdaptiveTextInputDialog({
  required BuildContext context,
  required String title,
  required String fieldLabel,
  required String confirmLabel,
  String? message,
  String? hintText,
  String initialValue = '',
  bool obscureText = false,
  String? confirmationFieldLabel,
  String mismatchMessage = 'Values do not match',
  bool trimResult = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => _AdaptiveTextInputDialog(
      title: title,
      message: message,
      fieldLabel: fieldLabel,
      hintText: hintText,
      confirmLabel: confirmLabel,
      obscureText: obscureText,
      confirmationFieldLabel: confirmationFieldLabel,
      mismatchMessage: mismatchMessage,
      trimResult: trimResult,
      initialValue: initialValue,
    ),
  );
}

class _AdaptiveTextInputDialog extends StatefulWidget {
  const _AdaptiveTextInputDialog({
    required this.title,
    required this.message,
    required this.fieldLabel,
    required this.hintText,
    required this.confirmLabel,
    required this.obscureText,
    required this.confirmationFieldLabel,
    required this.mismatchMessage,
    required this.trimResult,
    required this.initialValue,
  });

  final String title;
  final String? message;
  final String fieldLabel;
  final String? hintText;
  final String confirmLabel;
  final bool obscureText;
  final String? confirmationFieldLabel;
  final String mismatchMessage;
  final bool trimResult;
  final String initialValue;

  @override
  State<_AdaptiveTextInputDialog> createState() =>
      _AdaptiveTextInputDialogState();
}

class _AdaptiveTextInputDialogState extends State<_AdaptiveTextInputDialog> {
  late final TextEditingController _controller;
  late final TextEditingController _confirmationController;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _confirmationController = TextEditingController();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initialValue.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  bool get _needsConfirmation => widget.confirmationFieldLabel != null;

  bool get _valuesMatch =>
      !_needsConfirmation || _controller.text == _confirmationController.text;

  bool get _canSubmit => _controller.text.isNotEmpty && _valuesMatch;

  String get _result =>
      widget.trimResult ? _controller.text.trim() : _controller.text;

  void _close([String? result]) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  void _onChanged(String value) => setState(() {});

  void _submit() {
    if (_canSubmit) _close(_result);
  }

  Widget _buildFields() {
    final mismatch = _confirmationController.text.isNotEmpty && !_valuesMatch;
    final fields = <Widget>[
      if (widget.message != null) ...[
        Text(widget.message!),
        const SizedBox(height: 12),
      ],
      _buildTextField(
        controller: _controller,
        label: widget.fieldLabel,
        hint: widget.hintText,
        autofocus: true,
        onSubmitted: _needsConfirmation ? null : (_) => _submit(),
      ),
      if (_needsConfirmation) ...[
        const SizedBox(height: 12),
        _buildTextField(
          controller: _confirmationController,
          label: widget.confirmationFieldLabel!,
          onSubmitted: (_) => _submit(),
        ),
      ],
      if (mismatch) ...[
        const SizedBox(height: 8),
        Text(
          widget.mismatchMessage,
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
            fontSize: 12,
          ),
        ),
      ],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: fields,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool autofocus = false,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: widget.obscureText,
      autofocus: autofocus,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      textInputAction:
          onSubmitted == null ? TextInputAction.next : TextInputAction.done,
      onChanged: _onChanged,
      onSubmitted: onSubmitted,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(child: _buildFields()),
      actions: [
        TextButton(onPressed: _close, child: const Text('取消')),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
