import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_branding.dart';
import '../../widgets/sa_glass.dart';

class PermissionScreen extends StatelessWidget {
  const PermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);
    return SaGlassScaffold(
      header: SaBackHeader(
        title: 'Storage access',
        onBack: () => context.pop(),
      ),
      child: ListView(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            decoration: glass.card(radius: 20),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FaIcon(FontAwesomeIcons.folderOpen, size: 40, color: glass.accent),
                const SizedBox(height: 14),
                Text(
                  'Permission required',
                  style: TextStyle(
                    color: glass.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Storage permission is required to import MP3, WAV, AAC, or M4A '
                  'files from your device.',
                  style: TextStyle(color: glass.textMuted, fontSize: 14, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SaPrimaryButton(
            label: 'Open Settings',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Open OS Settings → Apps → ${AppBranding.appName} → Permissions',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          SaSecondaryButton(
            label: 'Back',
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );
  }
}
