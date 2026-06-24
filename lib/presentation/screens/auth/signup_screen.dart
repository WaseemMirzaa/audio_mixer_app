import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/repositories/auth_repository.dart';
import '../../providers/providers.dart';
import '../../widgets/book_with_notes.dart';
import '../../widgets/sa_glass.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  bool _acceptedTerms = false;
  bool _loading = false;
  String? _error;

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String? _validate() {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _pw.text;
    final confirm = _pw2.text;

    if (name.isEmpty) return 'Full name is required.';
    if (email.isEmpty) return 'Email is required.';
    if (!_emailRegex.hasMatch(email)) return 'Enter a valid email address.';
    if (password.isEmpty) return 'Password is required.';
    if (password.length < 6) return 'Password must be at least 6 characters.';
    if (confirm.isEmpty) return 'Please confirm your password.';
    if (password != confirm) return 'Passwords do not match.';
    if (!_acceptedTerms) return 'Please agree to the Terms & Conditions.';

    return null;
  }

  Future<void> _submit() async {
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
      await ref.read(authRepositoryProvider).signUp(
            displayName: _name.text.trim(),
            email: _email.text.trim(),
            password: _pw.text,
          );
      ref.invalidate(authStateProvider);
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

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pw.dispose();
    _pw2.dispose();
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
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/get-started');
                    }
                  },
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
              title: 'Create Account',
              subtitle: 'Sign up to get started',
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SaGlassTextField(
                    strongFill: true,
                    controller: _name,
                    label: 'Full Name',
                    hint: 'John Doe',
                  ),
                  const SizedBox(height: 12),
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
                    controller: _pw,
                    label: 'Password',
                    hint: '••••••••',
                    obscure: true,
                    showVisibilityIcon: true,
                  ),
                  const SizedBox(height: 12),
                  SaGlassTextField(
                    strongFill: true,
                    controller: _pw2,
                    label: 'Confirm Password',
                    hint: '••••••••',
                    obscure: true,
                    showVisibilityIcon: true,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 20, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _acceptedTerms,
                    fillColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return glass.accent;
                      }
                      return Colors.white.withValues(alpha: 0.12);
                    }),
                    side: BorderSide(color: glass.glassBorder),
                    checkColor: Colors.white,
                    onChanged: (v) =>
                        setState(() => _acceptedTerms = v ?? false),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'I agree to the Terms & Conditions',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            height: 1.35,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
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
                label: _loading ? 'Creating account…' : 'Create Account',
                onPressed: _loading ? null : _submit,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                TextButton(
                  onPressed: () => context.go('/login'),
                  style: TextButton.styleFrom(
                    foregroundColor: glass.accent,
                  ),
                  child: Text(
                    'Login',
                    style: TextStyle(
                      color: glass.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
