import 'dart:async';

import 'package:flutter/material.dart';

import '../services/service_provider.dart';
import '../widgets/adaptive_feedback.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageCopy {
  const _LoginPageCopy({
    required this.pageTitle,
    required this.brandName,
    required this.subtitle,
  });

  final String pageTitle;
  final String brandName;
  final String subtitle;
}

const _loginPageCopy = _LoginPageCopy(
  pageTitle: '登录',
  brandName: 'TechPie',
  subtitle: '登录以访问校园服务',
);

Future<void> presentLoginPage(BuildContext context) async {
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => const LoginPage()),
  );
}

class _LoginPageState extends State<LoginPage> {
  bool _loading = false;

  Future<void> _geekpieLogin() async {
    setState(() {
      _loading = true;
    });

    try {
      final sp = ServiceProvider.of(context);
      final tokens = await sp.uniAuthService.login(context);
      await sp.authService.geekpieLogin(tokens);
      if (mounted) {
        unawaited(sp.scheduleService.fetchAll());
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showAdaptiveFeedback(
          context: context,
          message: '登录失败: $e',
          style: AdaptiveFeedbackStyle.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildMaterialLoginPage(context, _loginPageCopy);
  }

  Widget _buildMaterialLoginPage(BuildContext context, _LoginPageCopy copy) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Hero area
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.school_rounded,
                      size: 64,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      copy.brandName,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      copy.subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Single login button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    FilledButton.icon(
                      onPressed: _loading ? null : _geekpieLogin,
                      icon: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: const Text('通过 GeekPie Uni-Auth 登录'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
