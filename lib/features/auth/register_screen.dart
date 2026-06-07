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
import 'package:keyframes_app/data/models/register_input.dart';
import 'package:keyframes_app/features/auth/auth_controller.dart';
import 'package:keyframes_app/features/auth/widgets/auth_scaffold.dart';

/// The client registration screen (Requirements 4.2, 4.4, 4.5, 4.6, 4.8).
///
/// Collects name, email, phone, and password (validated with [Validators]),
/// then builds a [RegisterInput] and submits it through the [AuthController].
/// Registration always yields a `client` account — no role selector or admin
/// sign-up surface is exposed (Requirement 4.8).
///
/// Shares the navy-header / slide-up form sheet chrome and the error-shake
/// behavior with the login screen via [AuthScaffold]. On success it routes by
/// the resolved [AppUser.role] (effectively client home); on an invalid submit
/// it shakes the form without navigating.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late final AnimationController _shakeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  bool _obscurePassword = true;

  @override
  void dispose() {
    _shakeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Validates a required phone for registration.
  ///
  /// [Validators.phone] treats an empty value as valid (the field is optional
  /// on other entities), but registration requires a phone, so we reject empty
  /// input first and then defer to the shared digit-count rule.
  String? _validatePhone(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Phone number is required.';
    }
    return Validators.phone(value);
  }

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
    final RegisterInput input = RegisterInput(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
    );
    final AppUser? user =
        await ref.read(authControllerProvider.notifier).register(input);
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
      title: 'Create account',
      subtitle: 'Join Keyframes to pre-order and track your projects.',
      form: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (hasError) ...<Widget>[
              const _RegisterErrorBanner(
                message: "We couldn't create your account. Please review your "
                    'details and try again.',
              ),
              const SizedBox(height: KSpace.lg),
            ],
            TextFormField(
              controller: _nameController,
              enabled: !isLoading,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: Validators.name,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: KSpace.lg),
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
              controller: _phoneController,
              enabled: !isLoading,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: _validatePhone,
              decoration: const InputDecoration(
                labelText: 'Phone',
                prefixIcon: Icon(Icons.phone_outlined),
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
              label: 'Create Account',
              loading: isLoading,
              expanded: true,
              onPressed: isLoading ? null : _submit,
            ),
            const SizedBox(height: KSpace.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'Already have an account?',
                  style: KTextStyles.bodyMd.copyWith(color: KColors.slate500),
                ),
                TextButton(
                  onPressed: isLoading ? null : () => context.go(KRoutes.login),
                  child: const Text('Sign In'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline error banner shown above the registration form on failure.
class _RegisterErrorBanner extends StatelessWidget {
  const _RegisterErrorBanner({required this.message});

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
