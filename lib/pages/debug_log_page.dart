import 'package:flutter/material.dart';

import '../services/debug_logger.dart';
import '../services/service_provider.dart';

class DebugLogPage extends StatelessWidget {
  const DebugLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logger = ServiceProvider.of(context).debugLogger;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: logger.clear,
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: logger,
        builder: (context, _) {
          final entries = logger.entries.reversed.toList();
          if (entries.isEmpty) {
            return const Center(child: Text('No logs yet'));
          }
          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) => _LogTile(entry: entries[index]),
          );
        },
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final LogEntry entry;
  const _LogTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = entry.error != null;
    final statusColor = hasError
        ? theme.colorScheme.error
        : (entry.statusCode != null && entry.statusCode! >= 200 && entry.statusCode! < 300)
            ? Colors.green
            : theme.colorScheme.onSurface;

    return ExpansionTile(
      leading: Text(
        entry.method,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      title: Text(
        entry.url,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      subtitle: Row(
        children: [
          if (entry.statusCode != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(30),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${entry.statusCode}',
                style: theme.textTheme.labelSmall?.copyWith(color: statusColor),
              ),
            ),
          if (entry.tag != null)
            Text(entry.tag!, style: theme.textTheme.labelSmall),
          const Spacer(),
          Text(
            '${entry.timestamp.hour.toString().padLeft(2, '0')}:'
            '${entry.timestamp.minute.toString().padLeft(2, '0')}:'
            '${entry.timestamp.second.toString().padLeft(2, '0')}',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
      children: [
        if (entry.requestBody != null)
          _DetailSection(title: 'Request', content: entry.requestBody!),
        if (entry.responseBody != null)
          _DetailSection(title: 'Response', content: entry.responseBody!),
        if (entry.error != null)
          _DetailSection(title: 'Error', content: entry.error!),
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final String content;
  const _DetailSection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              content,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
