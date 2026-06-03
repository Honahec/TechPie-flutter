enum DeadlineKind {
  assignment('assignment', '作业'),
  exam('exam', '考试');

  final String id;
  final String label;

  const DeadlineKind(this.id, this.label);

  static DeadlineKind fromJson(dynamic value) {
    final id = value?.toString().toLowerCase();
    return DeadlineKind.values.firstWhere(
      (kind) => kind.id == id,
      orElse: () => DeadlineKind.assignment,
    );
  }
}

class Assignment {
  final String id;
  final String platform;
  final DeadlineKind kind;
  final String title;
  final String course;
  final DateTime due;
  final DateTime? lateDue;
  final String? status;
  final String? url;

  const Assignment({
    required this.id,
    required this.platform,
    this.kind = DeadlineKind.assignment,
    required this.title,
    required this.course,
    required this.due,
    this.lateDue,
    this.status,
    this.url,
  });

  bool get submitted => status == 'Submitted' || status == 'Graded';

  factory Assignment.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v is num) {
        return DateTime.fromMillisecondsSinceEpoch(v.toInt() * 1000);
      }
      if (v is String) {
        final asNum = num.tryParse(v);
        if (asNum != null) {
          return DateTime.fromMillisecondsSinceEpoch(asNum.toInt() * 1000);
        }
        final parsed = DateTime.tryParse(v);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    return Assignment(
      id: json['id'] as String? ?? '',
      platform: json['platform'] as String? ?? 'unknown',
      kind: DeadlineKind.fromJson(json['kind']),
      title: json['title'] as String? ?? '',
      course: json['course'] as String? ?? '',
      due: json['due'] != null ? parseDate(json['due']) : DateTime.now(),
      lateDue: json['lateDue'] != null ? parseDate(json['lateDue']) : null,
      status: json['status'] as String?,
      url: json['url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'platform': platform,
        'kind': kind.id,
        'title': title,
        'course': course,
        'due': due.millisecondsSinceEpoch ~/ 1000,
        if (lateDue != null) 'lateDue': lateDue!.millisecondsSinceEpoch ~/ 1000,
        'status': status,
        'url': url,
      };
}
