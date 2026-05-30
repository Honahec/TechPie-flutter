import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/schedule_service.dart';
import '../services/service_provider.dart';
import '../utils/platform.dart';
import '../widgets/adaptive_feedback.dart';
import '../widgets/ios_liquid/ios_native_navigation_bar.dart';
import '../widgets/ios_liquid/ios_native_segmented_control.dart';
import '../widgets/ios_liquid/ios_native_text_field_group.dart';

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

const MethodChannel _nativeGlassPresenterChannel = MethodChannel(
  'techpie/native_glass_presenter',
);

Future<void> presentLoginPage(BuildContext context) async {
  if (isIos() && usesIosLiquidGlass()) {
    final sp = ServiceProvider.of(context);
    await _presentNativeLoginSheet(
      authService: sp.authService,
      scheduleService: sp.scheduleService,
    );
    return;
  }

  if (context.mounted) {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }
}

Future<void> _presentNativeLoginSheet({
  required AuthService authService,
  required ScheduleService scheduleService,
}) async {
  _nativeGlassPresenterChannel.setMethodCallHandler((call) async {
    final arguments = (call.arguments as Map<Object?, Object?>?) ?? const {};

    Future<Map<String, Object?>> runAction(
        Future<void> Function() action) async {
      try {
        await action();
        return const <String, Object?>{'ok': true};
      } catch (error) {
        return <String, Object?>{'ok': false, 'message': '$error'};
      }
    }

    switch (call.method) {
      case 'nativeLoginSheet.sendSms':
        final phone = (arguments['phone'] as String? ?? '').trim();
        return runAction(() => authService.sendSmsCode(phone));
      case 'nativeLoginSheet.smsLogin':
        final phone = (arguments['phone'] as String? ?? '').trim();
        final code = (arguments['code'] as String? ?? '').trim();
        return runAction(() async {
          await authService.smsLogin(phone, code);
          unawaited(scheduleService.fetchAll());
        });
      case 'nativeLoginSheet.egateLogin':
        final username = (arguments['username'] as String? ?? '').trim();
        final password = (arguments['password'] as String? ?? '').trim();
        return runAction(() async {
          await authService.egateLogin(username, password);
          unawaited(scheduleService.fetchAll());
        });
      default:
        throw MissingPluginException(
            'Unknown login sheet action ${call.method}');
    }
  });

  try {
    await _nativeGlassPresenterChannel.invokeMethod<void>(
      'presentLoginSheet',
      <String, Object?>{
        'pageTitle': _loginPageCopy.pageTitle,
        'brandName': _loginPageCopy.brandName,
        'subtitle': _loginPageCopy.subtitle,
      },
    );
  } finally {
    _nativeGlassPresenterChannel.setMethodCallHandler(null);
  }
}

