import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../../pages/assignments_page.dart';
import '../../pages/home_page.dart';
import '../../pages/schedule_page.dart';
import '../../pages/settings_page.dart';
import 'app_destination.dart';
import 'desktop/desktop_shell.dart';
import 'mobile_shell.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const int _assignmentsIndex = 2;

  int _selectedIndex = 0;
  bool _sidebarCollapsed = false;
  static const List<AppDestination> _destinations = [
    AppDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      sfSymbol: 'house',
      selectedSfSymbol: 'house.fill',
      page: HomePage(key: ValueKey('home')),
    ),
    AppDestination(
      label: 'Schedule',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
      sfSymbol: 'calendar',
      selectedSfSymbol: 'calendar.circle.fill',
      page: SchedulePage(key: ValueKey('schedule')),
    ),
    AppDestination(
      label: 'Assignments',
      icon: Icons.assignment_outlined,
      selectedIcon: Icons.assignment,
      sfSymbol: 'checkmark.circle',
      selectedSfSymbol: 'checkmark.circle.fill',
      page: AssignmentsPage(key: ValueKey('assignments')),
    ),
    AppDestination(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      sfSymbol: 'gearshape',
      selectedSfSymbol: 'gearshape.fill',
      page: SettingsPage(key: ValueKey('settings')),
    ),
  ];

  void _onDestinationSelected(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  void _onSidebarToggleCollapsed() {
    setState(() => _sidebarCollapsed = !_sidebarCollapsed);
  }

  Widget _buildPageView() {
    return PageTransitionSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation, secondaryAnimation) {
        return FadeThroughTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          fillColor: Colors.transparent,
          child: child,
        );
      },
      child: _destinations[_selectedIndex].page,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final pageView = _buildPageView();

    if (width >= 960) {
      return DesktopShell(
        destinations: _destinations,
        selectedIndex: _selectedIndex,
        sidebarCollapsed: _sidebarCollapsed,
        onDestinationSelected: _onDestinationSelected,
        onToggleSidebarCollapsed: _onSidebarToggleCollapsed,
        child: pageView,
      );
    }

    if (width >= 600) {
      return DesktopShell(
        destinations: _destinations,
        selectedIndex: _selectedIndex,
        sidebarCollapsed: true,
        showToggleButton: false,
        onDestinationSelected: _onDestinationSelected,
        onToggleSidebarCollapsed: () {},
        child: pageView,
      );
    }

    return MobileShell(
      destinations: _destinations,
      selectedIndex: _selectedIndex,
      assignmentsIndex: _assignmentsIndex,
      onDestinationSelected: _onDestinationSelected,
      child: pageView,
    );
  }
}
