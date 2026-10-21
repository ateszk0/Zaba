import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/failure_box.dart';
import '../../../core/widgets/zaba_wordmark.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_repository.dart';
import '../../auth/domain/auth_rules.dart';
import '../../auth/presentation/auth_messages.dart';

/// The staff account behind the "sign in as demo staff" button, set by the
/// build (`ADMIN_DEMO_EMAIL` / `ADMIN_DEMO_PASSWORD`). Unset by default: a
/// password inside a public web page lets anybody operate the page, so the demo
/// builds for customers leave it out and the staff member types it.
final adminDemoCredentialsProvider = Provider<DemoCredentials?>((ref) {
  if (AppConfig.adminDemoEmail == '' || AppConfig.adminDemoPassword == '') {
    return null;
  }
  return const DemoCredentials(
    email: AppConfig.adminDemoEmail,
    password: AppConfig.adminDemoPassword,
  );
});

/// Staff sign in. There is no registration: staff accounts are created by an
/// administrator. Leaving the screen after a sign-in is the router's job.
class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  var _showPassword = false;
  var _busy = false;
  var _checkWhileTyping = false;
  AuthFailureReason? _failure;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn(String email, String password) async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: password);
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

  void _submit() {
    if (_busy) {
      return;
    }
    setState(() => _checkWhileTyping = true);
    if (_formKey.currentState!.validate()) {
      _signIn(_email.text, _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final demo = ref.watch(adminDemoCredentialsProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
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
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.adminLoginTitle,
                        style: textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.adminLoginBody,
                        style: textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
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
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: l10n.authPasswordLabel,
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
                        validator: (value) => (value ?? '').isEmpty
                            ? l10n.authPasswordRequired
                            : null,
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
                            : Text(l10n.authLoginAction),
                      ),
                      if (demo != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _signIn(demo.email, demo.password),
                          icon: const Icon(Icons.play_circle_outline_rounded),
                          label: Text(l10n.adminDemoLogin),
                        ),
                      ],
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
