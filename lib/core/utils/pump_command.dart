/// Helper to generate MQTT command payload strings for the ESP32 Pumps Controller.
///
/// Payload format matches the firmware's `mqttCallback` router exactly:
/// - "D1_PUPUK_ON", "D1_PUPUK_OFF"
/// - "D1_PESTI_ON", "D1_PESTI_OFF"
/// - "D1_AIR_ON",   "D1_AIR_OFF"
/// - "D2_PUPUK_ON", "D2_PUPUK_OFF"
/// - ... (same pattern for D2, D3)
/// - "ALL_OFF" (emergency stop)
class PumpCommand {
  PumpCommand._(); // Prevent instantiation

  /// Builds a command payload string.
  ///
  /// [demplotIndex] — 0-based index matching `DemplotConfig.demplots`:
  ///   0 = Demplot 1, 1 = Demplot 2, 2 = Demplot 3
  ///
  /// [type] — actuator type: `'PUPUK'`, `'PESTI'`, or `'AIR'`
  ///
  /// [turnOn] — `true` to activate (ON), `false` to deactivate (OFF)
  ///
  /// Returns: e.g., `"D1_PUPUK_ON"`, `"D2_PESTI_OFF"`, `"D3_AIR_ON"`
  static String build({
    required int demplotIndex,
    required String type,
    required bool turnOn,
  }) {
    final prefix = 'D${demplotIndex + 1}';
    final suffix = turnOn ? 'ON' : 'OFF';
    return '${prefix}_${type}_$suffix';
  }

  /// Convenience: build a fertilizer (Pupuk Cair) command.
  static String fertilizer({required int demplotIndex, required bool turnOn}) {
    return build(demplotIndex: demplotIndex, type: 'PUPUK', turnOn: turnOn);
  }

  /// Convenience: build a pesticide (Pestisida) command.
  static String pesticide({required int demplotIndex, required bool turnOn}) {
    return build(demplotIndex: demplotIndex, type: 'PESTI', turnOn: turnOn);
  }

  /// Convenience: build a water-only (Siram Air Saja) command.
  static String water({required int demplotIndex, required bool turnOn}) {
    return build(demplotIndex: demplotIndex, type: 'AIR', turnOn: turnOn);
  }

  /// Emergency stop — shuts down ALL relays on the ESP32.
  static const String emergencyOff = 'ALL_OFF';
}
