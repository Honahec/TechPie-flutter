import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/third_party_account.dart';
import '../services/service_provider.dart';
import '../services/third_party_auth_service.dart';
import '../widgets/adaptive_alert_dialog.dart';
import '../widgets/blurred_app_bar.dart';

class ThirdPartyBindPage extends StatefulWidget {
  final ThirdPartyPlatform platform;

  const ThirdPartyBindPage({super.key, required this.platform});

  @override
  State<ThirdPartyBindPage> createState() => _ThirdPartyBindPageState();
}

class _ThirdPartyBindPageState extends State<ThirdPartyBindPage> {
  final _formKey = GlobalKey<FormState>();
  final _accountCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _hydroOriginCtrl = TextEditingController(
    text: 'https://acm.shanghaitech.edu.cn',
  );
  final _hydroDomainsCtrl = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  bool _autoRenew = false;

  bool get _isHydro => widget.platform == ThirdPartyPlatform.hydro;
  bool get _isGradescope => widget.platform == ThirdPartyPlatform.gradescope;

  @override
  void dispose() {
    _accountCtrl.dispose();
    _passwordCtrl.dispose();
    _hydroOriginCtrl.dispose();
    _hydroDomainsCtrl.dispose();
    super.dispose();
  }

  Future<void> _onAutoRenewChanged(bool value) async {
    if (!value) {
      setState(() => _autoRenew = false);
      return;
    }
    final ok = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: '开启自动更新 Token',
      message:
          '自动更新 Token 已打开,APP 将于本地加密存储你的账号和密码信息,'
          '用于在过期前 48 小时内自动触发 Token 更新。\n\n'
          '凭据仅存放在本设备的 Keychain / EncryptedSharedPreferences 中,'
          '不会上传到服务器。',
      actions: const [
        AdaptiveAlertAction<bool>(label: '取消', value: false),
        AdaptiveAlertAction<bool>(
          label: '我知道了,开启',
          value: true,
          isDefault: true,
        ),
      ],
    );
    if (!mounted) return;
    setState(() => _autoRenew = ok == true);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    final tpAuth = ServiceProvider.of(context).thirdPartyAuthService;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    List<String>? domains;
    if (_isHydro) {
      domains = _hydroDomainsCtrl.text
          .split(RegExp(r'[\s,]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    try {
      await tpAuth.bind(
        platform: widget.platform,
        account: _accountCtrl.text.trim(),
        password: _passwordCtrl.text,
        hydroOrigin: _isHydro ? _hydroOriginCtrl.text.trim() : null,
        hydroDomains: domains,
        autoRenew: _autoRenew,
      );
      messenger.showSnackBar(
        SnackBar(content: Text('${widget.platform.label} 绑定成功')),
      );
      navigator.pop();
    } on ThirdPartyBindException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usesIosControls =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: BlurredAppBar(title: Text('Bind ${widget.platform.label}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16 + kToolbarHeight + MediaQuery.viewPaddingOf(context).top,
            16,
            16,
          ),
          children: [
            TextFormField(
              controller: _accountCtrl,
              autofillHints: const [AutofillHints.username],
              keyboardType: _isGradescope
                  ? TextInputType.emailAddress
                  : TextInputType.text,
              decoration: InputDecoration(
                labelText: _isGradescope ? '邮箱' : '用户名',
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? '必填' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordCtrl,
              autofillHints: const [AutofillHints.password],
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: '密码',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? '必填' : null,
            ),
            if (_isHydro) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _hydroOriginCtrl,
                decoration: const InputDecoration(
                  labelText: 'Hydro 站点 origin',
                  helperText: '默认 https://acm.shanghaitech.edu.cn',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? '必填' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _hydroDomainsCtrl,
                minLines: 2,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: '课程 domain (每行一个,或用逗号分隔)',
                  helperText: '例: SI100B_2025_Autumn',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (v) {
                  final list = (v ?? '')
                      .split(RegExp(r'[\s,]+'))
                      .where((e) => e.trim().isNotEmpty);
                  return list.isEmpty ? '至少填一个 domain' : null;
                },
              ),
            ],
            const SizedBox(height: 8),
            if (usesIosControls)
              MergeSemantics(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('自动更新 Token'),
                  subtitle: const Text('过期前 48 小时内自动重登,免去手动重绑'),
                  trailing: CupertinoSwitch(
                    value: _autoRenew,
                    onChanged: _onAutoRenewChanged,
                  ),
                  onTap: () => _onAutoRenewChanged(!_autoRenew),
                ),
              )
            else
              CheckboxListTile(
                value: _autoRenew,
                onChanged: (v) => _onAutoRenewChanged(v ?? false),
                title: const Text('自动更新 Token'),
                subtitle: const Text('过期前 48 小时内自动重登,免去手动重绑'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('绑定'),
            ),
            const SizedBox(height: 12),
            Text(
              '凭据将通过 HTTPS 发送到 techpie 后端,后端代为登录上游平台并返回 token。'
              'token 与原始 payload 仅在本设备加密保存。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
