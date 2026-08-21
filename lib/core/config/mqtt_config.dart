/// Centralized MQTT configuration for AGRI-MOTION.
///
/// Mirrors the ESP32 firmware settings so both ends
/// agree on broker address, topics, and QoS.
///
/// Broker runs on the same VPS as the NestJS backend (103.174.114.65).
class MqttConfig {
  MqttConfig._(); // Prevent instantiation

  // ---------------------------------------------------------------------------
  // Broker Connection
  // ---------------------------------------------------------------------------

  /// MQTT broker hostname / IP — same VPS as the REST API.
  static const String brokerHost = '103.174.114.65';

  /// MQTT broker port (default, non-TLS).
  static const int brokerPort = 1883;

  /// Client ID prefix. A unique suffix (timestamp) is appended at runtime
  /// to avoid MQTT client-id collisions across multiple phones.
  static const String clientIdPrefix = 'agrimotion-mobile';

  // ---------------------------------------------------------------------------
  // Topics — must match ESP32 firmware exactly
  // ---------------------------------------------------------------------------

  /// Topic to PUBLISH actuator commands (mobile → ESP32).
  /// ESP32 subscribes to this topic.
  static const String topicCmd = 'agrimotion/device/pumps/cmd';

  /// Topic to SUBSCRIBE for actuator status feedback (ESP32 → mobile).
  /// ESP32 publishes status messages to this topic.
  static const String topicStatus = 'agrimotion/device/pumps/status';

  // ---------------------------------------------------------------------------
  // Connection Parameters
  // ---------------------------------------------------------------------------

  /// MQTT keep-alive interval in seconds.
  /// Broker will consider the client disconnected if no PING is received
  /// within 1.5× this value.
  static const int keepAlivePeriod = 30;

  /// Delay between automatic reconnection attempts.
  static const Duration reconnectDelay = Duration(seconds: 5);

  /// Connection timeout — how long to wait for CONNACK from broker.
  static const Duration connectTimeout = Duration(seconds: 10);
}
