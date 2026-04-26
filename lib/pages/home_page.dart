import 'package:flutter/material.dart';

import '../models/course.dart';
import '../models/course_table.dart';
import '../services/schedule_service.dart';
import '../services/service_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late ScheduleService _schedule;
  List<Course> _todayCourses = [];
  List<Period> _periods = defaultPeriods.toList();
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _schedule = ServiceProvider.of(context).scheduleService;
      _schedule.addListener(_rebuild);
      _doRebuild();
    }
  }

  @override
  void dispose() {
    _schedule.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (!mounted) return;
    // Defer setState to avoid calling it during build phase
    // (ScheduleService may notify during another widget's didChangeDependencies)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _doRebuild();
    });
  }

  void _doRebuild() {
    setState(() {
      final table = _schedule.courseTable;
      if (table != null) {
        if (table.periods.isNotEmpty) {
          _periods = table.periods.map((p) => p.toPeriod()).toList();
        }
        final week = _schedule.currentWeek();
        final today = DateTime.now().weekday; // 1=Mon, 7=Sun
        final all = eamsToDisplayCourses(table.courses, week);
        _todayCourses = all.where((c) => c.dayOfWeek == today).toList()
          ..sort((a, b) => a.startPeriod.compareTo(b.startPeriod));
      } else {
        _todayCourses = [];
      }
    });
  }

  String _timeForCourse(Course course) {
    if (course.startPeriod - 1 < _periods.length &&
        course.endPeriod - 1 < _periods.length) {
      final start = _periods[course.startPeriod - 1];
      final end = _periods[course.endPeriod - 1];
      return '${start.startTime} – ${end.endTime}';
    }
    return '第${course.startPeriod}-${course.endPeriod}节';
  }

  bool _isCourseNow(Course course) {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    if (course.startPeriod - 1 >= _periods.length) return false;
    if (course.endPeriod - 1 >= _periods.length) return false;
    final start = _periods[course.startPeriod - 1];
    final end = _periods[course.endPeriod - 1];
    final startMin = _parseMinutes(start.startTime);
    final endMin = _parseMinutes(end.endTime);
    if (startMin == null || endMin == null) return false;
    return nowMinutes >= startMin && nowMinutes <= endMin;
  }

  bool _isCoursePast(Course course) {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    if (course.endPeriod - 1 >= _periods.length) return false;
    final end = _periods[course.endPeriod - 1];
    final endMin = _parseMinutes(end.endTime);
    if (endMin == null) return false;
    return nowMinutes > endMin;
  }

  static int? _parseMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ServiceProvider.of(context).authService;

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card.filled(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome to TechPie',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your academic dashboard at a glance.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildTodayClasses(theme, auth.isLoggedIn),
          const SizedBox(height: 8),
          Card.outlined(
            child: ListTile(
              leading: Icon(
                Icons.assignment_outlined,
                color: theme.colorScheme.tertiary,
              ),
              title: const Text('Pending assignments'),
              subtitle: const Text('All caught up!'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayClasses(ThemeData theme, bool isLoggedIn) {
    if (!isLoggedIn || _todayCourses.isEmpty) {
      return Card.outlined(
        child: ListTile(
          leading: Icon(
            Icons.calendar_today,
            color: theme.colorScheme.primary,
          ),
          title: const Text('Upcoming classes'),
          subtitle: Text(
            !isLoggedIn ? '登录以查看今日课程' : '今天没有课程',
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      );
    }

    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '今日课程',
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  '${_todayCourses.length}节课',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (int i = 0; i < _todayCourses.length; i++) ...[
            _buildCourseItem(theme, _todayCourses[i]),
            if (i < _todayCourses.length - 1) const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }

  Widget _buildCourseItem(ThemeData theme, Course course) {
    final isNow = _isCourseNow(course);
    final isPast = _isCoursePast(course);
    final containerColor = course.color.containerColor(theme.colorScheme);
    final onContainerColor = course.color.onContainerColor(theme.colorScheme);

    return Opacity(
      opacity: isPast ? 0.5 : 1.0,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: containerColor,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            '${course.startPeriod}',
            style: theme.textTheme.titleSmall?.copyWith(
              color: onContainerColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Text(
          course.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: isNow
              ? theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                )
              : null,
        ),
        subtitle: Text(
          '${_timeForCourse(course)}'
          '${course.location.isNotEmpty ? '  ${course.location}' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: isNow
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '进行中',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
