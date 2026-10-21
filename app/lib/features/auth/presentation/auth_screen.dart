import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/locations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/zaba_wordmark.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/auth_providers.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_rules.dart';
import '../../../core/widgets/failure_box.dart';
import 'auth_messages.dart';

enum AuthMode { login, register }

/// Sign in and registration share one form. After a success the screen leaves
/// for [returnTo]. (The router's redirect cannot do it: for a page that was
/// pushed on top of another, it only ever looks at the page underneath.)
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, required this.mode, this.returnTo});

  final AuthMode mode;

  /// Where the person was heading when the app asked them to sign in.
  final String? returnTo;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  var _showPassword = false;
  var _busy = false;
  var _checkWhileTyping = false;
  AuthFailureReason? _failure;

  bool get _isLogin => widget.mode == AuthMode.login;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<Object?> Function(AuthRepository repository) call,
  ) async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await call(ref.read(authRepositoryProvider));
      if (mounted) {
        _leave();
      }
    } on AuthFailure catch (failure) {
      if (mounted) {
        setState(() => _failure = failure.reason);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// Signed in: on to where the person was heading, keeping the screens below
  /// this one (a cart, a tab) in place.
  void _leave() {
    final target = widget.returnTo ?? '/profile';
    if (isTabLocation(target)) {
      context.go(target);
    } else {
      context.pushReplacement(target);
    }
  }

  void _submit() {
    if (_busy) {
      return;
    }
    setState(() => _checkWhileTyping = true);
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _run(
      (repository) => _isLogin
          ? repository.signIn(email: _email.text, password: _password.text)
          : repository.signUp(
              email: _email.text,
              password: _password.text,
              fullName: _name.text,
            ),
    );
  }

  void _signInWithDemoAccount(DemoCredentials demo) {
    if (_busy) {
      return;
    }
    _run(
      (repository) =>
          repository.signIn(email: demo.email, password: demo.password),
    );
  }

  void _switchMode() {
    final target = Uri(
      path: _isLogin ? '/register' : '/login',
      queryParameters: {if (widget.returnTo != null) 'from': widget.returnTo},
    );
    context.pushReplacement(target.toString());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final demo = ref.watch(demoCredentialsProvider);
    final headsToCheckout = widget.returnTo?.startsWith('/checkout') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? l10n.authLoginTitle : l10n.authRegisterTitle),
      ),
      body: SafeArea(
        // Top-aligned: on a phone the keyboard takes the lower half, and a form
        // floating in the middle of a tall screen looks lost.
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  autovalidateMode: _checkWhileTyping
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: ZabaWordmark()),
                      const SizedBox(height: AppSpacing.lg),
                      if (headsToCheckout) ...[
                        Text(
                          l10n.authCheckoutHint,
                          style: textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (!_isLogin) ...[
                        TextFormField(
                          controller: _name,
                          enabled: !_busy,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(maxFullNameLength),
                          ],
                          decoration: InputDecoration(
                            labelText: l10n.authNameLabel,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      TextFormField(
                        controller: _email,
                        enabled: !_busy,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: InputDecoration(
                          labelText: l10n.authEmailLabel,
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return l10n.authEmailRequired;
                          }
                          return isPlausibleEmail(text)
                              ? null
                              : l10n.authEmailInvalid;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _password,
                        enabled: !_busy,
                        obscureText: !_showPassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: [
                          _isLogin
                              ? AutofillHints.password
                              : AutofillHints.newPassword,
                        ],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: l10n.authPasswordLabel,
                          helperText: _isLogin
                              ? null
                              : l10n.authPasswordHelper(minPasswordLength),
                          suffixIcon: IconButton(
                            tooltip: _showPassword
                                ? l10n.authHidePassword
                                : l10n.authShowPassword,
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                          ),
                        ),
                        validator: (value) {
                          final text = value ?? '';
                          if (text.isEmpty) {
                            return l10n.authPasswordRequired;
                          }
                          if (!_isLogin && text.length < minPasswordLength) {
                            return l10n.authPasswordTooShort(minPasswordLength);
                          }
                          return null;
                        },
                      ),
                      if (_failure != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        FailureBox(
                          message: authFailureMessage(l10n, _failure!),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                _isLogin
                                    ? l10n.authLoginAction
                                    : l10n.authRegisterAction,
                              ),
                      ),
                      if (_isLogin && demo != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Center(
                          child: Text(l10n.authOr, style: textTheme.bodySmall),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _signInWithDemoAccount(demo),
                          icon: const Icon(Icons.play_circle_outline_rounded),
                          label: Text(l10n.authDemoAccount),
                        ),
                      ],
                      if (!_isLogin) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          l10n.authRegisterDemoNote,
                          style: textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      TextButton(
                        onPressed: _busy ? null : _switchMode,
                        child: Text(
                          _isLogin
                              ? l10n.authSwitchToRegister
                              : l10n.authSwitchToLogin,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
