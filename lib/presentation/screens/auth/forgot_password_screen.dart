import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/mock/mock_auth_repository.dart';
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
  String? _error;

  Future<void> _send() async {
    setState(() => _error = null);
    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordResetEmail(_email.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reset link sent (mock uses toast only).'),
        ),
      );
      context.go('/login');
    } on AuthException catch (e) {
      setState(
        () => _error = e.code == 'invalid-email'
            ? 'Invalid email'
            : 'Could not send reset.',
      );
    } catch (_) {
      setState(() => _error = 'Network failure.');
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
              child: const BookWithNotes(height: 300),
            ),
            const SizedBox(height: 20),
            const SaHeading(
              title: 'Forgot Password?',
              subtitle: 'Enter your email and we’ll send you a reset link',
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SaGlassTextField(
                strongFill: true,
                controller: _email,
                label: 'Email',
                hint: 'demo@app.com',
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
                label: 'Send Reset Link',
                onPressed: _send,
              ),
            ),
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
