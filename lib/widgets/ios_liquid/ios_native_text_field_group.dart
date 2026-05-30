import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/platform.dart';

class IosNativeTextFieldGroupItem {
  const IosNativeTextFieldGroupItem({
    required this.controller,
    required this.placeholder,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.obscureText = false,
    this.enabled = true,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String placeholder;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool obscureText;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;
}

class IosNativeTextFieldGroup extends StatefulWidget {
  const IosNativeTextFieldGroup({
    super.key,
    required this.items,
  });

  final List<IosNativeTextFieldGroupItem> items;

  @override
  State<IosNativeTextFieldGroup> createState() =>
      _IosNativeTextFieldGroupState();
}

class _IosNativeTextFieldGroupState extends State<IosNativeTextFieldGroup> {
  MethodChannel? _channel;
  bool _updatingFromNative = false;

  @override
  void initState() {
    super.initState();
    for (final item in widget.items) {
      item.controller.addListener(_sendTextUpdate);
    }
  }

  @override
  void didUpdateWidget(covariant IosNativeTextFieldGroup oldWidget) {
    super.didUpdateWidget(oldWidget);

    for (final item in oldWidget.items) {
      item.controller.removeListener(_sendTextUpdate);
    }
    for (final item in widget.items) {
      item.controller.addListener(_sendTextUpdate);
    }
    unawaited(_sendConfigurationUpdate());
  }

  @override
  void dispose() {
    for (final item in widget.items) {
      item.controller.removeListener(_sendTextUpdate);
    }
    _channel?.setMethodCallHandler(null);
    _channel = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isIos()) {
      return Column(
        children: [
          for (final item in widget.items)
            TextField(
              controller: item.controller,
              decoration: InputDecoration(hintText: item.placeholder),
              keyboardType: item.keyboardType,
              textInputAction: item.textInputAction,
              obscureText: item.obscureText,
              enabled: item.enabled,
              onSubmitted: item.onSubmitted,
            ),
        ],
      );
    }

    final separatorCount =
        widget.items.length > 1 ? widget.items.length - 1 : 0;
    return SizedBox(
      height: widget.items.length * 56.0 + separatorCount * 0.5,
      child: UiKitView(
        viewType: _viewType,
        layoutDirection: Directionality.of(context),
        creationParams: _configuration,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      ),
    );
  }

  Map<String, Object?> get _configuration {
    return <String, Object?>{
      'items': [
        for (final item in widget.items)
          <String, Object?>{
            'text': item.controller.text,
            'placeholder': item.placeholder,
            'keyboardType': _keyboardTypeName(item.keyboardType),
            'textInputAction': item.textInputAction.name,
            'obscureText': item.obscureText,
            'enabled': item.enabled,
          },
      ],
    };
  }

  void _onPlatformViewCreated(int viewId) {
    final channel = MethodChannel('$_channelPrefix/$viewId');
    _channel = channel;

    channel.setMethodCallHandler((call) async {
      final arguments = call.arguments as Map<Object?, Object?>?;
      final index = arguments?['index'];
      if (index is! int || index < 0 || index >= widget.items.length) {
        return null;
      }

      switch (call.method) {
        case 'onChanged':
          final text = arguments?['text'] as String? ?? '';
          final controller = widget.items[index].controller;
          if (text == controller.text) return null;
          _updatingFromNative = true;
          controller.value = controller.value.copyWith(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
            composing: TextRange.empty,
          );
          _updatingFromNative = false;
        case 'onSubmitted':
          final text = arguments?['text'] as String?;
          final item = widget.items[index];
          if (text != null && text != item.controller.text) {
            _updatingFromNative = true;
            item.controller.value = item.controller.value.copyWith(
              text: text,
              selection: TextSelection.collapsed(offset: text.length),
              composing: TextRange.empty,
            );
            _updatingFromNative = false;
          }
          item.onSubmitted?.call(item.controller.text);
      }

      return null;
    });
  }

  void _sendTextUpdate() {
    if (_updatingFromNative) return;
    final channel = _channel;
    if (channel == null) return;
    unawaited(channel.invokeMethod<void>('updateTexts', <String, Object?>{
      'texts': [for (final item in widget.items) item.controller.text],
    }));
  }

  Future<void> _sendConfigurationUpdate() async {
    final channel = _channel;
    if (channel == null) return;

    try {
      await channel.invokeMethod<void>('updateConfiguration', _configuration);
    } on PlatformException {
      // Platform view may be tearing down.
    } on MissingPluginException {
      // Platform view may not be wired yet.
    }
  }

  String _keyboardTypeName(TextInputType keyboardType) {
    if (keyboardType == TextInputType.emailAddress) return 'emailAddress';
    if (keyboardType == TextInputType.phone) return 'phone';
    if (keyboardType == TextInputType.url) return 'url';
    if (keyboardType == TextInputType.number) return 'number';
    return 'text';
  }
}

const _viewType = 'techpie/native_text_field_group';
const _channelPrefix = 'techpie/native_text_field_group';
