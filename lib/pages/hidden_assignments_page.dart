import 'package:flutter/material.dart';

import '../models/assignment.dart';
import '../models/assignment_overrides.dart';
import '../services/service_provider.dart';
import '../widgets/blurred_app_bar.dart';

class HiddenAssignmentsPage extends StatelessWidget {
  const HiddenAssignmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = ServiceProvider.of(context).assignmentService;
    final theme = Theme.of(context);
    final topPad = kToolbarHeight + MediaQuery.viewPaddingOf(context).top;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: BlurredAppBar(
        title: const Text('已忽略的作业'),
        actions: [
          ListenableBuilder(
            listenable: service,
            builder: (context, _) {
              if (service.overrides.hidden.isEmpty) return const SizedBox();
              return TextButton(
                onPressed: () => service.unhideAll(),
                child: const Text('全部恢复'),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: service,
        builder: (context, _) {
          final hiddenKeys = service.overrides.hidden;
          if (hiddenKeys.isEmpty) {
            return Padding(
              padding: EdgeInsets.only(top: topPad),
              child: Center(
                child: Text(
                  '没有被忽略的作业',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }

          // Look up cached assignment metadata for each hidden key.
          final lookup = <String, Assignment>{
            for (final a in service.assignments) AssignmentOverrides.keyFor(a): a,
          };

          final entries = hiddenKeys.toList();

          return ListView.separated(
            padding: EdgeInsets.only(top: topPad),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final key = entries[i];
              final a = lookup[key];
              return ListTile(
                leading: const Icon(Icons.visibility_off_outlined),
                title: Text(a?.title ?? key),
                subtitle: Text(
                  a == null
                      ? '(已无缓存数据)'
                      : '${a.platform.toUpperCase()} · ${a.course}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: TextButton.icon(
                  icon: const Icon(Icons.restore, size: 18),
                  label: const Text('恢复'),
                  onPressed: () => service.unhide(key),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
