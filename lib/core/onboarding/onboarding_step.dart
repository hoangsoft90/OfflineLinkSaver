import 'package:flutter/material.dart';

/// A single step in the onboarding flow.
///
/// Each step highlights a target widget on screen and shows a tooltip
/// explaining what the feature does. Steps are played in order.
class OnboardingStep {
  /// Unique key to persist "has seen" state in SharedPreferences.
  final String id;

  /// GlobalKey assigned to the target widget so we can read its
  /// RenderBox position at runtime.  The caller must attach the same
  /// key to the actual widget in the tree.
  final GlobalKey targetKey;

  /// Title shown in the tooltip header.
  final String title;

  /// Body text explaining the feature.
  final String message;

  /// Where the tooltip arrow points relative to the target.
  /// Defaults to [TooltipPosition.bottom].
  final TooltipPosition position;

  /// Optional: a badge label to show on the target while the tooltip
  /// is NOT visible (e.g. "New").  Set to null to skip the badge.
  final String? badgeLabel;

  /// Which step number this is (1-based).  Used by the progress dots.
  final int stepNumber;

  /// Total number of steps.  Same for every step in the same flow.
  final int totalSteps;

  const OnboardingStep({
    required this.id,
    required this.targetKey,
    required this.title,
    required this.message,
    this.position = TooltipPosition.bottom,
    this.badgeLabel,
    required this.stepNumber,
    required this.totalSteps,
  });

  /// Whether this is the last step in the flow.
  bool get isLast => stepNumber == totalSteps;
}

/// Tooltip placement relative to the target widget.
enum TooltipPosition { top, bottom, left, right }
