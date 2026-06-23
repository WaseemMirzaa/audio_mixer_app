import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shared "SoundAxis glass" design system used by Home (dark), Sessions and
/// Profile. Light mode = teal glass, dark mode = blue glass — both sampled from
/// the reference HTML designs. Home light mode keeps its own (frozen) tokens.
class SaGlass {
  const SaGlass({
    required this.isDark,
    required this.textPrimary,
    required this.textMuted,
    required this.textMeta,
    required this.accent,
    required this.seeAll,
    required this.cyan,
    required this.glassTop,
    required this.glassBottom,
    required this.glassBorder,
    required this.glassHighlight,
    required this.glassShadow,
    required this.heroTop,
    required this.heroBottom,
    required this.heroBorder,
    required this.plusGradient,
    required this.plusBorder,
    required this.plusIcon,
    required this.plusShadow,
    required this.playRingBg,
    required this.playRingBorder,
    required this.playIcon,
    required this.sliderActive,
    required this.sliderInactive,
    required this.sliderThumb,
    required this.divider,
    required this.fabBg,
    required this.fabIcon,
    required this.catGradients,
    required this.catIcons,
  });

  final bool isDark;

  // Text
  final Color textPrimary;
  final Color textMuted;
  final Color textMeta;

  // Accents
  final Color accent;
  final Color seeAll;
  final Color cyan;

  // Glass surface
  final Color glassTop;
  final Color glassBottom;
  final Color glassBorder;
  final Color glassHighlight;
  final Color glassShadow;

  // Hero "New Session" card
  final Color heroTop;
  final Color heroBottom;
  final Color heroBorder;

  // Plus / add button (gradient + border + icon + shadow)
  final List<Color> plusGradient;
  final Color plusBorder;
  final Color plusIcon;
  final Color plusShadow;

  // Play ring (recent-session tiles)
  final Color playRingBg;
  final Color playRingBorder;
  final Color playIcon;

  // Sliders
  final Color sliderActive;
  final Color sliderInactive;
  final Color sliderThumb;

  // Misc
  final Color divider;
  final Color fabBg;
  final Color fabIcon;

  // Category icon tiles (cycled by index)
  final List<List<Color>> catGradients;
  final List<IconData> catIcons;

  static SaGlass of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  /// Gradient for the primary "Continue" pill button.
  /// Dark mode starts at a saturated blue (not the near-background navy) so the
  /// button's left edge stays distinct from the navy backdrop.
  List<Color> get continueGradient => isDark
      ? const [Color(0xFF1F6BD6), Color(0xFF1E8AE0), Color(0xFF18C8E4)]
      : const [Color(0xFF1FC0CC), Color(0xFF12A0AC)];

