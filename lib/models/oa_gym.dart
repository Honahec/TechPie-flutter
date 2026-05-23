enum OaSport {
  badminton,
  pingpong,
  tennis,
  pickleball,
}

extension OaSportInfo on OaSport {
  String get id => switch (this) {
        OaSport.badminton => 'badminton',
        OaSport.pingpong => 'pingpong',
        OaSport.tennis => 'tennis',
        OaSport.pickleball => 'pickleball',
      };

  String get label => switch (this) {
        OaSport.badminton => '羽毛球',
        OaSport.pingpong => '乒乓球',
        OaSport.tennis => '网球',
        OaSport.pickleball => '匹克球',
      };

  String get courtPrefix => switch (this) {
        OaSport.badminton => '羽毛球场地',
        OaSport.pingpong => '乒乓球场',
        OaSport.tennis => '网球场',
        OaSport.pickleball => '匹克球',
      };
}

class OaTimeSlot {
  final int id;
  final String start;
  final String end;

  const OaTimeSlot({
    required this.id,
    required this.start,
    required this.end,
  });

  String get range => '$start-$end';
}

const oaTimeSlots = <OaTimeSlot>[
  OaTimeSlot(id: 1, start: '11:00', end: '12:00'),
  OaTimeSlot(id: 2, start: '12:00', end: '13:00'),
  OaTimeSlot(id: 3, start: '13:00', end: '14:00'),
  OaTimeSlot(id: 4, start: '14:00', end: '15:00'),
  OaTimeSlot(id: 5, start: '15:00', end: '16:00'),
  OaTimeSlot(id: 6, start: '16:00', end: '17:00'),
  OaTimeSlot(id: 7, start: '17:00', end: '18:00'),
  OaTimeSlot(id: 8, start: '18:00', end: '19:00'),
  OaTimeSlot(id: 9, start: '19:00', end: '20:00'),
  OaTimeSlot(id: 10, start: '20:00', end: '21:00'),
  OaTimeSlot(id: 11, start: '21:00', end: '22:00'),
];

const oaTimeEndpointStart = 11;
const oaTimeEndpointEnd = 22;

List<int> oaSlotIdsForEndpointRange(int startHour, int endHour) => [
      for (var hour = startHour; hour < endHour; hour++)
        hour - oaTimeEndpointStart + 1,
    ];

String oaEndpointRangeLabel(int startHour, int endHour) =>
    '${startHour.toString().padLeft(2, '0')}:00-'
    '${endHour.toString().padLeft(2, '0')}:00';

class OaSportConfig {
  final OaSport sport;
  final String field32340;
  final int courtOffset;
  final int courtCount;
  final String parentName;
  final String courtNamePrefix;
  final String courtNameSuffix;

  const OaSportConfig({
    required this.sport,
    required this.field32340,
    required this.courtOffset,
    required this.courtCount,
    required this.parentName,
    required this.courtNamePrefix,
    required this.courtNameSuffix,
  });
}

const oaSportConfigs = <OaSport, OaSportConfig>{
  OaSport.badminton: OaSportConfig(
    sport: OaSport.badminton,
    field32340: '4',
    courtOffset: 12,
    courtCount: 6,
    parentName: '室内羽毛球场',
    courtNamePrefix: '羽毛球场地',
    courtNameSuffix: '号',
  ),
  OaSport.pingpong: OaSportConfig(
    sport: OaSport.pingpong,
    field32340: '5',
    courtOffset: 18,
    courtCount: 6,
    parentName: '室内乒乓球场',
    courtNamePrefix: '乒乓球场',
    courtNameSuffix: '号',
  ),
  OaSport.tennis: OaSportConfig(
    sport: OaSport.tennis,
    field32340: '6',
    courtOffset: 24,
    courtCount: 3,
    parentName: '网球场',
    courtNamePrefix: '网球场',
    courtNameSuffix: '号',
  ),
  OaSport.pickleball: OaSportConfig(
    sport: OaSport.pickleball,
    field32340: '11',
    courtOffset: 42,
    courtCount: 1,
    parentName: '匹克球场',
    courtNamePrefix: '匹克球',
    courtNameSuffix: '号场地',
  ),
};

class OaAvailability {
  final OaSport sport;
  final String date;
  final int timeSlot;
  final List<int> availableCourts;
  final int totalCourts;

  const OaAvailability({
    required this.sport,
    required this.date,
    required this.timeSlot,
    required this.availableCourts,
    required this.totalCourts,
  });

  String get key => '${sport.id}|$timeSlot';
}

class OaCourtSearchResult {
  final String venue;
  final String timeRange;
  final List<List<String>> rows;

  const OaCourtSearchResult({
    required this.venue,
    required this.timeRange,
    required this.rows,
  });
}

class OaBookingResult {
  final bool success;
  final String message;

  const OaBookingResult({
    required this.success,
    required this.message,
  });
}

class OaBookingProfile {
  final String name;
  final String phone;
  final String email;

  const OaBookingProfile({
    required this.name,
    required this.phone,
    required this.email,
  });

  OaBookingProfile copyWith({
    String? name,
    String? phone,
    String? email,
  }) =>
      OaBookingProfile(
        name: name ?? this.name,
        phone: phone ?? this.phone,
        email: email ?? this.email,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'email': email,
      };

  factory OaBookingProfile.fromJson(Map<String, dynamic> json) =>
      OaBookingProfile(
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        email: json['email'] as String? ?? '',
      );
}
