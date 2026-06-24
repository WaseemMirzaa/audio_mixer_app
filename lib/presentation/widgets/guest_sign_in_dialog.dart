import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'sa_glass.dart';

/// Shows a themed dialog prompting guest users to sign in.
/// Returns after the dialog is dismissed.
Future<void> showGuestSignInDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => const _GuestSignInDialog(),
  );
}

class _GuestSignInDialog extends StatelessWidget {
  const _GuestSignInDialog();

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: glass.dialogCard(radius: 22),
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Icon ────────────────────────────────────────────────────
            Center(
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: glass.catGradients[0],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: glass.catGradients[0].last.withValues(alpha: 0.45),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),

            const SizedBox(height: 18),

            // ── Title ────────────────────────────────────────────────────
            Text(
              'Sign In to Save Your Mix',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: glass.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),

            const SizedBox(height: 10),

            // ── Body ─────────────────────────────────────────────────────
            Text(
              'You\'re exploring as a guest. Sign in or create a free account to '
              'save this session, build your history, and sync across devices — '
              'it only takes a moment.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: glass.textMuted,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 24),

            // ── Primary CTA ───────────────────────────────────────────────
            SaPrimaryButton(
              label: 'Sign In / Sign Up',
              onPressed: () {
                Navigator.pop(context);
                context.go('/login');
              },
            ),

            const SizedBox(height: 6),

            // ── Dismiss ───────────────────────────────────────────────────
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: glass.textMuted,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: Text(
                  'Maybe Later',
                  style: TextStyle(
                    color: glass.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
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
