import 'package:flutter/material.dart';

import '../core/brand_config.dart';
import '../core/label_geometry.dart';
import '../core/label_painter.dart';
import 'micro_animations.dart';

/// Small uppercase heading above a group of fields.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
        ),
      ),
    );
  }
}

/// The bordered card used on the export screen, reused for grouped content.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brand = BrandScope.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141416) : Colors.white,
        borderRadius: brand.cornerStyle.mediumRadius,
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// A tappable card for picking one option from a short list.
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brand = BrandScope.of(context);
    final ink = isDark ? Colors.white : const Color(0xFF09090B);
    final muted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);

    return TapScale(
      onTap: onTap,
      scale: 0.98,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141416) : Colors.white,
          borderRadius: brand.cornerStyle.mediumRadius,
          border: Border.all(
            color: selected
                ? ink
                : (isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7)),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12.5, color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? ink : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? ink
                      : (isDark
                          ? const Color(0xFF3F3F46)
                          : const Color(0xFFD4D4D8)),
                  width: 1.5,
                ),
              ),
              child: selected
                  ? Icon(
                      Icons.check,
                      size: 14,
                      color: isDark ? Colors.black : Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// The solid black (white in dark mode) button used for the main action.
ButtonStyle primaryButtonStyle(BuildContext context, {double height = 56}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return FilledButton.styleFrom(
    backgroundColor: isDark ? Colors.white : const Color(0xFF09090B),
    foregroundColor: isDark ? Colors.black : Colors.white,
    disabledBackgroundColor:
        isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
    disabledForegroundColor:
        isDark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA),
    minimumSize: Size.fromHeight(height),
    shape: RoundedRectangleBorder(
      borderRadius: BrandScope.of(context).cornerStyle.mediumRadius,
    ),
  );
}

/// A label drawn on white, as it will print, framed so it stands out in both
/// themes.
class LabelPreview extends StatelessWidget {
  const LabelPreview({super.key, required this.geometry, this.maxWidth = 300});

  final LabelGeometry geometry;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brand = BrandScope.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: AspectRatio(
          aspectRatio: geometry.widthMm / geometry.heightMm,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: brand.cornerStyle.smallRadius,
              border: Border.all(
                color:
                    isDark ? const Color(0xFF3F3F46) : const Color(0xFFD4D4D8),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: brand.cornerStyle.smallRadius,
              child: CustomPaint(painter: LabelPainter(geometry)),
            ),
          ),
        ),
      ),
    );
  }
}
