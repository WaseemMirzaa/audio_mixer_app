import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_branding.dart';
import '../../widgets/book_with_notes.dart';
import '../../widgets/sa_glass.dart';

/// Welcome screen shown after the splash for signed-out users.
class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);
    return SaGlassScaffold(
      splashBackground: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Book artwork (same as login) — sized dynamically to fit, framed
            // by scattered music / media icons.
            const Expanded(
              flex: 6,
              child: BookWithNotes(),
            ),
            Text(
              AppBranding.appName,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: glass.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Mix your audiobooks with calming\nambient soundscapes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: glass.textMuted,
                fontSize: 14.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            SaPrimaryButton(
              dark: true,
              label: 'Get Started',
              icon: Icons.arrow_forward_rounded,
              onPressed: () => context.go('/signup'),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: TextStyle(color: glass.textMuted, fontSize: 14),
                ),
                GestureDetector(
                  onTap: () => context.go('/login'),
                  child: Text(
                    'Log In',
                    style: TextStyle(
                      color: glass.accent,
                      fontSize: 14,
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
