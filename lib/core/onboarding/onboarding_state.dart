import 'package:shared_preferences/shared_preferences.dart';

/// Manages onboarding state persisted in SharedPreferences.
///
/// Keys stored:
///   - `onboarding_seen_<stepId>` → bool   — whether a specific step was shown
///   - `onboarding_flow_<flowId>` → bool   — whether the entire flow is complete
///   - `onboarding_disabled_<key>` → bool  — whether user acknowledged a disabled-state hint
///
/// Usage:
///   final state = OnboardingState();
///   await state.init();                       // call once in main()
///   final hasSeen = await state.hasSeenStep('add_url');
///   await state.markStepSeen('add_url');
class OnboardingState {
  static SharedPreferences? _prefs;

  /// Call once at app startup, before any onboarding UI.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get _store {
    assert(_prefs != null, 'OnboardingState.init() must be called first');
    return _prefs!;
  }

  // ─── Step-level helpers ──────────────────────────────────────────────

  /// Has the user already seen this specific step?
  Future<bool> hasSeenStep(String stepId) async {
    return _store.getBool('onboarding_seen_$stepId') ?? false;
  }

  /// Mark a single step as seen.
  Future<void> markStepSeen(String stepId) async {
    await _store.setBool('onboarding_seen_$stepId', true);
  }

  /// Reset a single step (useful for debugging / re-showing onboarding).
  Future<void> resetStep(String stepId) async {
    await _store.remove('onboarding_seen_$stepId');
  }

  // ─── Flow-level helpers ──────────────────────────────────────────────

  /// Has the user completed the entire onboarding flow?
  Future<bool> hasCompletedFlow(String flowId) async {
    return _store.getBool('onboarding_flow_$flowId') ?? false;
  }

  /// Mark an entire flow as completed.
  Future<void> markFlowCompleted(String flowId) async {
    await _store.setBool('onboarding_flow_$flowId', true);
  }

  /// Reset a flow so it shows again.
  Future<void> resetFlow(String flowId) async {
    await _store.remove('onboarding_flow_$flowId');
  }

  // ─── Disabled-state helpers ─────────────────────────────────────────

  /// Has the user acknowledged the disabled-state hint for a given key?
  Future<bool> hasAcknowledgedDisabledHint(String key) async {
    return _store.getBool('onboarding_disabled_$key') ?? false;
  }

  /// Mark a disabled-state hint as acknowledged.
  Future<void> acknowledgeDisabledHint(String key) async {
    await _store.setBool('onboarding_disabled_$key', true);
  }

  // ─── Bulk helpers ───────────────────────────────────────────────────

  /// Clear ALL onboarding data (factory-reset onboarding).
  Future<void> resetAll() async {
    final keys = _store.getKeys().where(
      (k) =>
          k.startsWith('onboarding_seen_') ||
          k.startsWith('onboarding_flow_') ||
          k.startsWith('onboarding_disabled_'),
    );
    for (final key in keys) {
      await _store.remove(key);
    }
  }
}
