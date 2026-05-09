import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/assignment.dart';
import '../models/assignment_overrides.dart';
import '../services/assignment_service.dart';
import '../services/service_provider.dart';
import '../widgets/blurred_app_bar.dart';
import '../widgets/ios_liquid/ios_glass_dropdown_menu.dart';
import '../widgets/swipeable_card.dart';
import 'hidden_assignments_page.dart';
import 'third_party_accounts_page.dart';

class AssignmentsPage extends StatefulWidget {
  const AssignmentsPage({super.key});

  @override
  State<AssignmentsPage> createState() => _AssignmentsPageState();
}

class _AssignmentsPageState extends State<AssignmentsPage> {
  bool _pastCollapsed = true;
  bool _selectionMode = false;
  final Set<String> _selected = {};

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selected.clear();
    });
  }

  void _enterSelectionWith(String key) {
    setState(() {
      _selectionMode = true;
      _selected.add(key);
    });
  }

  void _toggleSelection(String key) {
    setState(() {
      if (_selected.remove(key)) {
        if (_selected.isEmpty) _selectionMode = false;
      } else {
        _selected.add(key);
      }
    });
  }

  void _selectAll(List<Assignment> all) {
    setState(() {
      final allKeys = all.map(AssignmentOverrides.keyFor).toSet();
      if (_selected.length == allKeys.length) {
        _selected.clear();
        _selectionMode = false;
      } else {
        _selected
          ..clear()
          ..addAll(allKeys);
      }
    });
  }

  void _invertSelection(List<Assignment> all) {
    setState(() {
      final allKeys = all.map(AssignmentOverrides.keyFor).toSet();
      final next = allKeys.difference(_selected);
      _selected
        ..clear()
        ..addAll(next);
      if (_selected.isEmpty) _selectionMode = false;
    });
  }

  Future<void> _resetSelected(AssignmentService service) async {
    await service.resetOverrides(_selected.toList());
    _exitSelection();
  }

  @override
  Widget build(BuildContext context) {
    final assignmentService = ServiceProvider.of(context).assignmentService;
    final topInset = kToolbarHeight + MediaQuery.viewPaddingOf(context).top;

    return ListenableBuilder(
      listenable: assignmentService,
      builder: (context, _) {
        final visible = assignmentService.visibleAssignments;
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: _selectionMode
              ? _buildSelectionAppBar(context, assignmentService, visible)
              : _buildNormalAppBar(context, assignmentService),
          body: PopScope(
            canPop: !_selectionMode,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && _selectionMode) _exitSelection();
            },
            child: _buildBody(context, assignmentService, visible, topInset),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildNormalAppBar(
    BuildContext context,
    AssignmentService service,
  ) {
    final usesIosLiquidGlass =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    return BlurredAppBar(
      title: const Text('Deadlines'),
      actions: [
        if (usesIosLiquidGlass)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Center(
              child: IosGlassDropdownMenu(
                icon: Icons.more_vert,
                sfSymbol: 'ellipsis',
                tooltip: '更多操作',
                items: [
                  IosGlassDropdownMenuItem(
                    value: 'hidden',
                    label: '查看已忽略 (${service.overrides.hidden.length})',
                  ),
                ],
                onSelected: (v) {
                  if (v == 'hidden') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HiddenAssignmentsPage(),
                      ),
                    );
                  }
                },
              ),
            ),
          )
        else
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'hidden') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HiddenAssignmentsPage(),
                  ),
                );
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'hidden',
                child: Row(
                  children: [
                    const Icon(Icons.visibility_off_outlined, size: 20),
                    const SizedBox(width: 12),
                    Text('查看已忽略 (${service.overrides.hidden.length})'),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  PreferredSizeWidget _buildSelectionAppBar(
    BuildContext context,
    AssignmentService service,
    List<Assignment> visible,
  ) {
    final allSelected =
        visible.isNotEmpty && _selected.length == visible.length;
    return BlurredAppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _exitSelection,
        tooltip: '退出多选',
      ),
      title: Text('已选择 ${_selected.length} 个'),
      actions: [
        IconButton(
          icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
          tooltip: allSelected ? '全不选' : '全选',
          onPressed: () => _selectAll(visible),
        ),
        IconButton(
          icon: const Icon(Icons.flip_to_front),
          tooltip: '反选',
          onPressed: () => _invertSelection(visible),
        ),
        IconButton(
          icon: const Icon(Icons.restart_alt),
          tooltip: '重置状态',
          onPressed: _selected.isEmpty ? null : () => _resetSelected(service),
        ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    AssignmentService service,
    List<Assignment> visible,
    double topInset,
  ) {
    final banner = _PlatformErrorsBanner(errors: service.platformErrors);

    if (service.loading && visible.isEmpty) {
      return Column(
        children: [
          SizedBox(height: topInset),
          banner,
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }

    if (visible.isEmpty) {
      return Column(
        children: [
          SizedBox(height: topInset),
          banner,
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => service.fetchAssignments(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: _emptyState(context, service),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        SizedBox(height: topInset),
        banner,
        Expanded(child: _buildList(context, service, visible)),
      ],
    );
  }

  Widget _emptyState(BuildContext context, AssignmentService service) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_turned_in_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text('No upcoming assignments', style: theme.textTheme.titleMedium),
          if (service.error != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                service.error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    AssignmentService service,
    List<Assignment> sorted,
  ) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final past = sorted.where((a) => a.due.isBefore(now)).toList();
    final upcoming = sorted.where((a) => !a.due.isBefore(now)).toList();
    final todayLabel = DateFormat('yyyy-MM-dd EEE').format(now);

    return RefreshIndicator(
      onRefresh: () => service.fetchAssignments(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          if (past.isNotEmpty) ...[
            InkWell(
              onTap: () => setState(() => _pastCollapsed = !_pastCollapsed),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      _pastCollapsed ? Icons.chevron_right : Icons.expand_more,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '已过期 (${past.length})',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _pastCollapsed ? '展开' : '折叠',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!_pastCollapsed)
              ...past.map((a) => _buildItem(context, service, a)),
            const SizedBox(height: 4),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(child: Divider(color: theme.colorScheme.primary)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '今天 · $todayLabel',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: theme.colorScheme.primary)),
              ],
            ),
          ),
          if (upcoming.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  '没有未来的 ddl',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ...upcoming.map((a) => _buildItem(context, service, a)),
        ],
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    AssignmentService service,
    Assignment a,
  ) {
    final key = AssignmentOverrides.keyFor(a);
    final selected = _selected.contains(key);
    final completed = service.isCompleted(a);
    final scheme = Theme.of(context).colorScheme;

    final card = _AssignmentCard(
      assignment: a,
      completed: completed,
      hasOverride: service.hasCompletionOverride(a),
      selected: selected,
      selectionMode: _selectionMode,
      onTap: () => _onTapItem(context, service, a, key),
      onLongPress: _selectionMode ? null : () => _enterSelectionWith(key),
    );

    final inner = _selectionMode
        ? Padding(padding: const EdgeInsets.only(bottom: 12), child: card)
        : SwipeableCard(
            startAction: SwipeAction(
              icon: completed
                  ? Icons.cancel_outlined
                  : Icons.check_circle_outline,
              label: completed ? '取消完成' : '标记完成',
              background: scheme.primaryContainer,
              foreground: scheme.onPrimaryContainer,
            ),
            endAction: SwipeAction(
              icon: Icons.delete_outline,
              label: '删除',
              background: scheme.errorContainer,
              foreground: scheme.onErrorContainer,
            ),
            onStartSwipe: () => service.toggleCompleted(a),
            onDismissed: () => _onDismiss(context, service, a, key),
            child: card,
          );

    // Stable key by override-key so swapping selection mode keeps the
    // entry animation from re-triggering. Each new key (unhide, undo,
    // first appearance) plays the enter animation; existing items just
    // rebuild in place.
    return CardEnterAnimation(key: ValueKey(key), child: inner);
  }

  void _onDismiss(
    BuildContext context,
    AssignmentService service,
    Assignment a,
    String key,
  ) {
    service.hide(a);
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text('已忽略「${a.title}」'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () => service.unhide(key),
        ),
      ),
    );
  }

  Future<void> _onTapItem(
    BuildContext context,
    AssignmentService service,
    Assignment a,
    String key,
  ) async {
    if (_selectionMode) {
      _toggleSelection(key);
      return;
    }
    final url = a.url;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('该作业没有链接')));
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('链接无法解析')));
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开链接')));
    }
  }
}

