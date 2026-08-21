import 'package:flutter/material.dart';
import '../../core/onboarding/onboarding_state.dart';
import '../../core/onboarding/onboarding_step.dart';
import 'spotlight_overlay.dart';

/// Orchestrates a multi-step onboarding flow.
///
/// Shows a [SpotlightOverlay] for each step in sequence, persists
/// "seen" state in [OnboardingState], and renders a skip/done UI.
///
/// ```dart
/// OnboardingCoordinator(
///   flowId: 'home_v1',
///   state: onboardingState,
///   steps: [
///     OnboardingStep(
///       id: 'add_url',
///       targetKey: _addUrlKey,
///       title: 'Add a link',
///       message: 'Tap here to paste any URL...',
///       stepNumber: 1,
///       totalSteps: 3,
///     ),
///     ...
///   ],
///   child: HomeContent(),
/// )
/// ```
///
/// The coordinator wraps [child] in a [Stack] so the overlay draws on top.
/// It only shows steps whose [OnboardingStep.id] has NOT been seen yet.
class OnboardingCoordinator extends StatefulWidget {
  /// Unique ID for this flow.  Used to persist completion state.
  final String flowId;

  /// Shared state manager for persistence.
  final OnboardingState state;

  /// Ordered list of steps to play through.
  final List<OnboardingStep> steps;

  /// The main app content to show behind the overlay.
  final Widget child;

  /// Called when the user completes or skips the entire flow.
  final VoidCallback? onFlowComplete;

  /// Whether onboarding is enabled.  Defaults to true.
  /// Set to false to completely disable (e.g. for returning users).
  final bool enabled;

  const OnboardingCoordinator({
    super.key,
    required this.flowId,
    required this.state,
    required this.steps,
    required this.child,
    this.onFlowComplete,
    this.enabled = true,
  });

  @override
  State<OnboardingCoordinator> createState() => _OnboardingCoordinatorState();
}

class _OnboardingCoordinatorState extends State<OnboardingCoordinator> {
  int _currentStepIndex = 0;
  bool _showOverlay = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initOnboarding();
  }

  Future<void> _initOnboarding() async {
    if (!widget.enabled) {
      setState(() => _initialized = true);
      return;
    }

    // Check if entire flow was already completed
    final completed = await widget.state.hasCompletedFlow(widget.flowId);
    if (completed) {
      setState(() => _initialized = true);
      return;
    }

    // Find the first unseen step
    int startIndex = 0;
    for (int i = 0; i < widget.steps.length; i++) {
      final seen = await widget.state.hasSeenStep(widget.steps[i].id);
      if (seen) {
        startIndex = i + 1;
      } else {
        break;
      }
    }

    // All steps already seen — mark flow complete
    if (startIndex >= widget.steps.length) {
      await widget.state.markFlowCompleted(widget.flowId);
      setState(() => _initialized = true);
      return;
    }

    _currentStepIndex = startIndex;
    // Wait one frame for target widgets to be laid out before showing overlay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _showOverlay = true;
          _initialized = true;
        });
      }
    });
  }

  Future<void> _nextStep() async {
    final step = widget.steps[_currentStepIndex];
    await widget.state.markStepSeen(step.id);

    if (step.isLast) {
      // Flow complete
      await widget.state.markFlowCompleted(widget.flowId);
      setState(() => _showOverlay = false);
      widget.onFlowComplete?.call();
    } else {
      setState(() {
        _currentStepIndex++;
      });
    }
  }

  Future<void> _skip() async {
    // Mark all remaining steps as seen
    for (int i = _currentStepIndex; i < widget.steps.length; i++) {
      await widget.state.markStepSeen(widget.steps[i].id);
    }
    await widget.state.markFlowCompleted(widget.flowId);
    setState(() => _showOverlay = false);
    widget.onFlowComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content
        widget.child,

        // Spotlight overlay
        if (_showOverlay && _initialized)
          SpotlightOverlay(
            step: widget.steps[_currentStepIndex],
            onNext: _nextStep,
            onSkip: _skip,
          ),
      ],
    );
  }
}
