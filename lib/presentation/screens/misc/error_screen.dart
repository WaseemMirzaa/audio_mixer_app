import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/sa_glass.dart';

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);
    return SaGlassScaffold(
      header: SaBackHeader(
        title: 'Something went wrong',
        onBack: () => context.go('/home'),
      ),
      child: ListView(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            decoration: glass.card(radius: 20),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                FaIcon(
                  FontAwesomeIcons.triangleExclamation,
                  size: 64,
                  color: glass.accent,
                ),
                const SizedBox(height: 12),
                Text(
                  'We hit an issue',
                  style: TextStyle(
                    color: glass.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message ?? 'Unexpected error',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: glass.textMuted, fontSize: 14, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SaPrimaryButton(
            label: 'Go home',
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
    );
  }
}
