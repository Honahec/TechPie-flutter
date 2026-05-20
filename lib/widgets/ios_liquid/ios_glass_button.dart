import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:techpie/utils/platform.dart';

class IosGlassButton extends StatefulWidget {
  const IosGlassButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.sfSymbol,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String sfSymbol;

  @override
  State<IosGlassButton> createState() => _IosGlassButtonState();
}

class _IosGlassButtonState extends State<IosGlassButton> {
  MethodChannel? _channel;

  @override
  void didUpdateWidget(covariant IosGlassButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.sfSymbol == widget.sfSymbol) return;
    _sendSymbolUpdate(widget.sfSymbol);
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    _channel = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isIos()) {
      return IconButton.filled(
        onPressed: widget.onPressed,
        icon: Icon(widget.icon),
      );
    }

    return SizedBox.square(
      dimension: 64,
      child: UiKitView(
        viewType: _viewType,
        layoutDirection: Directionality.of(context),
        creationParams: <String, Object?>{'sfSymbol': widget.sfSymbol},
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      ),
    );
  }

  void _onPlatformViewCreated(int viewId) {
    final channel = MethodChannel('$_channelPrefix/$viewId');
    _channel = channel;

    channel.setMethodCallHandler((call) async {
      if (call.method != 'onTap') return null;

      widget.onPressed();
      return null;
    });
  }

  Future<void> _sendSymbolUpdate(String sfSymbol) async {
    final channel = _channel;
    if (channel == null) return;

    try {
      await channel.invokeMethod<void>('updateSymbol', <String, Object?>{
        'sfSymbol': sfSymbol,
      });
    } on PlatformException {
      // Platform view may be tearing down.
    } on MissingPluginException {
      // Platform view may not be wired yet.
    }
  }
}

const _viewType = 'techpie/native_glass_button';
const _channelPrefix = 'techpie/native_glass_button';
