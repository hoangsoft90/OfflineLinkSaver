import 'package:flutter/material.dart';

/// A non-intrusive tooltip that explains why a button/widget is disabled.
///
/// When the user taps a disabled button wrapped with this widget, a
/// [Tooltip] or [ShowModalBottomSheet] appears explaining:
///   - WHY it is disabled
///   - WHAT condition unlocks it
///
/// This prevents confusion ("why can't I tap this?") and guides the user
/// toward the unlock condition.
///
/// Usage:
///   DisabledStateHelper(
///     reason: 'Save at least 1 article first',
///     unlockHint: 'Add a URL from the home screen',
///     child: IconButton(
///       icon: Icon(Icons.download),
///       onPressed: null, // disabled
///     ),
///   )
class DisabledStateHelper extends StatefulWidget {
  /// The child widget (typically has `onPressed: null` to appear disabled).
  final Widget child;

  /// Human-readable explanation of WHY the widget is disabled.
  final String reason;

  /// Actionable hint telling the user HOW to unlock this feature.
  final String unlockHint;

  /// How to present the hint.  Defaults to [DisabledHintStyle.tooltip].
  final DisabledHintStyle style;

  /// If true, the hint will auto-dismiss after [autoDismissDuration].
  /// Only applies to [DisabledHintStyle.tooltip] style.
  final bool autoDismiss;

  /// Duration before auto-dismiss.  Defaults to 4 seconds.
  final Duration autoDismissDuration;

  /// Persistence key.  If set, the hint is shown only once per unique key
  /// (tracked via OnboardingState).  Set to null to always show.
  final String? persistenceKey;

  const DisabledStateHelper({
    super.key,
    required this.child,
    required this.reason,
    required this.unlockHint,
    this.style = DisabledHintStyle.tooltip,
    this.autoDismiss = true,
    this.autoDismissDuration = const Duration(seconds: 4),
    this.persistenceKey,
  });

  @override
  State<DisabledStateHelper> createState() => _DisabledStateHelperState();
}

class _DisabledStateHelperState extends State<DisabledStateHelper> {
  final GlobalKey _childKey = GlobalKey();

  void _showHint() {
    switch (widget.style) {
      case DisabledHintStyle.tooltip:
        _showTooltip();
        break;
      case DisabledHintStyle.bottomSheet:
        _showBottomSheet();
        break;
    }
  }

  void _showTooltip() {
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final renderObj =
        _childKey.currentContext?.findRenderObject();
    if (renderObj is! RenderBox) return;

    final offset = renderObj.localToGlobal(Offset.zero);
    final size = renderObj.size;

    // Position tooltip above the widget
    final entry = OverlayEntry(
      builder: (context) => _TooltipOverlay(
        targetTop: offset.dy,
        targetCenter: offset.dx + size.width / 2,
        reason: widget.reason,
        unlockHint: widget.unlockHint,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);

    // Auto dismiss
    if (widget.autoDismiss) {
      Future.delayed(widget.autoDismissDuration, () {
        if (entry.mounted) entry.remove();
      });
    }
  }

  void _showBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Icon + title
            Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Feature Locked',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Reason
            Text(
              widget.reason,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 12),

            // Unlock hint
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.unlockHint,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Got it button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _childKey,
      // Always intercept taps — even when child is disabled
      onTap: _showHint,
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}

/// Presentation style for the disabled hint.
enum DisabledHintStyle {
  /// Floating tooltip anchored above the widget.
  tooltip,

  /// Material bottom sheet with more room for explanation.
  bottomSheet,
}

// ─── Tooltip overlay ──────────────────────────────────────────────────────────

class _TooltipOverlay extends StatefulWidget {
  final double targetTop;
  final double targetCenter;
  final String reason;
  final String unlockHint;
  final VoidCallback onDismiss;

  const _TooltipOverlay({
    required this.targetTop,
    required this.targetCenter,
    required this.reason,
    required this.unlockHint,
    required this.onDismiss,
  });

  @override
  State<_TooltipOverlay> createState() => _TooltipOverlayState();
}

class _TooltipOverlayState extends State<_TooltipOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _fade;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _opacity = CurvedAnimation(parent: _fade, curve: Curves.easeOut);
    _fade.forward();
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _fade.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    const cardWidth = 260.0;
    const gap = 8.0;

    final left = (widget.targetCenter - cardWidth / 2)
        .clamp(16.0, MediaQuery.of(context).size.width - cardWidth - 16.0);
    final top = widget.targetTop - 120 - gap; // above the target

    return Stack(
      children: [
        // Tap anywhere to dismiss
        Positioned.fill(
          child: GestureDetector(
            onTap: _dismiss,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),

        // Tooltip card
        Positioned(
          top: top,
          left: left,
          width: cardWidth,
          child: FadeTransition(
            opacity: _opacity,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.reason,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.unlockHint,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
