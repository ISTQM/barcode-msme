import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Provides tactile scale-down micro-interaction on press with haptic feedback.
/// Inspired by Mobbin & iOS tactile design.
class TapScale extends StatefulWidget {
  const TapScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.96,
    this.duration = const Duration(milliseconds: 110),
    this.enableHaptics = true,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final Duration duration;
  final bool enableHaptics;
  final HitTestBehavior behavior;

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  bool _pressed = false;

  void _down(TapDownDetails _) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (widget.enableHaptics) {
      HapticFeedback.selectionClick();
    }
    setState(() => _pressed = true);
  }

  void _up(TapUpDetails _) {
    if (_pressed) {
      setState(() => _pressed = false);
    }
  }

  void _cancel() {
    if (_pressed) {
      setState(() => _pressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: _cancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: widget.duration,
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// A smooth pop/bounce animation when a counter value changes.
class PopBadge extends StatefulWidget {
  const PopBadge({
    super.key,
    required this.valueKey,
    required this.child,
    this.duration = const Duration(milliseconds: 240),
  });

  final Object valueKey;
  final Widget child;
  final Duration duration;

  @override
  State<PopBadge> createState() => _PopBadgeState();
}

class _PopBadgeState extends State<PopBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(begin: 1.0, end: 1.18)
          .chain(CurveTween(curve: Curves.easeOutQuad)),
      weight: 45,
    ),
    TweenSequenceItem(
      tween: Tween<double>(begin: 1.18, end: 1.0)
          .chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 55,
    ),
  ]).animate(_controller);

  @override
  void didUpdateWidget(PopBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.valueKey != oldWidget.valueKey) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) =>
          Transform.scale(scale: _scale.value, child: child),
      child: widget.child,
    );
  }
}

/// Mobbin-style sleek sliding pill segment selector.
class SleekSegmentedControl<T> extends StatelessWidget {
  const SleekSegmentedControl({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.borderRadius,
    this.height = 42,
  });

  final Map<T, String> items;
  final T selected;
  final ValueChanged<T> onChanged;
  final BorderRadius? borderRadius;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final keys = items.keys.toList();
    final selectedIndex = keys.indexOf(selected);
    final radius = borderRadius ?? BorderRadius.circular(12);

    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5),
        borderRadius: radius,
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
          width: 1,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth) / keys.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                left: selectedIndex >= 0 ? selectedIndex * itemWidth : 0,
                top: 0,
                bottom: 0,
                width: itemWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF27272A) : Colors.white,
                    borderRadius: BorderRadius.circular(radius.topLeft.x - 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1.5),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final key in keys)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (key != selected) {
                            HapticFeedback.selectionClick();
                            onChanged(key);
                          }
                        },
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 150),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: key == selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: key == selected
                                  ? (isDark ? Colors.white : const Color(0xFF09090B))
                                  : (isDark
                                      ? const Color(0xFFA1A1AA)
                                      : const Color(0xFF71717A)),
                            ),
                            child: Text(items[key]!),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
