import 'package:flutter/material.dart';

class AppDestination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;

  const AppDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.page,
  });
}