class _PlatformErrorsBanner extends StatelessWidget {
  final Map<String, String> errors;
  const _PlatformErrorsBanner({required this.errors});

  @override
  Widget build(BuildContext context) {
    if (errors.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline,
              size: 20,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in errors.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '${entry.key}: ${entry.value}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ThirdPartyAccountsPage(),
                ),
              ),
              child: const Text('Manage'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final Assignment assignment;
  final bool completed;
  final bool hasOverride;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _AssignmentCard({
    required this.assignment,
    required this.completed,
    required this.hasOverride,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isPast = assignment.due.isBefore(now);

    final formatter = DateFormat('MM/dd HH:mm');
    final dueString = formatter.format(assignment.due);

    Color statusColor() {
      if (completed) return Colors.green;
      if (isPast) return Colors.red;
      final hoursLeft = assignment.due.difference(now).inHours;
      if (hoursLeft < 24) return Colors.orange;
      return theme.colorScheme.primary;
    }

    final statusLabel = completed
        ? (assignment.status == 'Graded' ? 'Graded' : 'Submitted')
        : assignment.status;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: selected ? theme.colorScheme.secondaryContainer : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: selected
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (selectionMode) ...[
                    Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      assignment.platform.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (hasOverride) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: '本地标记',
                      child: Icon(
                        Icons.edit_note,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeInOutCubicEmphasized,
                    switchOutCurve: Curves.easeInOutCubicEmphasized,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    ),
                    child: statusLabel == null
                        ? const SizedBox.shrink()
                        : Text(
                            statusLabel,
                            key: ValueKey(statusLabel),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: statusColor(),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                assignment.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                assignment.course,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: isPast && !completed
                        ? Colors.red
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Due: $dueString',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isPast && !completed
                          ? Colors.red
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: isPast && !completed
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    ),
                    child: completed
                        ? Row(
                            key: const ValueKey('completed'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 16,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '已完成',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(key: ValueKey('not')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
