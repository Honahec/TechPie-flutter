import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:techpie/utils/platform.dart';

/// AppBar with a fixed elevation and a Gaussian blur backdrop where supported.
///
/// Replaces Material 3's scroll-triggered elevation lift with a constant
/// surface. On iOS versions before Liquid Glass, this intentionally falls back
/// to an opaque title bar so controls don't float over content.
class BlurredAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BlurredAppBar({
    super.key,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.title,
    this.actions,
    this.bottom,
    this.centerTitle,
    this.titleSpacing,
    this.leadingWidth,
    this.elevation = 0,
    this.blurSigma = 24,
    this.backgroundOpacity = 0.50,
    this.foregroundColor,
  });

  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Widget? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool? centerTitle;
  final double? titleSpacing;
  final double? leadingWidth;
  final double elevation;
  final double blurSigma;
  final double backgroundOpacity;
  final Color? foregroundColor;

  @override
  Size get preferredSize => Size.fromHeight(
      adaptiveTopBarHeight() + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appBarTheme = theme.appBarTheme;
    final baseColor = appBarTheme.backgroundColor ?? theme.colorScheme.surface;

    if (usesLegacyIosChrome()) {
      return AppBar(
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        title: title,
        actions: actions,
        bottom: bottom,
        centerTitle: centerTitle,
        titleSpacing: titleSpacing,
        leadingWidth: leadingWidth,
        toolbarHeight: adaptiveTopBarHeight(),
        backgroundColor: baseColor,
        foregroundColor: foregroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: elevation,
        scrolledUnderElevation: elevation,
        shadowColor: Colors.transparent,
      );
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: AppBar(
          leading: leading,
          automaticallyImplyLeading: automaticallyImplyLeading,
          title: title,
          actions: actions,
          bottom: bottom,
          centerTitle: centerTitle,
          titleSpacing: titleSpacing,
          leadingWidth: leadingWidth,
          toolbarHeight: adaptiveTopBarHeight(),
          backgroundColor: baseColor.withValues(alpha: backgroundOpacity),
          foregroundColor: foregroundColor,
          surfaceTintColor: Colors.transparent,
          elevation: elevation,
          scrolledUnderElevation: elevation,
          shadowColor: theme.colorScheme.shadow,
        ),
      ),
    );
  }
}
