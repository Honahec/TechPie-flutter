import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/service_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _sendingSms = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  Future<void> _sendSms() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    setState(() => _sendingSms = true);
    try {
      await ServiceProvider.of(context).authService.sendSmsCode(phone);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification code sent')),
        );
      }
      _startCooldown();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Send SMS failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingSms = false);
    }
  }

  void _startCooldown() {
    setState(() => _cooldown = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldown--;
        if (_cooldown <= 0) timer.cancel();
      });
    });
  }

  Future<void> _smsLogin() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    if (phone.isEmpty || code.isEmpty) return;

    try {
      await ServiceProvider.of(context).authService.smsLogin(phone, code);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e')),
        );
      }
    }
  }

  Future<void> _egateLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    if (username.isEmpty || password.isEmpty) return;

    try {
      await ServiceProvider.of(context).authService.egateLogin(username, password);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ServiceProvider.of(context).authService;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Login'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'SMS Login'),
              Tab(text: 'eGate Login'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildSmsTab(auth),
            _buildEgateTab(auth),
          ],
        ),
      ),
    );
  }

  Widget _buildSmsTab(AuthService auth) {
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'Verification code',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: (_cooldown > 0 || _sendingSms)
                        ? null
                        : _sendSms,
                    child: Text(
                      _cooldown > 0 ? '${_cooldown}s' : 'Send Code',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: auth.loading ? null : _smsLogin,
              child: auth.loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEgateTab(AuthService auth) {
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Student ID',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: auth.loading ? null : _egateLogin,
              child: auth.loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}
