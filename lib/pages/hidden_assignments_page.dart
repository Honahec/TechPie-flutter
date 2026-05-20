import 'package:flutter/material.dart';

import '../models/assignment.dart';
import '../models/assignment_overrides.dart';
import '../services/assignment_service.dart';
import '../services/service_provider.dart';
import '../utils/platform.dart';
import '../widgets/blurred_app_bar.dart';
import '../widgets/ios_liquid/ios_glass_action_button.dart';

class HiddenAssignmentsPage extends StatefulWidget {
  const HiddenAssignmentsPage({super.key});

  @override
  State<HiddenAssignmentsPage> createState() => _HiddenAssignmentsPageState();
}

class _HiddenAssignmentsPageState extends State<HiddenAssignmentsPage> {
  bool _selectionMode = false;
  final Set<String> _selected = {};

  void _enterSelectionMode() {
    setState(() {
      _selectionMode = true;
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selected.clear();
    });
  }

  void _toggleSelection(String key) {
    setState(() {
      if (_selected.remove(key)) return;
      _selected.add(key);
    });
  }

  void _toggleSelectAll(List<String> allKeys) {
    setState(() {
      if (_selected.length == allKeys.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(allKeys);
      }
    });
  }

  void _restoreSelected() {
    final service = ServiceProvider.of(context).assignmentService;
    for (final key in _selected.toList()) {
      service.unhide(key);
    }
    _exitSelectionMode();
  }

  @override
  Widget build(BuildContext context) {
    final service = ServiceProvider.of(context).assignmentService;
    final theme = Theme.of(context);
    final topPad = kToolbarHeight + MediaQuery.viewPaddingOf(context).top;

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final hiddenKeys = service.overrides.hidden.toList();
        final selectedAll =
            hiddenKeys.isNotEmpty && _selected.length == hiddenKeys.length;

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: BlurredAppBar(
            automaticallyImplyLeading: !isIos(),
            leadingWidth: isIos() ? 0 : null,
            leading: isIos() ? const SizedBox.shrink() : null,
            centerTitle: false,
            titleSpacing: isIos() ? 8 : null,
            title: isIos()
                ? _HiddenAssignmentsTopContainer(
                    selectionMode: _selectionMode,
                    selectedAll: selectedAll,
                    hasItems: hiddenKeys.isNotEmpty,
                    hasSelection: _selected.isNotEmpty,
                    onBack: () => Navigator.maybePop(context),
                    onRestore: _restoreSelected,
                    onToggleSelectionMode: _selectionMode
                        ? _exitSelectionMode
                        : _enterSelectionMode,
                    onToggleSelectAll: hiddenKeys.isEmpty
                        ? null
                        : () => _toggleSelectAll(hiddenKeys),
                  )
                : const Text('已忽略的作业'),
            actions: isIos()
                ? null
                : [
                    if (_selectionMode)
                      _NavigationTextAction(
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.zero,
                        label: selectedAll ? 'Deselect All' : 'Select All',
                        width: selectedAll ? 124 : 108,
                        onPressed: hiddenKeys.isEmpty
                            ? null
                            : () => _toggleSelectAll(hiddenKeys),
                        usesIosLiquidGlass: false,
                      ),
                    if (_selectionMode)
                      IconButton(
                        tooltip: '恢复',
                        onPressed: _selected.isNotEmpty
                            ? _restoreSelected
                            : null,
                        icon: const Icon(Icons.restore),
                      ),
                    if (hiddenKeys.isNotEmpty)
                      _NavigationTextAction(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsetsDirectional.only(end: 12),
                        label: _selectionMode ? 'Done' : 'Select',
                        onPressed: _selectionMode
                            ? _exitSelectionMode
                            : _enterSelectionMode,
                        usesIosLiquidGlass: false,
                      ),
                  ],
          ),
          body: hiddenKeys.isEmpty
              ? Padding(
                  padding: EdgeInsets.only(top: topPad),
                  child: Center(
                    child: Text(
                      '没有被忽略的作业',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : _buildList(context, service, hiddenKeys, theme, topPad),
        );
      },
    );
  }

