class Assignment {
  final String id;
  final String platform;
  final String title;
  final String course;
  final DateTime due;
  final DateTime? lateDue;
  final String? status;
  final String? url;

  const Assignment({
    required this.id,
    required this.platform,
    required this.title,
    required this.course,
    required this.due,
    this.lateDue,
    this.status,
    this.url,
  });

  bool get submitted => status == "Submitted" || status == "Graded";

  factory Assignment.fromJson(Map<String, dynamic> json) {
    DateTime parseEpoch(dynamic v) {
      if (v is num) {
        return DateTime.fromMillisecondsSinceEpoch(v.toInt() * 1000);
      }
      return DateTime.now();
    }

    return Assignment(
      id: json["id"] as String? ?? "",
      platform: json["platform"] as String? ?? "unknown",
      title: json["title"] as String? ?? "",
      course: json["course"] as String? ?? "",
      due: json["due"] != null ? parseEpoch(json["due"]) : DateTime.now(),
      lateDue: json["lateDue"] != null ? parseEpoch(json["lateDue"]) : null,
      status: json["status"] as String?,
      url: json["url"] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "platform": platform,
        "title": title,
        "course": course,
        "due": due.millisecondsSinceEpoch ~/ 1000,
        if (lateDue != null) "lateDue": lateDue!.millisecondsSinceEpoch ~/ 1000,
        "status": status,
        "url": url,
      };
}
