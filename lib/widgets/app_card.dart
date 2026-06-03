import "package:flutter/material.dart";

import "../models/feature.dart";

class AppCard extends StatelessWidget {
  final List<Feature> features;
  final int rows;
  final ValueChanged<Feature>? onFeatureTap;

  const AppCard({
    super.key,
    required this.features,
    this.rows = 2,
    this.onFeatureTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (features.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const itemWidth = 72.0;
        final rawPerRow = ((constraints.maxWidth - 16) / itemWidth).floor();
        final effectivePerRow = rawPerRow < 1 ? 1 : rawPerRow;
        final visibleFeatures = features.take(effectivePerRow * rows - 1);
        return Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Wrap(
              runSpacing: 12,
              children: [
                for (final feature in [
                  ...visibleFeatures,
                  if (features.length > effectivePerRow * rows - 1) moreFeature,
                ])
                  SizedBox(
                    width: itemWidth,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        onFeatureTap?.call(feature);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconTheme(
                              data: IconThemeData(
                                color: theme.colorScheme.primary,
                                size: 28,
                              ),
                              child: feature.icon,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              feature.description,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
