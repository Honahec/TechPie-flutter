import 'dart:async';

import 'package:flutter/material.dart';

import '../services/service_provider.dart';
import '../services/sync_service.dart';
import '../utils/platform.dart';
import '../widgets/adaptive_button.dart';
import '../widgets/app_shell/app_shell_metrics.dart';
import '../widgets/blurred_app_bar.dart';

/// Cloud-sync settings: turn sync on/off, set / restore / change the master
/// password, and trigger a manual pull. All cryptography + Casdoor I/O lives
/// in [SyncService]; this page is pure orchestration + dialogs.
class SyncSettingsPage extends StatefulWidget {
  const SyncSettingsPage({super.key});

  @override
  State<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends State<SyncSettingsPage> {
  String? _busyAction;

  bool get _busy => _busyAction != null;

  @override
  Widget build(BuildContext context) {
    final sp = ServiceProvider.of(context);
    final sync = sp.syncService;
    final topInset =
        adaptiveTopBarHeight() + MediaQuery.viewPaddingOf(context).top;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const BlurredAppBar(title: Text('Cloud sync')),
      body: ListenableBuilder(
        listenable: sync,
        builder: (context, _) {
          return ListView(
            padding: EdgeInsets.only(
              top: topInset,
              bottom: AppShellMetrics.bottomContentPaddingOf(context),
            ),
            children: [
              _ExplanationCard(enabled: sync.enabled),
              const SizedBox(height: 8),
              if (sync.enabled) ...[
                _statusTile(sync),
                _actionPanel([
                  _actionButton(
                    id: 'pull',
                    label: '立即从云端恢复',
                    subtitle: '用云端备份覆盖本设备绑定',
                    icon: Icons.download_for_offline_outlined,
                    onPressed: () => unawaited(_pull(sync)),
                  ),
                  _actionButton(
                    id: 'push',
                    label: '立即备份到云端',
                    subtitle: '用本设备绑定覆盖云端备份',
                    icon: Icons.upload_outlined,
                    role: AdaptiveButtonRole.prominent,
                    onPressed: () => unawaited(_push(sync)),
                  ),
                  _actionButton(
                    id: 'password',
                    label: '修改主密码',
                    icon: Icons.lock_outline,
                    role: AdaptiveButtonRole.plain,
                    onPressed: () => unawaited(_changePassword(sync)),
                  ),
                  _actionButton(
                    id: 'disable',
                    label: '关闭云同步',
                    subtitle: '清除云端备份与本设备主密码',
                    icon: Icons.cloud_off_outlined,
                    role: AdaptiveButtonRole.destructive,
                    onPressed: () => unawaited(_disable(sync)),
                  ),
                ]),
              ] else ...[
                _actionPanel([
                  _actionButton(
                    id: 'restore',
                    label: '从云端恢复',
                    subtitle: '已有备份时输入主密码恢复',
                    icon: Icons.lock_reset_outlined,
                    onPressed: () => unawaited(_restore(sync)),
                  ),
                  _actionButton(
                    id: 'setup',
                    label: '开启并备份',
                    subtitle: '首次设置主密码并加密上传',
                    icon: Icons.cloud_upload_outlined,
                    role: AdaptiveButtonRole.prominent,
                    onPressed: () => unawaited(_setup(sync)),
                  ),
                ]),
              ],
              if (sync.needsRestore)
                _RestoreBanner(
                  onTap: _busy ? null : () => unawaited(_restore(sync)),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _statusTile(SyncService sync) {
    final at = sync.lastSyncAt;
    String label;
    if (at == null) {
      label = '已开启 · 尚未同步';
    } else {
      String two(int n) => n.toString().padLeft(2, '0');
      label =
          '已开启 · 上次同步 ${at.year}-${two(at.month)}-${two(at.day)} ${two(at.hour)}:${two(at.minute)}';
    }
    return ListTile(
      leading: const Icon(Icons.sync),
      title: const Text('同步状态'),
      subtitle: Text(label),
    );
  }

  Widget _actionPanel(List<Widget> actions) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < actions.length; index++) ...[
            if (index > 0) const SizedBox(height: 10),
            actions[index],
          ],
        ],
      ),
    );
  }

  Widget _actionButton({
    required String id,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    String? subtitle,
    AdaptiveButtonRole role = AdaptiveButtonRole.standard,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdaptiveButton(
          label: label,
          icon: icon,
          role: role,
          height: 44,
          loading: _busyAction == id,
          onPressed: _busy ? null : onPressed,
          accessibilityLabel: label,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // -- Actions -----------------------------------------------------------------

  Future<void> _guard(
    String action,
    Future<void> Function() task,
  ) async {
    setState(() => _busyAction = action);
    try {
      await task();
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  Future<void> _setup(SyncService sync) async {
    final pwd = await _askMasterPassword(
      title: '设置主密码',
      confirm: true,
      warning: _e2eExplanation,
    );
    if (pwd == null) return;
    await _guard('setup', () async {
      final outcome = await sync.setupWithMasterPassword(pwd);
      _feedback(outcome);
    });
  }

  Future<void> _restore(SyncService sync) async {
    final pwd = await _askMasterPassword(
      title: '输入主密码恢复',
      confirm: false,
      warning: _e2eExplanation,
    );
    if (pwd == null) return;
    await _guard('restore', () async {
      final outcome = await sync.restoreWithMasterPassword(pwd);
      _feedback(outcome);
    });
  }

  Future<void> _changePassword(SyncService sync) async {
    final oldPwd = await _askMasterPassword(
      title: '当前主密码',
      confirm: false,
      warning: null,
    );
    if (oldPwd == null) return;
    final newPwd = await _askMasterPassword(
      title: '设置新主密码',
      confirm: true,
      warning: _e2eExplanation,
    );
    if (newPwd == null) return;
    await _guard('password', () async {
      final outcome = await sync.changeMasterPassword(oldPwd, newPwd);
      _feedback(outcome);
    });
  }

  Future<void> _disable(SyncService sync) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关闭云同步？'),
        content: const Text(
          '将清除云端加密备份与本设备主密码。本设备上的绑定不受影响；其它设备将无法再从云端恢复。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _guard('disable', () async {
      final outcome = await sync.disable();
      _feedback(outcome);
    });
  }

  Future<void> _pull(SyncService sync) async {
    await _guard('pull', () async {
      try {
        await sync.pull();
        _toast('已从云端恢复绑定');
      } on NeedMasterPassword {
        _toast('需要主密码，请在下方输入');
      } catch (_) {
        _toast('恢复失败，请检查网络或重新登录');
      }
    });
  }

  Future<void> _push(SyncService sync) async {
    await _guard('push', () async {
      final res = await sync.push();
      if (res.ok) {
        _toast('已备份到云端');
      } else {
        // Surface Casdoor's real reason (e.g. "Unauthorized operation") so the
        // user knows whether it's a network/authz/permission issue.
        _toast(res.describe('备份失败'));
      }
    });
  }

  void _feedback(SyncOutcome outcome) {
    _toast(outcome.message);
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<String?> _askMasterPassword({
    required String title,
    required bool confirm,
    required String? warning,
  }) async {
    final passwordController = TextEditingController();
    final confirmationController = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (warning != null) ...[
                Text(warning),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: passwordController,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: '主密码',
                  errorText: error,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (confirm) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: confirmationController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '再次输入',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final password = passwordController.text;
                if (password.isEmpty) {
                  setDialogState(() => error = '主密码不能为空');
                } else if (confirm && password != confirmationController.text) {
                  setDialogState(() => error = '两次输入不一致');
                } else {
                  Navigator.pop(dialogContext, password);
                }
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
    passwordController.dispose();
    confirmationController.dispose();
    return result;
  }
}

const String _e2eExplanation =
    '启用后，你的 eGate 会话(含 CASTGC)、Gradescope/Hydro token 及(若开启自动续期)密码'
    '将以端到端加密形式存于 Casdoor，仅你能用主密码解密，TechPie 与 Casdoor 服务器均无法读取。'
    '请妥善保管主密码——遗忘将无法在其它设备恢复。';

class _ExplanationCard extends StatelessWidget {
  final bool enabled;
  const _ExplanationCard({required this.enabled});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  enabled ? Icons.cloud_done_outlined : Icons.lock_outline,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text('端到端加密云同步', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '把第三方账号绑定(eGate / Gradescope / Hydro)加密备份到 Casdoor，'
              '跟随你的 GeekPie 账号在设备间同步。用一个你设定的主密码派生密钥加密，'
              '服务器只存密文，无法读取。换设备登录后输入主密码即可恢复全部绑定。',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _RestoreBanner extends StatelessWidget {
  final VoidCallback? onTap;
  const _RestoreBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.filled(
      margin: const EdgeInsets.all(16),
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cloud_download_outlined,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '云端有可恢复的备份',
                    style: TextStyle(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '检测到其它设备设置了云同步，输入主密码即可恢复绑定。',
              style: TextStyle(
                color: theme.colorScheme.onSecondaryContainer.withValues(
                  alpha: 0.8,
                ),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            AdaptiveButton(
              label: '恢复备份',
              icon: Icons.cloud_download_outlined,
              role: AdaptiveButtonRole.prominent,
              onPressed: onTap,
              accessibilityLabel: '恢复云端备份',
            ),
          ],
        ),
      ),
    );
  }
}
