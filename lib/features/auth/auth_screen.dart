import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../state/app_state.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/buttons.dart';

/// Combined login / register screen with a sliding top sheet over the animated
/// brand background. Includes an "Admin" toggle for the dashboard demo.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _asAdmin = false;
  bool _obscure = true;
  bool _loading = false;

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController(text: 'you@keyframes.studio');
  final _password = TextEditingController(text: 'password');

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final app = context.read<AppState>();
    try {
      if (_isLogin) {
        await app.login(_email.text, _password.text, asAdmin: _asAdmin);
      } else {
        await app.register(_name.text, _email.text, _password.text);
      }
      // Routing is handled by the root listener (AppRoot).
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AnimatedAuroraBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.vertical,
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const SizedBox(height: 36),
                    const BrandLogo(size: 76, glow: true),
                    const SizedBox(height: 14),
                    const Text(
                      'KEYFRAMES',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 5,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Design · Develop · Deliver',
                      style: TextStyle(color: AppColors.amberBright, fontSize: 12),
                    ),
                    const Spacer(),
                    _AuthSheet(
                      isLogin: _isLogin,
                      formKey: _formKey,
                      name: _name,
                      email: _email,
                      password: _password,
                      obscure: _obscure,
                      loading: _loading,
                      asAdmin: _asAdmin,
                      onToggleObscure: () =>
                          setState(() => _obscure = !_obscure),
                      onToggleMode: () => setState(() => _isLogin = !_isLogin),
                      onToggleAdmin: (v) => setState(() => _asAdmin = v),
                      onSubmit: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthSheet extends StatelessWidget {
  const _AuthSheet({
    required this.isLogin,
    required this.formKey,
    required this.name,
    required this.email,
    required this.password,
    required this.obscure,
    required this.loading,
    required this.asAdmin,
    required this.onToggleObscure,
    required this.onToggleMode,
    required this.onToggleAdmin,
    required this.onSubmit,
  });

  final bool isLogin;
  final GlobalKey<FormState> formKey;
  final TextEditingController name;
  final TextEditingController email;
  final TextEditingController password;
  final bool obscure;
  final bool loading;
  final bool asAdmin;
  final VoidCallback onToggleObscure;
  final VoidCallback onToggleMode;
  final ValueChanged<bool> onToggleAdmin;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: const BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
      ),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isLogin ? 'Welcome back' : 'Create your account',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              isLogin
                  ? 'Sign in to manage your orders and chats.'
                  : 'Join Keyframes and pre-order in minutes.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 22),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              child: isLogin
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: TextFormField(
                        controller: name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          hintText: 'Full name',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (v) => (!isLogin && (v == null || v.isEmpty))
                            ? 'Enter your name'
                            : null,
                      ),
                    ),
            ),
            TextFormField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'Email address',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: password,
              obscureText: obscure,
              decoration: InputDecoration(
                hintText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(obscure
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded),
                  onPressed: onToggleObscure,
                ),
              ),
              validator: (v) => (v == null || v.length < 4)
                  ? 'Minimum 4 characters'
                  : null,
            ),
            const SizedBox(height: 8),
            if (isLogin)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Switch.adaptive(
                        value: asAdmin,
                        activeColor: AppColors.amber,
                        onChanged: onToggleAdmin,
                      ),
                      const Text('Admin login'),
                    ],
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Forgot password?',
                        style: TextStyle(color: AppColors.amberDeep)),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            GradientButton(
              label: isLogin ? 'Sign In' : 'Create Account',
              loading: loading,
              icon: Icons.arrow_forward_rounded,
              onPressed: onSubmit,
            ),
            const SizedBox(height: 18),
            Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    isLogin
                        ? "Don't have an account? "
                        : 'Already have an account? ',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  GestureDetector(
                    onTap: onToggleMode,
                    child: Text(
                      isLogin ? 'Sign up' : 'Sign in',
                      style: const TextStyle(
                        color: AppColors.navy600,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
