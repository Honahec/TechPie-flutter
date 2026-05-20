enum FeatureMode {
  native,
  webviewWithCookie,
}

enum CookieType {
  ecourse,
  egate,
  eams,
}

class Feature {
  final String id;
  final String description;
  final FeatureMode mode;
  final String? url;
  final CookieType? cookieType;

  Feature({
    required this.id,
    required this.description,
    required this.mode,
    this.url,
    this.cookieType,
  });
}

final featureEntries = <Feature>[
  Feature(
    id: 'ecourse',
    description: 'E云课堂',
    mode: FeatureMode.webviewWithCookie,
    url: 'https://ecourse.shanghaitech.edu.cn:8080/',
    cookieType: CookieType.ecourse,
  ),
  Feature(
    id: 'student_leave',
    description: '学生请假',
    mode: FeatureMode.webviewWithCookie,
    url: 'https://egate.shanghaitech.edu.cn/xsfw/sys/xsqjapp/*default/index.do',
    cookieType: CookieType.egate,
  ),
];