class _LoginPageState extends State<LoginPage> with WidgetsBindingObserver {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _sendingSms = false;
  bool _obscurePassword = true;
  int _selectedLoginMethod = 0;
  int _cooldown = 0;
  Timer? _cooldownTimer;
  DateTime? _cooldownBackgroundedAt;
  String? _smsInlineMessage;
  String? _egateInlineMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _dismissKeyboard() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (isIos()) {
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    }
  }

  Future<void> _sendSms() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    setState(() => _sendingSms = true);
    try {
      await ServiceProvider.of(context).authService.sendSmsCode(phone);
      if (mounted && !isIos()) {
        showAdaptiveFeedback(
          context: context,
          message: '验证码已发送',
          style: AdaptiveFeedbackStyle.success,
        );
      }
      if (mounted) {
        setState(() => _smsInlineMessage = null);
        _startCooldown();
      }
    } catch (e) {
      if (mounted) {
        if (isIos()) {
          setState(() => _smsInlineMessage = '发送失败：$e');
        } else {
          showAdaptiveFeedback(
            context: context,
            message: '发送失败: $e',
            style: AdaptiveFeedbackStyle.error,
          );
        }
      }
    } finally {
      if (mounted) setState(() => _sendingSms = false);
    }
  }

  void _startCooldown() {
    _cooldownBackgroundedAt = null;
    setState(() => _cooldown = 60);
    _startCooldownTimer();
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _tickCooldown();
    });
  }

  void _tickCooldown() {
    if (_cooldown <= 1) {
      _completeCooldown();
      return;
    }

    setState(() => _cooldown--);
  }

  void _completeCooldown() {
    _cooldownTimer?.cancel();
    _cooldownBackgroundedAt = null;
    if (mounted) {
      setState(() => _cooldown = 0);
    } else {
      _cooldown = 0;
    }
  }

  void _pauseCooldownForBackground() {
    if (_cooldown <= 0 || _cooldownBackgroundedAt != null) return;
    _cooldownBackgroundedAt = DateTime.now();
    _cooldownTimer?.cancel();
  }

  void _resumeCooldownFromBackground() {
    final backgroundedAt = _cooldownBackgroundedAt;
    if (backgroundedAt == null || _cooldown <= 0) return;

    _cooldownBackgroundedAt = null;
    final elapsedSeconds = DateTime.now().difference(backgroundedAt).inSeconds;
    if (elapsedSeconds <= 0) {
      if (_cooldownTimer?.isActive != true) {
        _startCooldownTimer();
      }
      return;
    }

    final remaining = _cooldown - elapsedSeconds;
    if (remaining <= 0) {
      _completeCooldown();
      return;
    }

    setState(() => _cooldown = remaining);
    if (_cooldownTimer?.isActive != true) {
      _startCooldownTimer();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _pauseCooldownForBackground();
        break;
      case AppLifecycleState.resumed:
        _resumeCooldownFromBackground();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _smsLogin() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    if (phone.isEmpty || code.isEmpty) return;

    await _dismissKeyboard();
    if (!mounted) return;

    try {
      await ServiceProvider.of(context).authService.smsLogin(phone, code);
      if (mounted) {
        setState(() => _smsInlineMessage = null);
        ServiceProvider.of(context).scheduleService.fetchAll();
        await _dismissKeyboard();
        if (!mounted) return;
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        if (isIos()) {
          setState(() => _smsInlineMessage = '登录失败：$e');
        } else {
          showAdaptiveFeedback(
            context: context,
            message: '登录失败: $e',
            style: AdaptiveFeedbackStyle.error,
          );
        }
      }
    }
  }

  Future<void> _egateLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    if (username.isEmpty || password.isEmpty) return;

    await _dismissKeyboard();
    if (!mounted) return;

    try {
      await ServiceProvider.of(
        context,
      ).authService.egateLogin(username, password);
      if (mounted) {
        setState(() => _egateInlineMessage = null);
        ServiceProvider.of(context).scheduleService.fetchAll();
        await _dismissKeyboard();
        if (!mounted) return;
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        if (isIos()) {
          setState(() => _egateInlineMessage = '登录失败：$e');
        } else {
          showAdaptiveFeedback(
            context: context,
            message: '登录失败: $e',
            style: AdaptiveFeedbackStyle.error,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cooldownTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const copy = _loginPageCopy;
    if (isIos()) {
      return _buildIosLoginPage(context, copy);
    }

    return _buildMaterialLoginPage(context, copy);
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
              // Hero area with tonal surface
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

              const SizedBox(height: 24),

              // Login form
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      // Segmented-style tab bar
                      TabBar(
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: colorScheme.secondaryContainer,
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerHeight: 0,
                        labelColor: colorScheme.onSecondaryContainer,
                        unselectedLabelColor: colorScheme.onSurfaceVariant,
                        labelStyle: theme.textTheme.labelLarge,
                        tabs: const [
                          Tab(text: '短信登录'),
                          Tab(text: '统一身份认证'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 280,
                        child: TabBarView(
                          children: [
                            _SmsLoginForm(
                              phoneController: _phoneController,
                              codeController: _codeController,
                              cooldown: _cooldown,
                              sendingSms: _sendingSms,
                              inlineMessage: _smsInlineMessage,
                              onSendSms: _sendSms,
                              onLogin: _smsLogin,
                            ),
                            _EgateLoginForm(
                              usernameController: _usernameController,
                              passwordController: _passwordController,
                              obscurePassword: _obscurePassword,
                              inlineMessage: _egateInlineMessage,
                              onToggleObscure: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              onLogin: _egateLogin,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIosLoginPage(BuildContext context, _LoginPageCopy copy) {
    final theme = Theme.of(context);
    final canPop = Navigator.canPop(context);
    final liquidGlass = usesIosLiquidGlass();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: IosNativeNavigationBar(
        title: copy.pageTitle,
        leadingItems: [
          if (canPop)
            const IosNativeNavigationBarItem(
              id: 'back',
              title: '返回',
              sfSymbol: 'chevron.left',
              accessibilityLabel: '返回',
            ),
        ],
        onItemPressed: (id) {
          if (id == 'back') {
            Navigator.maybePop(context);
          }
        },
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(20, liquidGlass ? 4 : 12, 20, 28),
          children: [
            _IosLoginHeader(copy: copy, liquidGlass: liquidGlass),
            SizedBox(height: liquidGlass ? 20 : 18),
            IosNativeSegmentedControl(
              value: _selectedLoginMethod,
              segments: const ['短信', '统一认证'],
              onChanged: (value) {
                setState(() => _selectedLoginMethod = value);
              },
            ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _selectedLoginMethod == 0
                  ? _IosSmsLoginForm(
                      key: const ValueKey<String>('sms'),
                      phoneController: _phoneController,
                      codeController: _codeController,
                      cooldown: _cooldown,
                      sendingSms: _sendingSms,
                      inlineMessage: _smsInlineMessage,
                      onSendSms: _sendSms,
                      onLogin: _smsLogin,
                      liquidGlass: liquidGlass,
                    )
                  : _IosEgateLoginForm(
                      key: const ValueKey<String>('egate'),
                      usernameController: _usernameController,
                      passwordController: _passwordController,
                      obscurePassword: _obscurePassword,
                      inlineMessage: _egateInlineMessage,
                      onLogin: _egateLogin,
                      liquidGlass: liquidGlass,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IosLoginHeader extends StatelessWidget {
  const _IosLoginHeader({
    required this.copy,
    required this.liquidGlass,
  });

  final _LoginPageCopy copy;
  final bool liquidGlass;

  @override
  Widget build(BuildContext context) {
    final labelColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: EdgeInsets.only(
        left: 2,
        right: 2,
        top: liquidGlass ? 0 : 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.brandName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            copy.subtitle,
            style: TextStyle(
              color: labelColor,
              fontSize: liquidGlass ? 17 : 15,
              height: 1.25,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _IosSmsLoginForm extends StatelessWidget {
  final TextEditingController phoneController;
  final TextEditingController codeController;
  final int cooldown;
  final bool sendingSms;
  final String? inlineMessage;
  final VoidCallback onSendSms;
  final VoidCallback onLogin;
  final bool liquidGlass;

  const _IosSmsLoginForm({
    super.key,
    required this.phoneController,
    required this.codeController,
    required this.cooldown,
    required this.sendingSms,
    required this.inlineMessage,
    required this.onSendSms,
    required this.onLogin,
    required this.liquidGlass,
  });

  @override
  Widget build(BuildContext context) {
    final auth = ServiceProvider.of(context).authService;

    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _IosAdaptiveFormSection(
              children: [
                IosNativeTextFieldGroup(
                  items: [
                    IosNativeTextFieldGroupItem(
                      placeholder: '手机号码',
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: IosNativeTextFieldGroup(
                        items: [
                          IosNativeTextFieldGroupItem(
                            placeholder: '验证码',
                            controller: codeController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => onLogin(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _IosCodeButton(
                      cooldown: cooldown,
                      sendingSms: sendingSms,
                      onPressed: onSendSms,
                    ),
                  ],
                ),
              ],
            ),
            if (inlineMessage != null) ...[
              const SizedBox(height: 12),
              _IosInlineFeedback(message: inlineMessage!),
            ],
            const SizedBox(height: 18),
            _IosPrimaryButton(
              label: '登录',
              loading: auth.loading,
              onPressed: auth.loading ? null : onLogin,
              liquidGlass: liquidGlass,
            ),
          ],
        );
      },
    );
  }
}

class _IosEgateLoginForm extends StatelessWidget {
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final String? inlineMessage;
  final VoidCallback onLogin;
  final bool liquidGlass;

  const _IosEgateLoginForm({
    super.key,
    required this.usernameController,
    required this.passwordController,
    required this.obscurePassword,
    required this.inlineMessage,
    required this.onLogin,
    required this.liquidGlass,
  });

  @override
  Widget build(BuildContext context) {
    final auth = ServiceProvider.of(context).authService;

    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _IosAdaptiveFormSection(
              children: [
                IosNativeTextFieldGroup(
                  items: [
                    IosNativeTextFieldGroupItem(
                      placeholder: '学号',
                      controller: usernameController,
                      textInputAction: TextInputAction.next,
                    ),
                    IosNativeTextFieldGroupItem(
                      placeholder: '密码',
                      controller: passwordController,
                      obscureText: obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => onLogin(),
                    ),
                  ],
                ),
              ],
            ),
            if (inlineMessage != null) ...[
              const SizedBox(height: 12),
              _IosInlineFeedback(message: inlineMessage!),
            ],
            const SizedBox(height: 18),
            _IosPrimaryButton(
              label: '登录',
              loading: auth.loading,
              onPressed: auth.loading ? null : onLogin,
              liquidGlass: liquidGlass,
            ),
          ],
        );
      },
    );
  }
}

class _IosAdaptiveFormSection extends StatelessWidget {
  const _IosAdaptiveFormSection({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index < children.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _IosCodeButton extends StatelessWidget {
  const _IosCodeButton({
    required this.cooldown,
    required this.sendingSms,
    required this.onPressed,
  });

  final int cooldown;
  final bool sendingSms;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = cooldown > 0 || sendingSms;

    return TextButton(
      onPressed: disabled ? null : onPressed,
      child: sendingSms
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(cooldown > 0 ? '${cooldown}s' : '发送'),
    );
  }
}

class _IosPrimaryButton extends StatelessWidget {
  const _IosPrimaryButton({
    required this.label,
    required this.loading,
    required this.onPressed,
    required this.liquidGlass,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  final bool liquidGlass;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      child: SizedBox(
        height: liquidGlass ? 56 : 52,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) ...[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
            ],
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _IosInlineFeedback extends StatelessWidget {
  const _IosInlineFeedback({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final red = scheme.error;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 18, color: red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: red,
                  fontSize: 14,
                  height: 1.25,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmsLoginForm extends StatelessWidget {
  final TextEditingController phoneController;
  final TextEditingController codeController;
  final int cooldown;
  final bool sendingSms;
  final String? inlineMessage;
  final VoidCallback onSendSms;
  final VoidCallback onLogin;

  const _SmsLoginForm({
    required this.phoneController,
    required this.codeController,
    required this.cooldown,
    required this.sendingSms,
    required this.inlineMessage,
    required this.onSendSms,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    final auth = ServiceProvider.of(context).authService;

    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: phoneController,
            decoration: const InputDecoration(
              labelText: '手机号码',
              prefixIcon: Icon(Icons.phone_outlined),
              filled: true,
              border: UnderlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: '验证码',
                    prefixIcon: Icon(Icons.pin_outlined),
                    filled: true,
                    border: UnderlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonal(
                onPressed: (cooldown > 0 || sendingSms) ? null : onSendSms,
                style: FilledButton.styleFrom(minimumSize: const Size(100, 56)),
                child: sendingSms
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(cooldown > 0 ? '${cooldown}s' : '发送验证码'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (inlineMessage != null) ...[
            _InlineFormFeedback(message: inlineMessage!),
            const SizedBox(height: 16),
          ],
          FilledButton.icon(
            onPressed: auth.loading ? null : onLogin,
            icon: auth.loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: const Text('登录'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
          ),
        ],
      ),
    );
  }
}

class _EgateLoginForm extends StatelessWidget {
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final String? inlineMessage;
  final VoidCallback onToggleObscure;
  final VoidCallback onLogin;

  const _EgateLoginForm({
    required this.usernameController,
    required this.passwordController,
    required this.obscurePassword,
    required this.inlineMessage,
    required this.onToggleObscure,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    final auth = ServiceProvider.of(context).authService;

    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: usernameController,
            decoration: const InputDecoration(
              labelText: '学号',
              prefixIcon: Icon(Icons.badge_outlined),
              filled: true,
              border: UnderlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: passwordController,
            decoration: InputDecoration(
              labelText: '密码',
              prefixIcon: const Icon(Icons.lock_outline),
              filled: true,
              border: const UnderlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: onToggleObscure,
              ),
            ),
            obscureText: obscurePassword,
          ),
          const SizedBox(height: 32),
          if (inlineMessage != null) ...[
            _InlineFormFeedback(message: inlineMessage!),
            const SizedBox(height: 16),
          ],
          FilledButton.icon(
            onPressed: auth.loading ? null : onLogin,
            icon: auth.loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: const Text('登录'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineFormFeedback extends StatelessWidget {
  const _InlineFormFeedback({required this.message});

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