  /// Translucent fill + border for secondary glass buttons (e.g. "Select Audio").
  BoxDecoration secondaryButton({double radius = 10}) => BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-0.4, -1),
          end: const Alignment(0.4, 1),
          colors: isDark
              ? const [Color(0x99104480), Color(0x80082454)]
              : const [Color(0x850E91A0), Color(0x70086E7C)],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isDark ? const Color(0x38468CE6) : const Color(0x3864D2DC),
          width: 1,
        ),
      );

  /// Glass surface shared by all cards.
  BoxDecoration card({double radius = 16}) => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [glassTop, glassBottom],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: glassBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: glassShadow,
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      );

  /// Slightly stronger glass for the hero "New Session" card.
  BoxDecoration hero({double radius = 20}) => BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-0.4, -1),
          end: const Alignment(0.4, 1),
          colors: [heroTop, heroBottom],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: heroBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: glassShadow,
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      );

  // ── Light (teal glass) ─────────────────────────────────────────────────────
  static const light = SaGlass(
    isDark: false,
    textPrimary: Color(0xFFDCEAF2),
    textMuted: Color(0xFF9CC2CC),
    textMeta: Color(0xFF6F9CA6),
    accent: Color(0xFF83EAF1),
    seeAll: Color(0xFF9CC2CC),
    cyan: Color(0xFF83EAF1),
    glassTop: Color(0x4D3CAAB9),
    glassBottom: Color(0x290F6473),
    glassBorder: Color(0x2EB4EBF0),
    glassHighlight: Color(0x1AB4EBF0),
    glassShadow: Color(0x47001E26),
    heroTop: Color(0x4D3CAAB9),
    heroBottom: Color(0x290F6473),
    heroBorder: Color(0x2EB4EBF0),
    plusGradient: [Color(0xEBFFFFFF), Color(0xEBFFFFFF)],
    plusBorder: Color(0x99FFFFFF),
    plusIcon: Color(0xFF137E90),
    plusShadow: Color(0x59002830),
    playRingBg: Color(0x730A7082),
    playRingBorder: Color(0x6683EAF1),
    playIcon: Color(0xFF83EAF1),
    sliderActive: Color(0xFF5DC0C5),
    sliderInactive: Color(0x2EFFFFFF),
    sliderThumb: Color(0xFF5DC0C5),
    divider: Color(0x2EB4EBF0),
    fabBg: Color(0xEBFFFFFF),
    fabIcon: Color(0xFF137E90),
    catGradients: [
      [Color(0xFF2E9BE0), Color(0xFF1E6FD0)],
      [Color(0xFFE6A93F), Color(0xFFC2762B)],
      [Color(0xFF5566C4), Color(0xFF2E4F9A)],
    ],
    catIcons: [
      Icons.headphones_rounded,
      Icons.access_time_rounded,
      Icons.headphones_rounded,
    ],
  );

  // ── Dark (blue glass) — from the SoundAxis dark-blue mockup ──────────────────
  static const dark = SaGlass(
    isDark: true,
    textPrimary: Color(0xFFEAF1F8),
    textMuted: Color(0xFF9DB0C7),
    textMeta: Color(0xFF6E7C92),
    accent: Color(0xFF2E9BFF),
    seeAll: Color(0xFF37B6F2),
    cyan: Color(0xFF3EBFF9),
    glassTop: Color(0x3D1A4EA0), // rgba(26,78,160,.24)
    glassBottom: Color(0x1F0A1E48), // rgba(10,30,72,.12)
    glassBorder: Color(0x295694EB), // rgba(86,148,235,.16)
    glassHighlight: Color(0x1A8CB4FF), // rgba(140,180,255,.10)
    glassShadow: Color(0x4D000A1E), // rgba(0,10,30,.3)
    heroTop: Color(0x661852B0), // rgba(24,82,176,.40)
    heroBottom: Color(0x47082052), // rgba(8,32,82,.28)
    heroBorder: Color(0x3360A0F5), // rgba(96,160,245,.2)
    plusGradient: [Color(0xFF4AB4FE), Color(0xFF2E9BFF)],
    plusBorder: Color(0x66FFFFFF),
    plusIcon: Colors.white,
    plusShadow: Color(0x802E9BFF), // rgba(46,155,255,.5)
    playRingBg: Color(0x80082048), // rgba(8,32,72,.5)
    playRingBorder: Color(0x663E96FA), // rgba(62,150,250,.4)
    playIcon: Color(0xFF3EBFF9),
    sliderActive: Color(0xFF2E9BFF),
    sliderInactive: Color(0x337896C8), // rgba(120,150,200,.2)
    sliderThumb: Color(0xFF6DCAF3),
    divider: Color(0x295694EB),
    fabBg: Color(0xFF2E9BFF),
    fabIcon: Colors.white,
    catGradients: [
      [Color(0xFF2E86E0), Color(0xFF0E4FC0)],
      [Color(0xFFE08A2A), Color(0xFF9A4A0E)],
      [Color(0xFF5450D6), Color(0xFF322BA0)],
    ],
    catIcons: [
      Icons.headphones_rounded,
      Icons.access_time_rounded,
      Icons.headphones_rounded,
    ],
  );
}

/// Full-screen radial backdrop + atmosphere glows for the glass design.
/// Teal ramp in light mode, deep-navy ramp in dark mode.
class SaGlassBackground extends StatelessWidget {
  const SaGlassBackground({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (isDark) return const _DarkBackground();
    return const _LightBackground();
  }
}

class _LightBackground extends StatelessWidget {
  const _LightBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -1.05),
          radius: 1.35,
          colors: [
            Color(0xFF2A9DB0),
            Color(0xFF137E90),
            Color(0xFF0A6171),
            Color(0xFF023D4E),
          ],
          stops: [0.0, 0.30, 0.58, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.78, -0.9),
                radius: 0.5,
                colors: [Color(0x1A8CF0FA), Color(0x008CF0FA)],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-1.0, 0.2),
                radius: 0.7,
                colors: [Color(0x590A5A69), Color(0x000A5A69)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkBackground extends StatelessWidget {
  const _DarkBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -1.0),
          radius: 1.3,
          colors: [
            Color(0xFF0B2C5A),
            Color(0xFF061A3C),
            Color(0xFF030F29),
            Color(0xFF010A1B),
          ],
          stops: [0.0, 0.30, 0.58, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Top-right blue glow.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.8, -0.92),
                radius: 0.5,
                colors: [Color(0x243C96FF), Color(0x003C96FF)],
              ),
            ),
          ),
          // Edge vignette that deepens toward the bottom corners.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.16),
                radius: 1.05,
                colors: [Color(0x00000610), Color(0x8C000610)],
                stops: [0.5, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular play button used by Home (dark) and Sessions glass tiles.
class SaPlayRing extends StatelessWidget {
  const SaPlayRing({
    super.key,
    required this.glass,
    required this.onTap,
    this.size = 44,
  });

  final SaGlass glass;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: glass.playRingBg,
          border: Border.all(color: glass.playRingBorder, width: 1.5),
        ),
        child: Icon(
          Icons.play_arrow_rounded,
          color: glass.playIcon,
          size: size * 0.5,
        ),
      ),
    );
  }
}

