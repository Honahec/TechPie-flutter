import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/platform.dart';

class IosNativeTextView extends StatefulWidget {
  const IosNativeTextView({
    super.key,
    required this.controller,
    required this.placeholder,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.minLines = 1,
    this.maxLines = 1,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String placeholder;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final int minLines;
  final int maxLines;
  final bool enabled;

  @override
  State<IosNativeTextView> createState() => _IosNativeTextViewState();
}

class _IosNativeTextViewState extends State<IosNativeTextView> {
  MethodChannel? _channel;
  bool _updatingFromNative = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sendTextUpdate);
  }

  @override
  void didUpdateWidget(covariant IosNativeTextView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_sendTextUpdate);
      widget.controller.addListener(_sendTextUpdate);
    }
    unawaited(_sendConfigurationUpdate());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sendTextUpdate);
    _channel?.setMethodCallHandler(null);
    _channel = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isIos()) {
      return TextField(
        controller: widget.controller,
        decoration: InputDecoration(
          hintText: widget.placeholder,
        ),
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        enabled: widget.enabled,
      );
    }

    return SizedBox(
      height: 108,
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
      'text': widget.controller.text,
      'placeholder': widget.placeholder,
      'keyboardType': _keyboardTypeName(widget.keyboardType),
      'textInputAction': widget.textInputAction.name,
      'minLines': widget.minLines,
      'maxLines': widget.maxLines,
      'enabled': widget.enabled,
    };
  }

  void _onPlatformViewCreated(int viewId) {
    final channel = MethodChannel('$_channelPrefix/$viewId');
    _channel = channel;

    channel.setMethodCallHandler((call) async {
      final arguments = call.arguments as Map<Object?, Object?>?;
      switch (call.method) {
        case 'onChanged':
          final text = arguments?['text'] as String? ?? '';
          if (text == widget.controller.text) return null;
          _updatingFromNative = true;
          widget.controller.value = widget.controller.value.copyWith(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
            composing: TextRange.empty,
          );
          _updatingFromNative = false;
      }
      return null;
    });
  }

  void _sendTextUpdate() {
    if (_updatingFromNative) return;
    final channel = _channel;
    if (channel == null) return;
    unawaited(channel.invokeMethod<void>('updateText', <String, Object?>{
      'text': widget.controller.text,
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

const _viewType = 'techpie/native_text_view';
const _channelPrefix = 'techpie/native_text_view';
