class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.isGuest = false,
    this.onboardingCompleted = false,
    this.preferredTheme = 'system',
    this.defaultPresetId,
  });

  final String uid;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final bool isGuest;
  final bool onboardingCompleted;
  final String preferredTheme;
  final String? defaultPresetId;

  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? avatarUrl,
    bool clearAvatar = false,
    bool? isGuest,
    bool? onboardingCompleted,
    String? preferredTheme,
    String? defaultPresetId,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
      isGuest: isGuest ?? this.isGuest,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      preferredTheme: preferredTheme ?? this.preferredTheme,
      defaultPresetId: defaultPresetId ?? this.defaultPresetId,
    );
  }
}