/// Gradient category icon tile (cycled per index).
class SaCategoryIcon extends StatelessWidget {
  const SaCategoryIcon({
    super.key,
    required this.glass,
    required this.index,
    this.size = 50,
    this.radius = 15,
  });

  final SaGlass glass;
  final int index;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final gradient = glass.catGradients[index % glass.catGradients.length];
    final glyph = glass.catIcons[index % glass.catIcons.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          // Elevation drop shadow.
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          // Colored glow.
          BoxShadow(
            color: gradient.last.withValues(alpha: 0.65),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Icon(glyph, color: Colors.white, size: size * 0.5),
    );
  }
}

/// Full-screen branded splash/auth backdrop image (light vs dark variant).
class SaSplashBackground extends StatelessWidget {
  const SaSplashBackground({super.key});

  static const _light = 'assets/branding/light_splash_background.png';
  static const _dark = 'assets/branding/dark_splash_background.png';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      isDark ? _dark : _light,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => SaGlassBackground(isDark: isDark),
    );
  }
}

/// The player-style page backdrop: the full-bleed splash photo with a
/// brand-coloured fade rising from the bottom so foreground content stays
/// readable. Light/dark variants are chosen automatically. Shared by the
/// Player, Home and the audio picker so the core flow has one backdrop.
class SaPlayerBackground extends StatelessWidget {
  const SaPlayerBackground({super.key});

  /// Bottom anchor tone — deep teal in light, near-black navy in dark. Matches
  /// the Home gradient's bottom stop so the fade lands on the established tone.
  static const _overlayLight = Color(0xFF023D4E);
  static const _overlayDark = Color(0xFF010A1B);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlay = isDark ? _overlayDark : _overlayLight;
    return Stack(
      fit: StackFit.expand,
      children: [
        const SaSplashBackground(),
        // Brand-coloured overlay: opaque at the bottom, fading to transparent
        // by the vertical middle so the photo shows behind the top content.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: const Alignment(0, -0.8),
                colors: [
                  overlay,
                  overlay.withValues(alpha: 0.7),
                  overlay.withValues(alpha: 0),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Scaffold pre-wired with a background — the glass radial by default, or the
/// branded splash image when [splashBackground] is true (login / signup / etc).
class SaGlassScaffold extends StatelessWidget {
  const SaGlassScaffold({
    super.key,
    required this.child,
    this.header,
    this.headerPadding = const EdgeInsets.symmetric(horizontal: 12),
    this.floatingActionButton,
    this.resizeToAvoidBottomInset,
    this.safeArea = true,
    this.splashBackground = false,
  });

  final Widget child;

  /// Optional sticky header pinned above [child]. It stays fixed on the screen
  /// background while [child] (a scrollable) scrolls underneath it.
  final Widget? header;
  final EdgeInsetsGeometry headerPadding;
  final Widget? floatingActionButton;
  final bool? resizeToAvoidBottomInset;
  final bool safeArea;
  final bool splashBackground;

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);
    final content = header == null
        ? child
        : Column(
            children: [
              Padding(padding: headerPadding, child: header!),
              Expanded(child: child),
            ],
          );
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      floatingActionButton: floatingActionButton,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const SaPlayerBackground(),
          safeArea ? SafeArea(child: content) : content,
        ],
      ),
    );
  }
}

