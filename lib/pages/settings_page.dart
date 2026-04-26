import 'package:flutter/material.dart';

import '../services/service_provider.dart';
import 'debug_log_page.dart';
import 'login_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sp = ServiceProvider.of(context);
    final auth = sp.authService;
    final logger = sp.debugLogger;
    final storage = sp.storageService;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: Listenable.merge([auth, logger]),
        builder: (context, _) => ListView(
          children: [
            // Account section
            _sectionHeader(theme, 'Account'),
            if (auth.isLoggedIn) ...[
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(auth.session!.userName.isNotEmpty
                    ? auth.session!.userName
                    : auth.session!.userId),
                subtitle: Text(
                  [
                    auth.session!.schoolName,
                    if (auth.session!.phoneNumber.isNotEmpty)
                      auth.session!.phoneNumber,
                  ].join(' | '),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () => auth.logout(),
              ),
            ] else
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Login'),
                subtitle: const Text('Sign in to your campus account'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                ),
              ),
            const Divider(),

            // Appearance section
            _sectionHeader(theme, 'Appearance'),
            ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: const Text('Theme'),
              subtitle: const Text('System default'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Dynamic color'),
              subtitle: const Text('Use wallpaper colors'),
              trailing: Switch(value: true, onChanged: (_) {}),
            ),
            const Divider(),

            // General section
            _sectionHeader(theme, 'General'),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notifications'),
              subtitle: const Text('Manage notification preferences'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              subtitle: const Text('Version 1.0.0'),
              onTap: () {},
            ),
            const Divider(),

            // Developer section
            _sectionHeader(theme, 'Developer'),
            SwitchListTile(
              secondary: const Icon(Icons.bug_report_outlined),
              title: const Text('Debug mode'),
              subtitle: const Text('Log all API requests'),
              value: logger.enabled,
              onChanged: (value) {
                logger.enabled = value;
                storage.setDebugMode(value);
              },
            ),
            if (logger.enabled)
              ListTile(
                leading: const Icon(Icons.list_alt),
                title: const Text('View Logs'),
                subtitle: Text('${logger.entries.length} entries'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DebugLogPage()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
