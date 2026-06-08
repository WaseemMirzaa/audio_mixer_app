import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/mock/mock_auth_repository.dart';
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
  bool _acceptedTerms = true;
  String? _error;

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_pw.text != _pw2.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    if (!_acceptedTerms) {
      setState(() => _error = 'Please agree to Terms & Conditions.');
      return;
    }
    try {
      await ref.read(authRepositoryProvider).signUp(
            displayName: _name.text,
            email: _email.text.trim(),
            password: _pw.text,
          );
      ref.invalidate(sessionsProvider);
      ref.invalidate(presetsProvider);
      if (!mounted) return;
      context.go('/home');
    } on AuthException catch (e) {
      setState(() => _error = e.code);
    } catch (_) {
      setState(() => _error = 'Network error.');
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
              child: const BookWithNotes(height: 300),
            ),
            // const SizedBox(height: 20),
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
                    hint: 'demo@app.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  SaGlassTextField(
                    strongFill: true,
                    controller: _pw,
                    label: 'Password',
                    hint: '********',
                    obscure: true,
                    showVisibilityIcon: true,
                  ),
                  const SizedBox(height: 12),
                  SaGlassTextField(
                    strongFill: true,
                    controller: _pw2,
                    label: 'Confirm Password',
                    hint: '********',
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
                padding: const EdgeInsets.symmetric(horizontal: 20),
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
                dark: true,
                label: 'Create Account',
                onPressed: _submit,
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
