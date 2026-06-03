import 'package:flutter/services.dart';

class CalendarImporter {
  static const MethodChannel _channel = MethodChannel(
    'techpie/calendar_importer',
  );

  static Future<int> importCalendarEvents(
    List<Map<String, dynamic>> events, {
    required String calendarName,
  }) async {
    final result = await _channel.invokeMethod<int>('importCalendarEvents', {
      'events': events,
      'calendarName': calendarName,
    });
    return result ?? 0;
  }
}
