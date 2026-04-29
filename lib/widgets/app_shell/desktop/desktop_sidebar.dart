import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../app_destination.dart';
import 'desktop_sidebar_item.dart';
import 'desktop_sidebar_tokens.dart';

class DesktopSidebar extends StatelessWidget {
  final List<AppDestination> destinations;
  final int selectedIndex;
  final bool collapsed;
  final bool showToggleButton;
  final ValueChanged<int> onSelected;
  final VoidCallback onToggleCollapsed;

  const DesktopSidebar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.collapsed,
    this.showToggleButton = true,
    required this.onSelected,
    required this.onToggleCollapsed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final horizontalPadding = collapsed
        ? DesktopSidebarTokens.collapsedHorizontalPadding
        : DesktopSidebarTokens.expandedHorizontalPadding;
    final itemSpacing = DesktopSidebarTokens.navItemSpacing;

    return ColoredBox(
      color: colorScheme.surfaceContainerLow,
      child: SafeArea(
        right: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SidebarDragHeader(
              horizontalPadding: horizontalPadding,
              collapsed: collapsed,
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  DesktopSidebarTokens.navTopPadding,
                  horizontalPadding,
                  DesktopSidebarTokens.navBottomPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (
                      int index = 0;
                      index < destinations.length;
                      index++
                    ) ...[
                      DesktopSidebarItem(
                        destination: destinations[index],
                        selected: index == selectedIndex,
                        collapsed: collapsed,
                        onTap: () => onSelected(index),
                      ),
                      if (index < destinations.length - 1)
                        SizedBox(height: itemSpacing),
                    ],
                    const Spacer(),
                    if (showToggleButton)
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: _SidebarToggleButton(
                          collapsed: collapsed,
                          onPressed: onToggleCollapsed,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarDragHeader extends StatelessWidget {
  final double horizontalPadding;
  final bool collapsed;

  const _SidebarDragHeader({
    required this.horizontalPadding,
    required this.collapsed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: DesktopSidebarTokens.headerHeight,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          DesktopSidebarTokens.headerTopPadding,
          horizontalPadding,
          DesktopSidebarTokens.headerBottomPadding,
        ),
        child: DragToMoveArea(child: _SidebarBrand(collapsed: collapsed)),
      ),
    );
  }
}

class _SidebarBrand extends StatelessWidget {
  final bool collapsed;

  const _SidebarBrand({required this.collapsed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final foreground = colorScheme.primary;

    return SizedBox(
      height: DesktopSidebarTokens.brandHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canShowLabel =
              !collapsed &&
              constraints.maxWidth >=
                  DesktopSidebarTokens.iconColumnWidth +
                      DesktopSidebarTokens.brandTextGap +
                      DesktopSidebarTokens.minLabelWidth;

          return Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(
                width: DesktopSidebarTokens.iconColumnWidth,
                child: Center(
                  child: Icon(
                    Icons.school_rounded,
                    size: DesktopSidebarTokens.brandIconSize,
                    color: foreground,
                  ),
                ),
              ),
              if (canShowLabel) ...[
                const SizedBox(width: DesktopSidebarTokens.brandTextGap),
                Expanded(
                  child: Text(
                    'TechPie',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SidebarToggleButton extends StatelessWidget {
  final bool collapsed;
  final VoidCallback onPressed;

  const _SidebarToggleButton({
    required this.collapsed,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      tooltip: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
      onPressed: onPressed,
      icon: SizedBox(
        width: DesktopSidebarTokens.iconColumnWidth,
        height: DesktopSidebarTokens.navItemHeight,
        child: Center(
          child: Icon(
            Icons.menu_rounded,
            size: DesktopSidebarTokens.toggleIconSize,
          ),
        ),
      ),
      style: IconButton.styleFrom(
        fixedSize: const Size(
          DesktopSidebarTokens.iconColumnWidth,
          DesktopSidebarTokens.navItemHeight,
        ),
        minimumSize: const Size(
          DesktopSidebarTokens.iconColumnWidth,
          DesktopSidebarTokens.navItemHeight,
        ),
        padding: EdgeInsets.zero,
        foregroundColor: colorScheme.onSurfaceVariant,
        backgroundColor: Colors.transparent,
        hoverColor: colorScheme.surfaceContainerHighest,
        highlightColor: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            DesktopSidebarTokens.navItemRadius,
          ),
        ),
      ),
    );
  }
}
