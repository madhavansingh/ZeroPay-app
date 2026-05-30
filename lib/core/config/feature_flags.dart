class FeatureFlagService {
  FeatureFlagService._();

  static final Map<String, bool> _flags = {
    'beta_cardano_ledger': false,
    'ai_negotiation_negotiator': true,
    'arbitration_court_litigation': true,
    'telemetry_live_aggregates': true,
    'offline_first_commerce': true,
    'biometric_sensitive_confirmations': true,
  };

  static final Map<String, double> _rolloutPercentages = {
    'new_payout_ui': 0.15, // 15% progressive rollout
  };

  // Get flag status
  static bool isFeatureEnabled(String flagName, [String? userUid]) {
    if (!_flags.containsKey(flagName)) return false;

    // Check emergency kill switch
    if (_flags[flagName] == false) return false;

    // Check progressive rollout percentage
    if (_rolloutPercentages.containsKey(flagName) && userUid != null) {
      final hash = userUid.hashCode.abs() % 100;
      final target = (_rolloutPercentages[flagName]! * 100).toInt();
      return hash < target;
    }

    return _flags[flagName]!;
  }

  // Emergency toggle override
  static void setEmergencyKillSwitch(String flagName, bool enabled) {
    if (_flags.containsKey(flagName)) {
      _flags[flagName] = enabled;
    }
  }

  // Remote config rollout updates
  static void updateRolloutPercentage(String flagName, double percentage) {
    _rolloutPercentages[flagName] = percentage.clamp(0.0, 1.0);
  }
}
