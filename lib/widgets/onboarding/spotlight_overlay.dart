import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/onboarding/onboarding_step.dart';

/// A full-screen overlay that dims the background and draws a "spotlight"
/// circle around a target widget, then shows a tooltip card attached to it.
///
/// The overlay is drawn via [Stack] on top of the normal content.  It
/// calculates the target's position using [GlobalKey] → [RenderBox] and
/// positions the tooltip accordingly.
///
/// Usage:
///   SpotlightOverlay(
///     step: currentStep,
///     onNext: () => nextStep(),
///     onSkip: () => skipAll(),
///   )
class SpotlightOverlay extends StatelessWidget {
  final OnboardingStep step;
  final VoidCallback onNext;
  final VoidCallback? onSkip;

  /// Padding around the target widget for the spotlight circle.
  final double spotlightPadding;

  /// Radius of the spotlight cut-out.  If null, auto-calculated from
  /// the target widget's size.
  final double? spotlightRadius;

  const SpotlightOverlay({
    super.key,
    required this.step,
    required this.onNext,
    this.onSkip,
    this.spotlightPadding = 12,
    this.spotlightRadius,
  });

  /// Resolve the target widget's position and size on screen.
  _TargetInfo? _getTargetInfo() {
    final key = step.targetKey;
    final renderObj = key.currentContext?.findRenderObject();
    if (renderObj is! RenderBox) return null;
    final size = renderObj.size;
    final offset = renderObj.localToGlobal(Offset.zero);
    return _TargetInfo(
      rect: Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height),
      center: Offset(
        offset.dx + size.width / 2,
        offset.dy + size.height / 2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final target = _getTargetInfo();
    if (target == null) {
      // Target not yet laid out — show nothing this frame.
      return const SizedBox.shrink();
    }

    final screenSize = MediaQuery.of(context).size;
    final radius =
        spotlightRadius ?? math.max(target.rect.width, target.rect.height) / 2 + spotlightPadding;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // ── Dim background with spotlight cut-out ──
            CustomPaint(
              size: Size(screenSize.width, screenSize.height),
              painter: _SpotlightPainter(
                center: target.center,
                radius: radius,
              ),
            ),

            // ── Tooltip card ──
            _PositionedTooltip(
              target: target,
              step: step,
              screenSize: screenSize,
              onNext: onNext,
              onSkip: onSkip,
            ),
          ],
        );
      },
    );
  }
}

// ─── Spotlight painter ────────────────────────────────────────────────────────

/// Draws a full-screen dimmed rectangle with a circular transparent hole.
class _SpotlightPainter extends CustomPainter {
  final Offset center;
  final double radius;

  _SpotlightPainter({required this.center, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    // Dim layer
    final dimPaint = Paint()..color = Colors.black.withOpacity(0.55);
    canvas.drawRect(Offset.zero & size, dimPaint);

    // Cut-out circle (destination-out composite)
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    canvas.drawCircle(center, radius, clearPaint);
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.center != center || old.radius != radius;
}

// ─── Positioned tooltip ────────────────────────────────────────────────────────

class _PositionedTooltip extends StatelessWidget {
  final _TargetInfo target;
  final OnboardingStep step;
  final Size screenSize;
  final VoidCallback onNext;
  final VoidCallback? onSkip;

  const _PositionedTooltip({
    required this.target,
    required this.step,
    required this.screenSize,
    required this.onNext,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    // Tooltip card dimensions (estimated; actual layout may vary)
    const cardWidth = 260.0;
    const cardHeight = 160.0;
    const gap = 14.0; // space between target and tooltip

    final targetCenter = target.center;
    double top;
    double left;

    // ── Compute position based on [TooltipPosition] ──
    switch (step.position) {
      case TooltipPosition.bottom:
        top = target.rect.bottom + gap;
        left = (targetCenter.dx - cardWidth / 2)
            .clamp(16.0, screenSize.width - cardWidth - 16.0);
        break;
      case TooltipPosition.top:
        top = target.rect.top - cardHeight - gap;
        left = (targetCenter.dx - cardWidth / 2)
            .clamp(16.0, screenSize.width - cardWidth - 16.0);
        break;
      case TooltipPosition.left:
        top = (targetCenter.dy - cardHeight / 2)
            .clamp(16.0, screenSize.height - cardHeight - 16.0);
        left = target.rect.left - cardWidth - gap;
        break;
      case TooltipPosition.right:
        top = (targetCenter.dy - cardHeight / 2)
            .clamp(16.0, screenSize.height - cardHeight - 16.0);
        left = target.rect.right + gap;
        break;
    }

    // Clamp so tooltip never goes off-screen
    left = left.clamp(8.0, screenSize.width - cardWidth - 8.0);
    top = top.clamp(8.0, screenSize.height - cardHeight - 8.0);

    final isLast = step.isLast;

    return Positioned(
      top: top,
      left: left,
      width: cardWidth,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Step indicator ──
              Row(
                children: [
                  _StepDots(current: step.stepNumber, total: step.totalSteps),
                  const Spacer(),
                  if (!isLast && onSkip != null)
                    TextButton(
                      onPressed: onSkip,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // ── Title ──
              Text(
                step.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),

              // ── Body ──
              Text(
                step.message,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 12),

              // ── Action button ──
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(isLast ? 'Done' : 'Next'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Step progress dots ────────────────────────────────────────────────────────

class _StepDots extends StatelessWidget {
  final int current;
  final int total;

  const _StepDots({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final isActive = i < current;
        return Container(
          width: isActive ? 8 : 6,
          height: isActive ? 8 : 6,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: isActive ? primary : primary.withOpacity(0.25),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

// ─── Helper data class ─────────────────────────────────────────────────────────

class _TargetInfo {
  final Rect rect;
  final Offset center;

  const _TargetInfo({required this.rect, required this.center});
}
