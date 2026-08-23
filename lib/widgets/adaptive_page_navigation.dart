import 'package:flutter/material.dart';

/// Pushes a page using the standard Material navigation transition.
Future<T?> pushAdaptivePage<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  RouteSettings? settings,
}) {
  final navigator = Navigator.of(context);
  final route = MaterialPageRoute<T>(settings: settings, builder: builder);

  return navigator.push<T>(route);
}

/// Pops the current page through the active route.
Future<bool> maybePopAdaptivePage<T>(
  BuildContext context, [
  T? result,
]) {
  return Navigator.of(context).maybePop<T>(result);
}