  Widget _buildList(
    BuildContext context,
    AssignmentService service,
    List<String> hiddenKeys,
    ThemeData theme,
    double topPad,
  ) {
    final lookup = <String, Assignment>{
      for (final a in service.assignments) AssignmentOverrides.keyFor(a): a,
    };
    return ListView.separated(
      padding: EdgeInsets.only(top: topPad),
      itemCount: hiddenKeys.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final key = hiddenKeys[i];
        final a = lookup[key];
        final selected = _selected.contains(key);

        return ListTile(
          selected: selected,
          selectedTileColor: theme.colorScheme.primaryContainer.withValues(
            alpha: 0.22,
          ),
          leading: _selectionMode
              ? Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                )
              : const Icon(Icons.visibility_off_outlined),
          title: Text(a?.title ?? key),
          subtitle: Text(
            a == null
                ? '(已无缓存数据)'
                : '${a.platform.toUpperCase()} · ${a.course}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: _selectionMode ? () => _toggleSelection(key) : null,
          onLongPress: _selectionMode
              ? null
              : () {
                  setState(() {
                    _selectionMode = true;
                    _selected.add(key);
                  });
                },
        );
      },
    );
  }
}

class _HiddenAssignmentsTopContainer extends StatelessWidget {
  const _HiddenAssignmentsTopContainer({
    required this.selectionMode,
    required this.selectedAll,
    required this.hasItems,
    required this.hasSelection,
    required this.onBack,
    required this.onRestore,
    required this.onToggleSelectionMode,
    required this.onToggleSelectAll,
  });

  final bool selectionMode;
  final bool selectedAll;
  final bool hasItems;
  final bool hasSelection;
  final VoidCallback onBack;
  final VoidCallback onRestore;
  final VoidCallback onToggleSelectionMode;
  final VoidCallback? onToggleSelectAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Row(
        children: [
          if (selectionMode)
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.centerLeft,
              child: IosGlassActionButton(
                label: selectedAll ? 'Deselect All' : 'Select All',
                sfSymbol: 'none',
                width: selectedAll ? 132 : 120,
                enabled: onToggleSelectAll != null,
                onPressed: onToggleSelectAll ?? () {},
              ),
            )
          else
            IosGlassActionButton(
              label: 'Deadlines',
              sfSymbol: 'chevron.left',
              width: 120,
              onPressed: onBack,
            ),
          const Spacer(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  axis: Axis.horizontal,
                  axisAlignment: 1,
                  child: child,
                ),
              );
            },
            child: selectionMode
                ? Row(
                    key: const ValueKey('restore-action'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IosGlassActionButton(
                        sfSymbol: 'arrow.uturn.backward',
                        width: 44,
                        enabled: hasSelection,
                        variant: IosGlassActionButtonVariant.glass,
                        onPressed: onRestore,
                      ),
                      const SizedBox(width: 16),
                    ],
                  )
                : const SizedBox(key: ValueKey('restore-action-hidden')),
          ),
          IosGlassActionButton(
            label: selectionMode ? 'Done' : 'Select',
            sfSymbol: 'none',
            width: 80,
            enabled: hasItems,
            onPressed: onToggleSelectionMode,
          ),
        ],
      ),
    );
  }
}

class _NavigationTextAction extends StatelessWidget {
  const _NavigationTextAction({
    required this.alignment,
    required this.padding,
    required this.label,
    required this.onPressed,
    required this.usesIosLiquidGlass,
    this.width,
  });

  final Alignment alignment;
  final EdgeInsetsGeometry padding;
  final String label;
  final VoidCallback? onPressed;
  final bool usesIosLiquidGlass;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final button = usesIosLiquidGlass
        ? const SizedBox.shrink()
        : AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOutCubic,
            alignment: alignment,
            child: SizedBox(
              width: width,
              child: TextButton(
                onPressed: onPressed,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  label,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                ),
              ),
            ),
          );

    return Align(
      alignment: alignment,
      child: Padding(padding: padding, child: button),
    );
  }
}
