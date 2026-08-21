import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

export 'package:mqtt_client/mqtt_client.dart' show MqttConnectionState;

import '../config/mqtt_config.dart';

/// Singleton MQTT service for AGRI-MOTION.
///
/// Manages a single persistent MQTT connection used by all screens.
/// Provides:
/// - [connect] / [disconnect] lifecycle
/// - [publishCommand] to send actuator commands to ESP32
/// - [onStatusReceived] stream for ESP32 status feedback
/// - [connectionState] notifier for UI connection indicators
/// - Automatic reconnection on disconnection
///
/// Usage:
/// ```dart
/// // Connect (once at app start)
/// await MqttService.instance.connect();
///
/// // Publish a command
/// MqttService.instance.publishCommand('D1_PUPUK_ON');
///
/// // Listen for status
/// MqttService.instance.onStatusReceived.listen((status) {
///   print('ESP32 says: $status');
/// });
/// ```
class MqttService {
  MqttService._internal();

  /// Singleton instance — safe to access from any screen.
  static final MqttService instance = MqttService._internal();

  MqttServerClient? _client;
  Timer? _reconnectTimer;

  /// Stream controller for status messages from ESP32.
  /// Broadcasts so multiple listeners can subscribe simultaneously.
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  /// Stream of status messages received from `agrimotion/device/pumps/status`.
  ///
  /// Messages are raw strings as published by the ESP32 firmware, e.g.:
  /// - `"STATUS: Pupuk Demplot 1 ON"`
  /// - `"STATUS: EMERGENCY ALL OFF Dieksekusi!"`
  /// - `"SISTEM SIAP: ESP32 Pumps Controller Terhubung"`
  Stream<String> get onStatusReceived => _statusController.stream;

  /// Notifier for the current MQTT connection state.
  /// Use with [ValueListenableBuilder] in widgets for reactive UI updates.
  final ValueNotifier<MqttConnectionState> connectionState =
      ValueNotifier<MqttConnectionState>(MqttConnectionState.disconnected);

  /// Whether the MQTT client is currently connected to the broker.
  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  // ---------------------------------------------------------------------------
  // CONNECT
  // ---------------------------------------------------------------------------

  /// Connects to the MQTT broker.
  ///
  /// Safe to call multiple times — will no-op if already connected.
  /// On success, automatically subscribes to the status topic.
  /// On failure, schedules an automatic reconnection attempt.
  Future<void> connect() async {
    // Already connected — do nothing
    if (isConnected) return;

    // Generate unique client ID to avoid broker collision
    final clientId =
        '${MqttConfig.clientIdPrefix}-${DateTime.now().millisecondsSinceEpoch}';

    _client = MqttServerClient.withPort(
      MqttConfig.brokerHost,
      clientId,
      MqttConfig.brokerPort,
    );

    _client!
      ..logging(on: false) // Set to true for debug
      ..keepAlivePeriod = MqttConfig.keepAlivePeriod
      ..connectTimeoutPeriod = MqttConfig.connectTimeout.inMilliseconds
      ..autoReconnect = false // We handle reconnect manually for more control
      ..onConnected = _onConnected
      ..onDisconnected = _onDisconnected;

    // Build the connection message
    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atMostOnce);
    _client!.connectionMessage = connMessage;

    try {
      debugPrint(
          '[MqttService] Connecting to ${MqttConfig.brokerHost}:${MqttConfig.brokerPort} ...');
      connectionState.value = MqttConnectionState.connecting;

      await _client!.connect();
    } on NoConnectionException catch (e) {
      debugPrint('[MqttService] NoConnectionException: $e');
      _client!.disconnect();
      _scheduleReconnect();
    } on SocketException catch (e) {
      debugPrint('[MqttService] SocketException: $e');
      _client!.disconnect();
      _scheduleReconnect();
    } catch (e) {
      debugPrint('[MqttService] Connection error: $e');
      _client!.disconnect();
      _scheduleReconnect();
    }
  }

  // ---------------------------------------------------------------------------
  // DISCONNECT
  // ---------------------------------------------------------------------------

  /// Gracefully disconnects from the MQTT broker.
  ///
  /// Cancels any pending reconnection timer. Call this when the app
  /// is being disposed or when the user explicitly disconnects.
  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    if (_client != null) {
      _client!.disconnect();
      _client = null;
    }

    connectionState.value = MqttConnectionState.disconnected;
    debugPrint('[MqttService] Disconnected.');
  }

  // ---------------------------------------------------------------------------
  // PUBLISH
  // ---------------------------------------------------------------------------

  /// Publishes a command string to the ESP32 pumps controller.
  ///
  /// [command] — the payload string, e.g., `"D1_PUPUK_ON"`, `"ALL_OFF"`.
  /// Returns `true` if the message was published, `false` if not connected.
  bool publishCommand(String command) {
    if (!isConnected) {
      debugPrint(
          '[MqttService] Cannot publish — not connected. Command: $command');
      return false;
    }

    final builder = MqttClientPayloadBuilder();
    builder.addString(command);

    _client!.publishMessage(
      MqttConfig.topicCmd,
      MqttQos.atMostOnce,
      builder.payload!,
    );

    debugPrint('[MqttService] Published → ${MqttConfig.topicCmd}: $command');
    return true;
  }

  // ---------------------------------------------------------------------------
  // CALLBACKS
  // ---------------------------------------------------------------------------

  void _onConnected() {
    debugPrint('[MqttService] ✅ Connected to MQTT broker!');
    connectionState.value = MqttConnectionState.connected;

    // Cancel any pending reconnect timer
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    // Subscribe to status topic
    _client!.subscribe(MqttConfig.topicStatus, MqttQos.atMostOnce);
    debugPrint('[MqttService] Subscribed to ${MqttConfig.topicStatus}');

    // Listen for incoming messages
    _client!.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (final msg in messages) {
        final payload = msg.payload as MqttPublishMessage;
        final text = MqttPublishPayload.bytesToStringAsString(
          payload.payload.message,
        );

        debugPrint('[MqttService] ← ${msg.topic}: $text');

        if (msg.topic == MqttConfig.topicStatus) {
          _statusController.add(text);
        }
      }
    });
  }

  void _onDisconnected() {
    debugPrint('[MqttService] ⚠️ Disconnected from MQTT broker.');
    connectionState.value = MqttConnectionState.disconnected;

    // Auto-reconnect
    _scheduleReconnect();
  }

  // ---------------------------------------------------------------------------
  // RECONNECT
  // ---------------------------------------------------------------------------

  void _scheduleReconnect() {
    // Avoid stacking multiple timers
    if (_reconnectTimer?.isActive ?? false) return;

    debugPrint(
      '[MqttService] Scheduling reconnect in ${MqttConfig.reconnectDelay.inSeconds}s...',
    );

    _reconnectTimer = Timer(MqttConfig.reconnectDelay, () {
      debugPrint('[MqttService] Attempting reconnection...');
      connect();
    });
  }

  /// Disposes resources. Call only when the app is truly shutting down.
  void dispose() {
    disconnect();
    _statusController.close();
    connectionState.dispose();
  }
}
