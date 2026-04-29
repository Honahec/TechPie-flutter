import 'package:flutter/material.dart';

import '../app_destination.dart';
import 'desktop_sidebar_tokens.dart';

class DesktopSidebarItem extends StatelessWidget {
  final AppDestination destination;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  const DesktopSidebarItem({
    super.key,
    required this.destination,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = selected
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurfaceVariant;

    return LayoutBuilder(
      builder: (context, constraints) {
        final canShowLabel =
            !collapsed &&
            constraints.maxWidth >=
                DesktopSidebarTokens.iconColumnWidth +
                    DesktopSidebarTokens.navItemTextGap +
                    DesktopSidebarTokens.minLabelWidth;

        return Material(
          color: selected ? colorScheme.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(
            DesktopSidebarTokens.navItemRadius,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(
              DesktopSidebarTokens.navItemRadius,
            ),
            child: SizedBox(
              height: DesktopSidebarTokens.navItemHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(
                    width: DesktopSidebarTokens.iconColumnWidth,
                    child: Center(
                      child: Icon(
                        selected ? destination.selectedIcon : destination.icon,
                        size: DesktopSidebarTokens.navItemIconSize,
                        color: foreground,
                      ),
                    ),
                  ),
                  if (canShowLabel) ...[
                    const SizedBox(
                      width: DesktopSidebarTokens.navItemTextGap,
                    ),
                    Expanded(
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: foreground,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
