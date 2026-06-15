import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/repositories/auth_repository.dart';
import '../../providers/providers.dart';
import '../../widgets/book_with_notes.dart';
import '../../widgets/sa_glass.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  String? _error;

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String? _validate() {
    final email = _email.text.trim();
    final password = _password.text;

    if (email.isEmpty) return 'Email is required.';
    if (!_emailRegex.hasMatch(email)) return 'Enter a valid email address.';
    if (password.isEmpty) return 'Password is required.';

    return null;
  }

  Future<void> _login() async {
    final validationError = _validate();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .signInWithEmail(email: _email.text.trim(), password: _password.text);
      ref.invalidate(sessionsProvider);
      ref.invalidate(presetsProvider);
      if (!mounted) return;
      context.go('/home');
    } on AuthException catch (e) {
      setState(() => _error = authErrorMessage(e));
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.\n($e)');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _guest() async {
    setState(() => _error = null);
    try {
      await ref.read(authRepositoryProvider).continueAsGuest();
      ref.invalidate(sessionsProvider);
      if (!mounted) return;
      context.go('/home');
    } on AuthException catch (e) {
      setState(() => _error = authErrorMessage(e));
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.\n($e)');
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);

    return SaGlassScaffold(
      splashBackground: true,
      child: SingleChildScrollView(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => context.pop(),
                  icon: Icon(
                    Icons.chevron_left_rounded,
                    color: glass.textPrimary,
                    size: 28,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: const BookWithNotes(height: 200),
            ),
            const SizedBox(height: 8),
            const SaHeading(
              title: 'Welcome Back',
              subtitle: 'Login to continue',
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SaGlassTextField(
                    strongFill: true,
                    controller: _email,
                    label: 'Email',
                    hint: 'you@example.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  SaGlassTextField(
                    strongFill: true,
                    controller: _password,
                    label: 'Password',
                    hint: '••••••••',
                    obscure: true,
                    showVisibilityIcon: true,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/forgot'),
                  style: TextButton.styleFrom(
                    foregroundColor: glass.accent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: glass.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFFF7A9D),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: SaPrimaryButton(
                label: _loading ? 'Signing in…' : 'Login',
                onPressed: _loading ? null : _login,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Don\'t have an account? ',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                TextButton(
                  onPressed: () => context.push('/signup'),
                  style: TextButton.styleFrom(
                    foregroundColor: glass.accent,
                  ),
                  child: Text(
                    'Sign Up',
                    style: TextStyle(
                      color: glass.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            Center(
              child: TextButton(
                onPressed: _guest,
                style: TextButton.styleFrom(
                  foregroundColor: glass.accent,
                ),
                child: Text(
                  'Continue as Guest',
                  style: TextStyle(
                    color: glass.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
