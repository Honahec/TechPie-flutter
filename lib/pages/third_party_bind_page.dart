import 'dart:async';

import 'package:flutter/material.dart';

import '../models/third_party_account.dart';
import '../services/service_provider.dart';
import '../services/third_party_auth_service.dart';
import '../utils/platform.dart';
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
  String? _inlineError;

  // cpdaily SMS state
  int _cpdailyLoginMethod = 0; // 0 = password, 1 = SMS
  final _cpdailyPhoneCtrl = TextEditingController();
  final _cpdailyCodeCtrl = TextEditingController();
  bool _sendingSms = false;
  int _smsCooldown = 0;
  Timer? _smsCooldownTimer;

  bool get _isHydro => widget.platform == ThirdPartyPlatform.hydro;
  bool get _isGradescope => widget.platform == ThirdPartyPlatform.gradescope;
  bool get _isCpdaily => widget.platform == ThirdPartyPlatform.cpdaily;

  Future<void> _dismissKeyboard() async {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  void dispose() {
    _accountCtrl.dispose();
    _passwordCtrl.dispose();
    _hydroOriginCtrl.dispose();
    _hydroDomainsCtrl.dispose();
    _cpdailyPhoneCtrl.dispose();
    _cpdailyCodeCtrl.dispose();
    _smsCooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _onAutoRenewChanged(bool value) async {
    if (!value) {
      setState(() => _autoRenew = false);
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('开启自动更新 Token'),
        content: const Text(
          '打开后，APP 将于本地加密存储你的账号和密码信息,用于在过期前 48 小时内自动触发 Token 更新。\n\n'
          '凭据存放在本设备的 Keychain / EncryptedSharedPreferences 中。若开启云同步，密码也会被端到端加密后备份至 Casdoor(仅你能用主密码解密)。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('我知道了,开启'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    setState(() => _autoRenew = ok == true);
  }

  // -- cpdaily SMS methods --

  Future<void> _sendCpdailySms() async {
    final phone = _cpdailyPhoneCtrl.text.trim();
    if (phone.isEmpty) return;

    setState(() => _sendingSms = true);
    try {
      await ServiceProvider.of(context)
          .thirdPartyAuthService
          .sendCpdailySmsCode(phone);
      if (mounted) {
        setState(() => _inlineError = null);
        _smsCooldown = 60;
        _smsCooldownTimer?.cancel();
        _smsCooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted) {
            t.cancel();
            return;
          }
          if (_smsCooldown <= 1) {
            t.cancel();
            setState(() => _smsCooldown = 0);
          } else {
            setState(() => _smsCooldown--);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _inlineError = '发送失败：$e');
      }
    } finally {
      if (mounted) setState(() => _sendingSms = false);
    }
  }

  Future<void> _submit() async {
    if (!_validateForSubmit()) return;
    await _dismissKeyboard();
    if (!mounted) return;
    setState(() => _busy = true);

    final tpAuth = ServiceProvider.of(context).thirdPartyAuthService;

    List<String>? domains;
    if (_isHydro) {
      domains = _hydroDomainsCtrl.text
          .split(RegExp(r'[\s,]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    try {
      if (_isCpdaily && _cpdailyLoginMethod == 1) {
        // SMS mode
        await tpAuth.bindCpdailySms(
          phone: _cpdailyPhoneCtrl.text.trim(),
          code: _cpdailyCodeCtrl.text.trim(),
        );
      } else {
        await tpAuth.bind(
          platform: widget.platform,
          account: _accountCtrl.text.trim(),
          password: _passwordCtrl.text,
          hydroOrigin: _isHydro ? _hydroOriginCtrl.text.trim() : null,
          hydroDomains: domains,
          autoRenew: _autoRenew,
        );
      }
      if (!mounted) return;
      setState(() => _inlineError = null);
      await _dismissKeyboard();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.platform.label} 绑定成功')),
      );
      Navigator.of(context).pop();
    } on ThirdPartyBindException catch (e) {
      if (!mounted) return;
      setState(() => _inlineError = e.message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _inlineError = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _validateForSubmit() {
    setState(() => _inlineError = null);
    return _formKey.currentState?.validate() ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final topInset =
        16 + adaptiveTopBarHeight() + MediaQuery.viewPaddingOf(context).top;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: BlurredAppBar(title: Text('Bind ${widget.platform.label}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            topInset,
            16,
            16,
          ),
          children: [
            if (_inlineError != null) ...[
              _InlineBindFeedback(message: _inlineError!),
              const SizedBox(height: 12),
            ],
            if (_isCpdaily) ...[
              // cpdaily: tabbed password / SMS interface
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('密码登录')),
                  ButtonSegment(value: 1, label: Text('短信登录')),
                ],
                selected: {_cpdailyLoginMethod},
                onSelectionChanged: (v) =>
                    setState(() => _cpdailyLoginMethod = v.first),
              ),
              const SizedBox(height: 16),
              if (_cpdailyLoginMethod == 0) ...[
                TextFormField(
                  controller: _accountCtrl,
                  decoration: const InputDecoration(
                    labelText: '学号',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '必填' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
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
              ] else ...[
                TextFormField(
                  controller: _cpdailyPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: '手机号码',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '必填' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cpdailyCodeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '验证码',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? '必填' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonal(
                      onPressed: (_smsCooldown > 0 || _sendingSms)
                          ? null
                          : () => unawaited(_sendCpdailySms()),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(100, 56),
                      ),
                      child: _sendingSms
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _smsCooldown > 0 ? '${_smsCooldown}s' : '发送验证码',
                            ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
            ] else ...[
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
              const SizedBox(height: 8),
            ],
            CheckboxListTile(
              value: _autoRenew,
              onChanged: (v) => unawaited(_onAutoRenewChanged(v ?? false)),
              title: const Text('自动更新 Token'),
              subtitle: const Text('过期前 48 小时内自动重登,免去手动重绑'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : () => unawaited(_submit()),
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
              'token 与原始 payload 在本设备加密保存;开启云同步后会以端到端加密形式备份至 Casdoor。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineBindFeedback extends StatelessWidget {
  const _InlineBindFeedback({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 18, color: scheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
