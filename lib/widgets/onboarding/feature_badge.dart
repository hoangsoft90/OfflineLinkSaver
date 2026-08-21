import 'package:flutter/material.dart';

/// A small badge that sits on top of a child widget (typically an icon button)
/// to draw attention to a new feature.
///
/// Shows either a pulsing dot or a text label (e.g. "New") depending on
/// [variant].
///
/// Usage:
///   FeatureBadge(
///     child: IconButton(icon: Icon(Icons.add), onPressed: ...),
///   )
class FeatureBadge extends StatelessWidget {
  /// The widget to wrap.  The badge is positioned at the top-right corner.
  final Widget child;

  /// Text label shown next to the dot.  If null, only a dot is shown.
  final String? label;

  /// Which visual variant to use.
  final BadgeVariant variant;

  /// Badge color.  Defaults to the theme's error color (red).
  final Color? color;

  /// Whether to show the badge at all.  Useful for conditionally showing
  /// it based on onboarding state.
  final bool visible;

  const FeatureBadge({
    super.key,
    required this.child,
    this.label,
    this.variant = BadgeVariant.dot,
    this.color,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return child;

    final badgeColor = color ?? Theme.of(context).colorScheme.error;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -2,
          right: -2,
          child: variant == BadgeVariant.dot
              ? _DotBadge(color: badgeColor)
              : _LabelBadge(label: label ?? 'New', color: badgeColor),
        ),
      ],
    );
  }
}

/// Variants for the badge appearance.
enum BadgeVariant {
  /// A small pulsing dot — minimal visual weight.
  dot,

  /// A small chip with text like "New".
  label,
}

// ─── Dot badge ────────────────────────────────────────────────────────────────

class _DotBadge extends StatefulWidget {
  final Color color;
  const _DotBadge({required this.color});

  @override
  State<_DotBadge> createState() => _DotBadgeState();
}

class _DotBadgeState extends State<_DotBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final scale = 1.0 + _pulse.value * 0.3;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.4 + _pulse.value * 0.3),
                  blurRadius: 4 + _pulse.value * 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Label badge ──────────────────────────────────────────────────────────────

class _LabelBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _LabelBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
    );
  }
}