/// Back chevron + title (and optional subtitle), matching the New Session header.
class SaBackHeader extends StatelessWidget {
  const SaBackHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 7, 2, 2),
      child: Row(
        children: [
          if (onBack != null) ...[
            GestureDetector(
              onTap: onBack,
              child: Icon(Icons.chevron_left_rounded,
                  color: glass.textPrimary, size: 28),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: glass.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(color: glass.textMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Centered page heading (large title + subtitle) for hero-style screens.
class SaHeading extends StatelessWidget {
  const SaHeading({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// Glass text field — translucent fill, glass border, accent focus.
/// Mirrors the old AppTextField API for drop-in replacement; the visibility
/// icon actually toggles obscuring.
class SaGlassTextField extends StatefulWidget {
  const SaGlassTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.showVisibilityIcon = false,
    this.prefixIcon,
    this.strongFill = false,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final bool showVisibilityIcon;
  final IconData? prefixIcon;

  /// Darker, more opaque fill so the field reads clearly on the splash image
  /// backgrounds (login / signup / forgot password).
  final bool strongFill;

  @override
  State<SaGlassTextField> createState() => _SaGlassTextFieldState();
}

class _SaGlassTextFieldState extends State<SaGlassTextField> {
  late bool _obscured = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );

    return TextField(
      controller: widget.controller,
      obscureText: _obscured,
      keyboardType: widget.keyboardType,
      style: TextStyle(
        color: glass.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      cursorColor: glass.accent,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        isDense: true,
        filled: true,
        fillColor: widget.strongFill
            ? (glass.isDark
                ? const Color(0xCC061327) // deep navy, ~0.8
                : const Color(0xB3052E38)) // deep teal, ~0.7
            : glass.glassBottom,
        prefixIcon: widget.prefixIcon != null
            ? Icon(widget.prefixIcon, color: glass.textMuted, size: 20)
            : null,
        labelStyle: TextStyle(color: glass.textMuted, fontWeight: FontWeight.w500),
        floatingLabelStyle: TextStyle(color: glass.accent),
        hintStyle: TextStyle(color: glass.textMeta),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        enabledBorder: border(glass.glassBorder, 1),
        focusedBorder: border(glass.accent, 1.4),
        border: border(glass.glassBorder, 1),
        suffixIcon: widget.showVisibilityIcon
            ? IconButton(
                onPressed: () => setState(() => _obscured = !_obscured),
                icon: Icon(
                  _obscured
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                  color: glass.textMuted,
                ),
              )
            : null,
      ),
    );
  }
}

/// Primary gradient pill button (matches "Continue to Player").
class SaPrimaryButton extends StatelessWidget {
  const SaPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.enabled = true,
    this.dark = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool enabled;

  /// Dark, solid, prominent variant for CTAs sitting on the splash backgrounds
  /// (Get Started / Login / Create Account / Send Reset Link).
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);
    final on = enabled && onPressed != null;
    return Opacity(
      opacity: on ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: on ? onPressed : null,
          borderRadius: BorderRadius.circular(26),
          child: Container(
            constraints: const BoxConstraints(minHeight: 54),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
            decoration: BoxDecoration(
              gradient: dark
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0C1E3C), Color(0xFF05101F)],
                    )
                  : LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: glass.continueGradient,
                    ),
              borderRadius: BorderRadius.circular(26),
              border: dark
                  ? Border.all(color: Colors.white.withValues(alpha: 0.14))
                  : null,
              boxShadow: [
                BoxShadow(
                  color: dark
                      ? Colors.black.withValues(alpha: 0.45)
                      : glass.continueGradient.last.withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary translucent glass button (matches "Select Audio").
class SaSecondaryButton extends StatelessWidget {
  const SaSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          decoration: glass.secondaryButton(radius: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: glass.textPrimary, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: glass.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact "Privacy Policy · Terms of Service" footer row.
/// Drop it at the bottom of any screen that needs legal links.
class SaLegalFooter extends StatelessWidget {
  const SaLegalFooter({super.key, this.topPadding = 16});

  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);
    final linkStyle = TextStyle(
      color: glass.textMuted,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      decoration: TextDecoration.underline,
      decorationColor: glass.textMuted.withValues(alpha: 0.5),
    );
    final sepStyle = TextStyle(color: glass.textMeta, fontSize: 12);

    return Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              final router = GoRouter.of(context);
              router.push('/privacy');
            },
            child: Text('Privacy Policy', style: linkStyle),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('·', style: sepStyle),
          ),
          GestureDetector(
            onTap: () {
              final router = GoRouter.of(context);
              router.push('/terms');
            },
            child: Text('Terms of Service', style: linkStyle),
          ),
        ],
      ),
    );
  }
}
