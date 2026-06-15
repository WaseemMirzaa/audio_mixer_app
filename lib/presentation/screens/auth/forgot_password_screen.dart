import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/repositories/auth_repository.dart';
import '../../providers/providers.dart';
import '../../widgets/book_with_notes.dart';
import '../../widgets/sa_glass.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<void> _send() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Email is required.');
      return;
    }
    if (!_emailRegex.hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordResetEmail(email);
      if (!mounted) return;
      setState(() => _sent = true);
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
    _email.dispose();
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
              title: 'Forgot Password?',
              subtitle: 'Enter your email and we\'ll send you a reset link',
            ),
            const SizedBox(height: 12),
            if (_sent)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text(
                  'Reset link sent! Check your inbox.',
                  style: TextStyle(
                    color: glass.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SaGlassTextField(
                  strongFill: true,
                  controller: _email,
                  label: 'Email',
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
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
              ],
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SaPrimaryButton(
                  dark: true,
                  label: _loading ? 'Sending…' : 'Send Reset Link',
                  onPressed: _loading ? null : _send,
                ),
              ),
            ],
            Center(
              child: TextButton(
                onPressed: () => context.go('/login'),
                style: TextButton.styleFrom(foregroundColor: glass.accent),
                child: Text(
                  'Back to Login',
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
