import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Restrained frosted surface with a cool, blue-led edge.
/// Slightly stronger fill so cards read on near-black scaffolds.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 18,
    this.blur = 10,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final double blur;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: AppTheme.glassFill,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.silver.withValues(alpha: 0.10),
                AppTheme.brandBlue.withValues(alpha: 0.06),
                AppTheme.surfaceRaised.withValues(alpha: 0.55),
              ],
            ),
            border: Border.all(color: AppTheme.glassBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: body,
      ),
    );
  }
}

/// App backdrop. Keep the decoration static and lightweight so scrolling
/// screens don't need an animated or continuously changing background.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.metalDeep,
            Color(0xFF1A2534),
            AppTheme.metal,
          ],
          stops: [0.0, 0.48, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -50,
            child: _blob(AppTheme.brandBlue, 220, 0.12),
          ),
          Positioned(
            bottom: 100,
            left: -70,
            child: _blob(AppTheme.brandBlueDeep, 190, 0.10),
          ),
          child,
        ],
      ),
    );
  }

  Widget _blob(Color color, double size, double alpha) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: alpha),
          ),
        ),
      );
}
