import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../widgets/app_layout.dart';
import '../../widgets/app_surface_card.dart';
import '../../widgets/primary_button.dart';

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Something went wrong')),
      body: AppContent(
        child: ListView(
          children: [
            AppSurfaceCard(
              child: Column(
                children: [
                  FaIcon(
                    FontAwesomeIcons.triangleExclamation,
                    size: 64,
                    color: AppTheme.ceramicGradient[38],
                  ),
                  const SizedBox(height: 8),
                  const Text('We hit an issue'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message ?? 'Unexpected error',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 28),
            PrimaryButton(
              label: 'Go home',
              onPressed: () => context.go('/home'),
            ),
          ],
        ),
      ),
    );
  }
}
