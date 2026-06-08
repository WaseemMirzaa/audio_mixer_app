import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../widgets/sa_glass.dart';
import '../../widgets/user_avatar.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  late final TextEditingController _name;
  String? _pickedPath;
  bool _clearAvatar = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authStateProvider).valueOrNull;
    _name = TextEditingController(text: auth?.displayName ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image);
    if (res == null || res.files.isEmpty) return;
    final path = res.files.single.path;
    if (path == null) return;
    setState(() {
      _pickedPath = path;
      _clearAvatar = false;
    });
  }

  void _removeAvatar() {
    setState(() {
      _pickedPath = null;
      _clearAvatar = true;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a display name.')),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(authRepositoryProvider);
    setState(() => _saving = true);
    try {
      if (_pickedPath != null) {
        // Upload the picked image (Firebase Storage in firebase mode; the
        // local path is returned unchanged in mock mode) and store the URL.
        final avatarUrl = await repo.uploadAvatar(_pickedPath!);
        await repo.updateProfile(displayName: name, avatarUrl: avatarUrl);
      } else if (_clearAvatar) {
        await repo.updateProfile(displayName: name, clearAvatar: true);
      } else {
        await repo.updateProfile(displayName: name);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update profile: $e')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    messenger.showSnackBar(
      const SnackBar(content: Text('Profile updated')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider).valueOrNull;
    final glass = SaGlass.of(context);

    return SaGlassScaffold(
      header: SaBackHeader(
        title: 'My Account',
        subtitle: 'Update your profile',
        onBack: () => context.pop(),
      ),
      child: SingleChildScrollView(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: glass.glassBorder,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: UserAvatar(
                      user: auth,
                      radius: 52,
                      localPathOverride: _pickedPath,
                      preferInitials: _clearAvatar && _pickedPath == null,
                    ),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 2,
                      shadowColor: Colors.black.withValues(alpha: 0.2),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _pickAvatar,
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Center(
                            child: Icon(
                              Icons.camera_alt_rounded,
                              size: 18,
                              color: glass.accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if ((_pickedPath != null ||
                    (auth?.avatarUrl?.isNotEmpty ?? false)) &&
                !_clearAvatar)
              Center(
                child: TextButton(
                  onPressed: _removeAvatar,
                  style: TextButton.styleFrom(
                    foregroundColor: glass.accent,
                  ),
                  child: Text(
                    'Remove photo',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: glass.accent,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 8),
            const SizedBox(height: 4),
            SaGlassTextField(
              controller: _name,
              label: 'Display name',
              hint: 'Your name',
            ),
            if (auth != null && auth.email.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Email',
                style: TextStyle(
                  color: glass.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                decoration: glass.card(radius: 14),
                child: Text(
                  auth.email,
                  style: TextStyle(
                    color: glass.textMuted,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SaPrimaryButton(
              label: _saving ? 'Saving…' : 'Save Changes',
              enabled: !_saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
