import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:keyframes_app/app/routes.dart';
import 'package:keyframes_app/core/theme/k_colors.dart';
import 'package:keyframes_app/core/theme/k_space.dart';
import 'package:keyframes_app/core/theme/k_text_styles.dart';
import 'package:keyframes_app/core/utils/validators.dart';
import 'package:keyframes_app/core/widgets/k_primary_button.dart';
import 'package:keyframes_app/data/models/app_user.dart';
import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/features/auth/auth_controller.dart';
import 'package:keyframes_app/features/auth/widgets/auth_scaffold.dart';

/// The sign-in screen (Requirements 4.1, 4.3, 4.5, 4.6).
///
/// Presents a navy gradient header carrying the Keyframes logo and a white,
/// rounded form sheet that slides up from the bottom on entrance. The form
/// collects email + password (validated with [Validators]), exposes a primary
/// submit button whose loading state is bound to [AuthController], a
/// "Continue with Google" action, and a link to registration.
///
/// On an invalid submit the form plays a horizontal shake (no navigation); on
/// successful authentication it routes by the resolved [AppUser.role]
/// (`admin` → admin orders, otherwise client home), leaving the router's guard
/// to correct any edge cases.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late final AnimationController _shakeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  bool _obscurePassword = true;

  @override
  void dispose() {
    _shakeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Validates a required, minimum-length password (inline, screen-local).
  String? _validatePassword(String? value) {
    final input = value ?? '';
    if (input.isEmpty) {
      return 'Password is required.';
    }
    if (input.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    return null;
  }

  void _triggerShake() {
    _shakeController.forward(from: 0);
  }

  void _routeByRole(AppUser user) {
    final String target =
        user.role == UserRole.admin ? KRoutes.adminOrders : KRoutes.home;
    context.go(target);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      _triggerShake();
      return;
    }
    final AppUser? user =
        await ref.read(authControllerProvider.notifier).signIn(
              email: _emailController.text,
              password: _passwordController.text,
            );
    if (!mounted) {
      return;
    }
    if (user != null) {
      _routeByRole(user);
    } else {
      _triggerShake();
    }
  }

  Future<void> _continueWithGoogle() async {
    FocusScope.of(context).unfocus();
    final AppUser? user =
        await ref.read(authControllerProvider.notifier).signInWithGoogle();
    if (!mounted) {
      return;
    }
    if (user != null) {
      _routeByRole(user);
    } else {
      _triggerShake();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AppUser?> authState = ref.watch(authControllerProvider);
    final bool isLoading = authState.isLoading;
    final bool hasError = authState.hasError;

    return AuthScaffold(
      shakeController: _shakeController,
      title: 'Welcome back',
      subtitle: 'Sign in to continue to Keyframes.',
      form: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (hasError) ...<Widget>[
              const _AuthErrorBanner(
                message:
                    "We couldn't sign you in. Please check your details and "
                    'try again.',
              ),
              const SizedBox(height: KSpace.lg),
            ],
            TextFormField(
              controller: _emailController,
              enabled: !isLoading,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              validator: Validators.email,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: KSpace.lg),
            TextFormField(
              controller: _passwordController,
              enabled: !isLoading,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              validator: _validatePassword,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: KSpace.xl),
            KPrimaryButton(
              label: 'Sign In',
              loading: isLoading,
              expanded: true,
              onPressed: isLoading ? null : _submit,
            ),
            const SizedBox(height: KSpace.lg),
            const _OrDivider(),
            const SizedBox(height: KSpace.lg),
            _GoogleButton(
              onPressed: isLoading ? null : _continueWithGoogle,
            ),
            const SizedBox(height: KSpace.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  "Don't have an account?",
                  style: KTextStyles.bodyMd.copyWith(color: KColors.slate500),
                ),
                TextButton(
                  onPressed:
                      isLoading ? null : () => context.go(KRoutes.register),
                  child: const Text('Register'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline, dismissible-looking error banner shown above the auth form.
class _AuthErrorBanner extends StatelessWidget {
  const _AuthErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KSpace.md),
      decoration: BoxDecoration(
        color: const Color(0x1AE5484D), // danger @ ~10%
        borderRadius: BorderRadius.circular(KSpace.rMd),
        border: Border.all(color: const Color(0x66E5484D)), // danger @ ~40%
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline, color: KColors.danger, size: 20),
          const SizedBox(width: KSpace.sm),
          Expanded(
            child: Text(
              message,
              style: KTextStyles.bodyMd.copyWith(color: KColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

/// A horizontal "OR" divider between the primary submit and Google actions.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(child: Divider(color: KColors.slate200)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: KSpace.md),
          child: Text(
            'OR',
            style: KTextStyles.caption.copyWith(color: KColors.slate500),
          ),
        ),
        const Expanded(child: Divider(color: KColors.slate200)),
      ],
    );
  }
}

/// A "Continue with Google" outlined button sized to the 48px touch target.
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: KSpace.minTouchTarget,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.g_mobiledata, size: 28, color: KColors.navy800),
        label: Text(
          'Continue with Google',
          style: KTextStyles.label.copyWith(
            color: KColors.navy800,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: KColors.slate200),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KSpace.rPill),
          ),
        ),
      ),
    );
  }
}
