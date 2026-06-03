import 'package:flutter/material.dart';

class Course {
  final String name;
  final String location;
  final int dayOfWeek; // 1=Mon, 7=Sun
  final int startPeriod; // 1-based
  final int endPeriod; // inclusive
  final CourseColor color;
  final String? teachers;
  final String? weeksText;
  final bool isGhost; // non-current-week course shown transparently

  const Course({
    required this.name,
    required this.location,
    required this.dayOfWeek,
    required this.startPeriod,
    required this.endPeriod,
    this.color = CourseColor.primary,
    this.teachers,
    this.weeksText,
    this.isGhost = false,
  });

  static CourseColor colorFromIndex(int index) =>
      CourseColor.values[index % CourseColor.values.length];
}

enum CourseColor {
  primary,
  secondary,
  tertiary,
  error,
  green,
  orange,
  pink,
}

class Period {
  final int number;
  final String startTime;
  final String endTime;

  const Period({
    required this.number,
    required this.startTime,
    required this.endTime,
  });

  String get label => '$startTime\n$endTime';
}

const List<Period> defaultPeriods = [
  Period(number: 1, startTime: '08:00', endTime: '08:45'),
  Period(number: 2, startTime: '08:55', endTime: '09:40'),
  Period(number: 3, startTime: '09:50', endTime: '10:35'),
  Period(number: 4, startTime: '10:45', endTime: '11:30'),
  Period(number: 5, startTime: '14:00', endTime: '14:45'),
  Period(number: 6, startTime: '14:55', endTime: '15:40'),
];

extension CourseColorScheme on CourseColor {
  /// Seed color for generating a proper tonal [ColorScheme] per course color.
  /// Using [ColorScheme.fromSeed] ensures every container/onContainer pair
  /// meets MD3's contrast requirements (WCAG 4.5:1 for normal text).
  Color get _seed => switch (this) {
        CourseColor.primary => Colors.deepPurple,
        CourseColor.secondary => Colors.blueGrey,
        CourseColor.tertiary => Colors.teal,
        CourseColor.error => Colors.red,
        CourseColor.green => Colors.green,
        CourseColor.orange => Colors.deepOrange,
        CourseColor.pink => Colors.pink,
      };

  ColorScheme _scheme(Brightness brightness) =>
      ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);

  Color containerColor(ColorScheme scheme) =>
      _scheme(scheme.brightness).primaryContainer;

  Color onContainerColor(ColorScheme scheme) =>
      _scheme(scheme.brightness).onPrimaryContainer;
}
