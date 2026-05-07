import 'package:flutter/material.dart';

import '../models/third_party_account.dart';
import '../services/service_provider.dart';
import '../services/third_party_auth_service.dart';

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
  final _hydroOriginCtrl =
      TextEditingController(text: 'https://acm.shanghaitech.edu.cn');
  final _hydroDomainsCtrl = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

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
    return Scaffold(
      appBar: AppBar(title: Text('Bind ${widget.platform.label}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
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
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '必填' : null,
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
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
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
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '必填' : null,
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
            const SizedBox(height: 24),
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
