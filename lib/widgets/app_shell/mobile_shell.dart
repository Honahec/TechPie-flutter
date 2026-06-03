import 'package:flutter/material.dart';

import '../../utils/platform.dart';
import '../ios_liquid/ios_glass_button.dart';
import '../ios_liquid/ios_glass_tab_bar.dart';
import 'app_destination.dart';

class MobileShell extends StatelessWidget {
  final List<AppDestination> destinations;
  final int selectedIndex;
  final int assignmentsIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  const MobileShell({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.assignmentsIndex,
    required this.onDestinationSelected,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final usesIosChrome = isIos();

    return Scaffold(
      extendBody: true,
      body: child,
      floatingActionButton: selectedIndex == assignmentsIndex
          ? usesIosChrome
              ? IosGlassButton(
                  onPressed: () {},
                  icon: Icons.add,
                  sfSymbol: 'plus',
                )
              : FloatingActionButton(
                  onPressed: () {},
                  child: const Icon(Icons.add),
                )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: usesIosChrome
          ? IosGlassTabBar(
              selectedIndex: selectedIndex,
              items: destinations
                  .map((item) => item.toIosGlassTabBarItem())
                  .toList(),
              onSelected: onDestinationSelected,
            )
          : NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: [
                for (final destination in destinations)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: destination.label,
                  ),
              ],
            ),
    );
  }
}
