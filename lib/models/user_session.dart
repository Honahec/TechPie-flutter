class UserSession {
  final String sessionToken;
  final String tgc;
  final String userId;
  final String userName;
  final String schoolName;
  final String tenantId;
  final String phoneNumber;
  final DateTime createdAt;

  UserSession({
    required this.sessionToken,
    required this.tgc,
    required this.userId,
    required this.userName,
    required this.schoolName,
    required this.tenantId,
    required this.phoneNumber,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'sessionToken': sessionToken,
        'tgc': tgc,
        'userId': userId,
        'userName': userName,
        'schoolName': schoolName,
        'tenantId': tenantId,
        'phoneNumber': phoneNumber,
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
        sessionToken: json['sessionToken'] as String? ?? '',
        tgc: json['tgc'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        userName: json['userName'] as String? ?? '',
        schoolName: json['schoolName'] as String? ?? '',
        tenantId: json['tenantId'] as String? ?? '',
        phoneNumber: json['phoneNumber'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );

  UserSession copyWith({
    String? sessionToken,
    String? tgc,
    String? userId,
    String? userName,
    String? schoolName,
    String? tenantId,
    String? phoneNumber,
    DateTime? createdAt,
  }) =>
      UserSession(
        sessionToken: sessionToken ?? this.sessionToken,
        tgc: tgc ?? this.tgc,
        userId: userId ?? this.userId,
        userName: userName ?? this.userName,
        schoolName: schoolName ?? this.schoolName,
        tenantId: tenantId ?? this.tenantId,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        createdAt: createdAt ?? this.createdAt,
      );
}
