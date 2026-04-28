import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NativeGlassTabBarItem {
  const NativeGlassTabBarItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.sfSymbol,
    required this.selectedSfSymbol,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String sfSymbol;
  final String selectedSfSymbol;
}

class NativeGlassTabBar extends StatefulWidget {
  const NativeGlassTabBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<NativeGlassTabBarItem> items;

  @override
  State<NativeGlassTabBar> createState() => _NativeGlassTabBarState();
}

class _NativeGlassTabBarState extends State<NativeGlassTabBar> {
  MethodChannel? _channel;

  bool get _usesNativeBar =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void didUpdateWidget(covariant NativeGlassTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_usesNativeBar && oldWidget.selectedIndex != widget.selectedIndex) {
      _sendSelectionUpdate(widget.selectedIndex);
    }
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_usesNativeBar) {
      return NavigationBar(
        selectedIndex: widget.selectedIndex,
        onDestinationSelected: widget.onSelected,
        destinations: [
          for (final item in widget.items)
            NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon),
              label: item.label,
            ),
        ],
      );
    }

    final creationParams = <String, dynamic>{
      'selectedIndex': widget.selectedIndex,
      'items': [
        for (final item in widget.items)
          <String, dynamic>{
            'label': item.label,
            'sfSymbol': item.sfSymbol,
            'selectedSfSymbol': item.selectedSfSymbol,
          },
      ],
    };

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: SizedBox(
        height: 72,
        child: UiKitView(
          viewType: _viewType,
          layoutDirection: Directionality.of(context),
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
        ),
      ),
    );
  }

  Future<void> _onPlatformViewCreated(int viewId) async {
    final channel = MethodChannel('$_channelPrefix/$viewId');
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onSelect':
          final arguments = call.arguments;
          final index = arguments is Map ? arguments['index'] : null;
          if (index is int) {
            widget.onSelected(index);
          }
          return null;
        default:
          return null;
      }
    });
    await _sendSelectionUpdate(widget.selectedIndex);
  }

  Future<void> _sendSelectionUpdate(int index) async {
    final channel = _channel;
    if (channel == null) return;
    try {
      await channel.invokeMethod<void>(
        'updateSelectedIndex',
        <String, dynamic>{'index': index},
      );
    } on PlatformException {
      // Ignore transient channel errors during view teardown.
    } on MissingPluginException {
      // Ignore calls issued before the platform view finishes wiring itself up.
    }
  }
}

const _viewType = 'techpie/native_glass_tab_bar';
const _channelPrefix = 'techpie/native_glass_tab_bar';
