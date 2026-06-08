import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.showVisibilityIcon = false,
    /// Translucent white field on brand glaze (auth screens without cards).
    this.onGlazedBackdrop = false,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final bool showVisibilityIcon;
  final bool onGlazedBackdrop;

  static const double _radius = 14;

  @override
  Widget build(BuildContext context) {
    if (onGlazedBackdrop) {
      final borderColor = Colors.white.withValues(alpha: 0.32);
      final fillColor = Colors.white.withValues(alpha: 0.14);
      return TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
          filled: true,
          fillColor: fillColor,
          labelStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontWeight: FontWeight.w500,
          ),
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.52),
            fontWeight: FontWeight.w400,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_radius),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_radius),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.72),
              width: 1.4,
            ),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_radius),
            borderSide: BorderSide(color: borderColor.withValues(alpha: 0.5)),
          ),
          suffixIcon: showVisibilityIcon
              ? Icon(
                  Icons.visibility_outlined,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.65),
                )
              : null,
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: scheme.onSurface,
          ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        suffixIcon: showVisibilityIcon
            ? Icon(
                Icons.visibility_outlined,
                size: 18,
                color: AppTheme.fgMuted(context),
              )
            : null,
      ),
    );
  }
}
