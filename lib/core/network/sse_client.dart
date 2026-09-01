import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:agrimotion/core/constants/api_constants.dart';

// =============================================================================
// LOG LEVEL & LOG ENTRY MODELS
// =============================================================================

/// Severity and categorization levels for server diagnostics and event streams.
enum LogLevel {
  info,
  warn,
  error,
  debug,
  http,
  mqtt;

  /// Returns the uppercase string tag (e.g., "INFO", "HTTP", "MQTT").
  String get label => name.toUpperCase();
}

/// Represents a single real-time or historical server log entry.
class LogEntry {
  /// The descriptive body of the log message.
  final String message;

  /// Severity / category level of this log record.
  final LogLevel level;

  /// Timestamp when the log event occurred on server or device.
  final DateTime timestamp;

  /// Optional module or subsystem source (e.g., "TelemetryService", "MqttBroker").
  final String? source;

  /// Optional structured metadata attributes.
  final Map<String, dynamic>? metadata;

  const LogEntry({
    required this.message,
    required this.level,
    required this.timestamp,
    this.source,
    this.metadata,
  });

  // ---------------------------------------------------------------------------
  // FACTORIES & SERIALIZATION
  // ---------------------------------------------------------------------------

  /// Parses a raw console or stream text line into a structured [LogEntry].
  ///
  /// Supports:
  /// - Standard NestJS/Node formatted strings: `[INFO] [TelemetryService] Telemetry received from node-1a`
  /// - Prefixed format: `[HTTP] POST /telemetry 201 Created - 12ms`
  /// - JSON structured payloads: `{"level":"warn","message":"High memory","timestamp":"..."}`
  /// - Plain unformatted log lines
  factory LogEntry.fromRawLine(String rawLine) {
    final String trimmed = rawLine.trim();
    if (trimmed.isEmpty) {
      return LogEntry(
        message: '',
        level: LogLevel.info,
        timestamp: DateTime.now(),
      );
    }

    // 1. Attempt JSON parsing
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final dynamic decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          return LogEntry.fromJson(decoded);
        }
      } catch (_) {
        // Fall back to regex / plain string parsing
      }
    }

    DateTime parsedTimestamp = DateTime.now();
    LogLevel parsedLevel = LogLevel.info;
    String? parsedSource;
    String parsedMessage = trimmed;

    // 2. Extract timestamp if present at beginning: [2026-08-27T02:30:42.000Z] or [2026-08-27 02:30:42]
    final RegExp timeRegex = RegExp(
      r'^\[(\d{4}-\d{2}-\d{2}[T\s]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?)\]\s*',
    );
    final RegExpMatch? timeMatch = timeRegex.firstMatch(parsedMessage);
    if (timeMatch != null) {
      final DateTime? dt = DateTime.tryParse(timeMatch.group(1)!);
      if (dt != null) {
        parsedTimestamp = dt;
      }
      parsedMessage = parsedMessage.substring(timeMatch.end);
    }

    // 3. Extract log level: [INFO], [WARN], [ERROR], [DEBUG], [HTTP], [MQTT]
    final RegExp levelRegex = RegExp(
      r'^\[(INFO|WARN|WARNING|ERROR|ERR|DEBUG|HTTP|MQTT)\]\s*',
      caseSensitive: false,
    );
    final RegExpMatch? levelMatch = levelRegex.firstMatch(parsedMessage);
    if (levelMatch != null) {
      final String tag = levelMatch.group(1)!.toUpperCase();
      switch (tag) {
        case 'WARN':
        case 'WARNING':
          parsedLevel = LogLevel.warn;
          break;
        case 'ERROR':
        case 'ERR':
          parsedLevel = LogLevel.error;
          break;
        case 'DEBUG':
          parsedLevel = LogLevel.debug;
          break;
        case 'HTTP':
          parsedLevel = LogLevel.http;
          break;
        case 'MQTT':
          parsedLevel = LogLevel.mqtt;
          break;
        case 'INFO':
        default:
          parsedLevel = LogLevel.info;
          break;
      }
      parsedMessage = parsedMessage.substring(levelMatch.end);
    }

    // 4. Extract optional source tag: [TelemetryService] or [Nest]
    final RegExp sourceRegex = RegExp(r'^\[([a-zA-Z0-9_\-\.\s]+)\]\s*');
    final RegExpMatch? sourceMatch = sourceRegex.firstMatch(parsedMessage);
    if (sourceMatch != null) {
      parsedSource = sourceMatch.group(1)!.trim();
      parsedMessage = parsedMessage.substring(sourceMatch.end);
    }

    return LogEntry(
      message: parsedMessage.trim(),
      level: parsedLevel,
      timestamp: parsedTimestamp,
      source: parsedSource,
    );
  }

  /// Deserializes a [LogEntry] from a JSON map.
  factory LogEntry.fromJson(Map<String, dynamic> json) {
    LogLevel parsedLevel = LogLevel.info;
    final String? rawLevel = json['level']?.toString().toLowerCase();
    if (rawLevel != null) {
      for (final LogLevel l in LogLevel.values) {
        if (l.name == rawLevel || l.name.toUpperCase() == rawLevel.toUpperCase()) {
          parsedLevel = l;
          break;
        }
      }
      if (rawLevel == 'warning') parsedLevel = LogLevel.warn;
      if (rawLevel == 'err') parsedLevel = LogLevel.error;
    }

    DateTime parsedTimestamp = DateTime.now();
    if (json['timestamp'] != null) {
      parsedTimestamp =
          DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now();
    }

    return LogEntry(
      message: json['message']?.toString() ?? '',
      level: parsedLevel,
      timestamp: parsedTimestamp,
      source: json['source']?.toString(),
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : null,
    );
  }

  /// Serializes this [LogEntry] to a JSON map.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'message': message,
        'level': level.name,
        'timestamp': timestamp.toIso8601String(),
        if (source != null) 'source': source,
        if (metadata != null) 'metadata': metadata,
      };

  // ---------------------------------------------------------------------------
  // FORMATTED DISPLAY GETTERS
  // ---------------------------------------------------------------------------

  /// Formatted time string in `HH:mm:ss.SSS` format.
  String get formattedTime {
    final String h = timestamp.hour.toString().padLeft(2, '0');
    final String m = timestamp.minute.toString().padLeft(2, '0');
    final String s = timestamp.second.toString().padLeft(2, '0');
    final String ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  /// Formatted date string in `YYYY-MM-DD` format.
  String get formattedDate {
    final String y = timestamp.year.toString();
    final String m = timestamp.month.toString().padLeft(2, '0');
    final String d = timestamp.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Formatted level tag string (e.g., "INFO", "WARN", "ERROR").
  String get levelTag => level.name.toUpperCase();

  /// Complete formatted console log line.
  /// Example: `[14:32:05.120] [INFO ] [TelemetryService] Telemetry received`
  String get formattedLine {
    final String src =
        source != null && source!.isNotEmpty ? ' [$source]' : '';
    return '[$formattedTime] [${levelTag.padRight(5)}]$src $message';
  }

  // Level predicates for easy filtering and UI coloring
  bool get isInfo => level == LogLevel.info;
  bool get isWarn => level == LogLevel.warn;
  bool get isError => level == LogLevel.error;
  bool get isDebug => level == LogLevel.debug;
  bool get isHttp => level == LogLevel.http;
  bool get isMqtt => level == LogLevel.mqtt;

  @override
  String toString() => formattedLine;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogEntry &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          level == other.level &&
          timestamp == other.timestamp &&
          source == other.source;

  @override
  int get hashCode => Object.hash(message, level, timestamp, source);
}

// =============================================================================
// SSE & WEBSOCKET CLIENT
// =============================================================================

enum SseConnectionState {
  connected,
  reconnecting,
  offline,
}

/// Real-time stream consumer supporting both Server-Sent Events (SSE)
/// and WebSocket protocols with automatic exponential backoff reconnection.
class SseClient {
  bool _isDisposed = false;
  final List<StreamController<String>> _activeControllers = [];
  final StreamController<SseConnectionState> _connectionStateController = StreamController<SseConnectionState>.broadcast();

  Stream<SseConnectionState> get connectionStateStream => _connectionStateController.stream;

  void _updateState(SseConnectionState state) {
    if (!_isDisposed && !_connectionStateController.isClosed) {
      _connectionStateController.add(state);
    }
  }

  /// Connects to a Server-Sent Events (SSE) endpoint and yields event payload strings.
  ///
  /// Features:
  /// - Sets `Accept: text/event-stream` and `Cache-Control: no-cache` headers.
  /// - Automatically reconnects with exponential backoff on stream termination or network error.
  /// - Parses multi-line or standard `data: ...` event chunks.
  /// - Closes cleanly when the stream is cancelled or [dispose] is called.
  Stream<String> connectSse(
    String url, {
    Map<String, String>? headers,
    Duration initialBackoff = const Duration(seconds: 2),
    Duration maxBackoff = const Duration(seconds: 10),
  }) {
    late final StreamController<String> controller;
    http.Client? httpClient;
    StreamSubscription<String>? lineSub;
    Timer? reconnectTimer;
    bool isCancelled = false;
    Duration currentBackoff = initialBackoff;
    _updateState(SseConnectionState.reconnecting);

    void cleanUpConnection() {
      reconnectTimer?.cancel();
      reconnectTimer = null;
      lineSub?.cancel();
      lineSub = null;
      try {
        httpClient?.close();
      } catch (_) {}
      httpClient = null;
    }

    late void Function() connect;

    void scheduleReconnect() {
      if (isCancelled || _isDisposed || controller.isClosed) return;
      cleanUpConnection();
      _updateState(SseConnectionState.reconnecting);

      reconnectTimer = Timer(currentBackoff, () {
        if (isCancelled || _isDisposed || controller.isClosed) return;

        // Exponential backoff doubling up to maxBackoff
        currentBackoff = Duration(
          milliseconds: (currentBackoff.inMilliseconds * 2)
              .clamp(initialBackoff.inMilliseconds, maxBackoff.inMilliseconds),
        );
        connect();
      });
    }

    connect = () async {
      if (isCancelled || _isDisposed || controller.isClosed) return;
      cleanUpConnection();

      try {
        httpClient = http.Client();
        final Uri uri = Uri.parse(url);
        final http.Request request = http.Request('GET', uri);

        request.headers['Accept'] = 'text/event-stream';
        request.headers['Cache-Control'] = 'no-cache';
        request.headers['Connection'] = 'keep-alive';

        if (headers != null) {
          request.headers.addAll(headers);
        }

        final http.StreamedResponse response = await httpClient!.send(request);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          scheduleReconnect();
          return;
        }

        // Reset backoff on successful connection
        currentBackoff = initialBackoff;
        _updateState(SseConnectionState.connected);

        final StringBuffer dataBuffer = StringBuffer();

        final Stream<String> lineStream = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter());

        lineSub = lineStream.listen(
          (String line) {
            if (controller.isClosed) return;
            final String trimmed = line.trim();

            if (trimmed.isEmpty) {
              // Empty line signals end of SSE event chunk
              if (dataBuffer.isNotEmpty) {
                controller.add(dataBuffer.toString());
                dataBuffer.clear();
              }
            } else if (trimmed.startsWith('data:')) {
              final String payload = trimmed.substring(5).trim();
              if (dataBuffer.isNotEmpty) {
                dataBuffer.writeln(payload);
              } else {
                dataBuffer.write(payload);
              }
            }
          },
          onError: (_) {
            scheduleReconnect();
          },
          onDone: () {
            if (dataBuffer.isNotEmpty && !controller.isClosed) {
              controller.add(dataBuffer.toString());
              dataBuffer.clear();
            }
            scheduleReconnect();
          },
          cancelOnError: true,
        );
      } catch (_) {
        scheduleReconnect();
      }
    };

    controller = StreamController<String>.broadcast(
      onListen: () {
        isCancelled = false;
        connect();
      },
      onCancel: () {
        isCancelled = true;
        cleanUpConnection();
        _updateState(SseConnectionState.offline);
      },
    );

    _activeControllers.add(controller);
    return controller.stream;
  }

  /// Connects to a WebSocket endpoint and yields incoming text messages.
  ///
  /// Features:
  /// - Automatic exponential backoff reconnection on socket close or network error.
  /// - Safe cleanup when the subscription is cancelled.
  Stream<String> connectWebSocket(
    String url, {
    Duration initialBackoff = const Duration(seconds: 1),
    Duration maxBackoff = const Duration(seconds: 30),
  }) {
    late final StreamController<String> controller;
    WebSocketChannel? channel;
    StreamSubscription<dynamic>? channelSub;
    Timer? reconnectTimer;
    bool isCancelled = false;
    Duration currentBackoff = initialBackoff;

    void cleanUpConnection() {
      reconnectTimer?.cancel();
      reconnectTimer = null;
      channelSub?.cancel();
      channelSub = null;
      try {
        channel?.sink.close();
      } catch (_) {}
      channel = null;
    }

    late void Function() connect;

    void scheduleReconnect() {
      if (isCancelled || _isDisposed || controller.isClosed) return;
      cleanUpConnection();
      _updateState(SseConnectionState.reconnecting);

      reconnectTimer = Timer(currentBackoff, () {
        if (isCancelled || _isDisposed || controller.isClosed) return;

        currentBackoff = Duration(
          milliseconds: (currentBackoff.inMilliseconds * 2)
              .clamp(initialBackoff.inMilliseconds, maxBackoff.inMilliseconds),
        );
        connect();
      });
    }

    connect = () {
      if (isCancelled || _isDisposed || controller.isClosed) return;
      cleanUpConnection();

      try {
        final Uri uri = Uri.parse(url);
        channel = WebSocketChannel.connect(uri);
        channel!.ready.then((_) {
           if (!isCancelled && !_isDisposed && !controller.isClosed) {
              _updateState(SseConnectionState.connected);
           }
        }).catchError((_) {});

        channelSub = channel!.stream.listen(
          (dynamic event) {
            if (controller.isClosed) return;
            // Connection is active, reset backoff
            currentBackoff = initialBackoff;
            controller.add(event.toString());
          },
          onError: (_) {
            scheduleReconnect();
          },
          onDone: () {
            scheduleReconnect();
          },
          cancelOnError: true,
        );
      } catch (_) {
        scheduleReconnect();
      }
    };

    controller = StreamController<String>.broadcast(
      onListen: () {
        isCancelled = false;
        connect();
      },
      onCancel: () {
        isCancelled = true;
        cleanUpConnection();
        _updateState(SseConnectionState.offline);
      },
    );

    _activeControllers.add(controller);
    return controller.stream;
  }

  /// Disposes all active stream controllers and terminates active network connections.
  void dispose() {
    _isDisposed = true;
    for (final StreamController<String> controller in _activeControllers) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _activeControllers.clear();
    if (!_connectionStateController.isClosed) {
       _connectionStateController.close();
    }
  }
}

// =============================================================================
// REAL SERVER LOG STREAM SERVICE
// =============================================================================

/// Real-time server log stream service that generates structured [LogEntry]
/// records from live backend API polling (health checks, system info,
/// and HTTP request/response metadata).
///
/// Replaces the previous MockLogStreamService with actual server diagnostics.
class ServerLogStreamService {
  final StreamController<LogEntry> _controller =
      StreamController<LogEntry>.broadcast();

  Timer? _pollingTimer;
  bool _isDisposed = false;
  bool _isRunning = false;
  final http.Client _client;

  /// Creates a [ServerLogStreamService] with an optional HTTP client.
  ServerLogStreamService({http.Client? client})
      : _client = client ?? http.Client() {
    _controller.onListen = _onListen;
    _controller.onCancel = _onCancel;
  }

  /// Broadcast stream of structured [LogEntry] events from real server.
  Stream<LogEntry> get logStream => _controller.stream;

  /// Whether the background polling is currently running.
  bool get isRunning => _isRunning;

  void _onListen() {
    if (!_isRunning && !_isDisposed) {
      start();
    }
  }

  void _onCancel() {
    if (!_controller.hasListener) {
      stop();
    }
  }

  /// Starts the real server log polling loop.
  void start() {
    if (_isDisposed) return;
    _isRunning = true;

    // Emit initial connection log
    _emit(LogEntry(
      level: LogLevel.info,
      source: 'ServerMonitor',
      message: 'Memulai koneksi ke server monitoring AgriMotion...',
      timestamp: DateTime.now(),
    ));

    // Poll every 8 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _pollServerStatus();
    });

    // First poll immediately
    _pollServerStatus();
  }

  /// Stops the polling loop.
  void stop() {
    _isRunning = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Polls /health and /system/info endpoints and emits structured log entries.
  Future<void> _pollServerStatus() async {
    if (!_isRunning || _isDisposed || _controller.isClosed) return;

    try {
      // Poll /health
      final healthResponse = await _client.get(
        Uri.parse(ApiConstants.healthEndpoint),
        headers: const {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (healthResponse.statusCode == 200) {
        final dynamic healthBody = jsonDecode(healthResponse.body);
        if (healthBody is Map<String, dynamic>) {
          final String status = healthBody['status']?.toString() ?? 'unknown';
          final Map<String, dynamic>? info =
              healthBody['info'] is Map<String, dynamic>
                  ? healthBody['info'] as Map<String, dynamic>
                  : null;

          _emit(LogEntry(
            level: status == 'ok' ? LogLevel.info : LogLevel.warn,
            source: 'HealthCheck',
            message: 'Health check: status=$status',
            timestamp: DateTime.now(),
          ));

          if (info != null) {
            // Database status
            final dbInfo = info['database'];
            if (dbInfo is Map<String, dynamic>) {
              final dbStatus = dbInfo['status']?.toString() ?? 'unknown';
              _emit(LogEntry(
                level: dbStatus == 'up' ? LogLevel.info : LogLevel.error,
                source: 'DatabaseService',
                message: 'PostgreSQL connection pool: status=$dbStatus',
                timestamp: DateTime.now(),
              ));
            }

            // MQTT status
            final mqttInfo = info['mqtt'];
            if (mqttInfo is Map<String, dynamic>) {
              final mqttStatus = mqttInfo['status']?.toString() ?? 'unknown';
              _emit(LogEntry(
                level: mqttStatus == 'up' ? LogLevel.mqtt : LogLevel.error,
                source: 'MqttBroker',
                message:
                    'MQTT Broker connection: status=$mqttStatus',
                timestamp: DateTime.now(),
              ));
            }

            // Memory status
            final memHeap = info['memory_heap'];
            if (memHeap is Map<String, dynamic>) {
              final heapStatus = memHeap['status']?.toString() ?? 'unknown';
              _emit(LogEntry(
                level: heapStatus == 'up' ? LogLevel.debug : LogLevel.warn,
                source: 'SystemMonitor',
                message: 'Memory heap: status=$heapStatus',
                timestamp: DateTime.now(),
              ));
            }
          }
        }
      } else {
        _emit(LogEntry(
          level: LogLevel.error,
          source: 'HealthCheck',
          message:
              'Health endpoint responded with HTTP ${healthResponse.statusCode}',
          timestamp: DateTime.now(),
        ));
      }
    } on TimeoutException {
      _emit(LogEntry(
        level: LogLevel.warn,
        source: 'HealthCheck',
        message: 'Health check timeout - server may be under heavy load',
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      _emit(LogEntry(
        level: LogLevel.error,
        source: 'ServerMonitor',
        message: 'Failed to poll server status: $e',
        timestamp: DateTime.now(),
      ));
    }

    // Also poll /system/info
    try {
      final sysResponse = await _client.get(
        Uri.parse(ApiConstants.systemInfoEndpoint),
        headers: const {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (sysResponse.statusCode == 200) {
        final dynamic sysBody = jsonDecode(sysResponse.body);
        if (sysBody is Map<String, dynamic>) {
          final system = sysBody['system'];
          if (system is Map<String, dynamic>) {
            final memory = system['memory'];
            if (memory is Map<String, dynamic>) {
              final percentage = memory['percentage'];
              final used = memory['used'];
              final total = memory['total'];
              _emit(LogEntry(
                level: (percentage is num && percentage > 80)
                    ? LogLevel.warn
                    : LogLevel.info,
                source: 'SystemMonitor',
                message:
                    'RAM Usage: ${used}MB / ${total}MB (${percentage is num ? percentage.toStringAsFixed(1) : percentage}%)',
                timestamp: DateTime.now(),
              ));
            }
          }

          final app = sysBody['app'];
          if (app is Map<String, dynamic>) {
            final uptimeSeconds = app['uptimeSeconds'];
            if (uptimeSeconds is num) {
              final days = uptimeSeconds ~/ 86400;
              final hours = (uptimeSeconds.toInt() % 86400) ~/ 3600;
              final minutes = (uptimeSeconds.toInt() % 3600) ~/ 60;
              _emit(LogEntry(
                level: LogLevel.info,
                source: 'AppRuntime',
                message: 'Application uptime: ${days}d ${hours}h ${minutes}m',
                timestamp: DateTime.now(),
              ));
            }
          }
        }
      }
    } catch (_) {
      // System info polling failure is non-critical
    }
  }

  /// Emits a log entry to the stream if not disposed.
  void _emit(LogEntry entry) {
    if (!_isDisposed && !_controller.isClosed) {
      _controller.add(entry);
    }
  }

  /// Manually add an external log entry (e.g., from HTTP interceptor).
  void addLog(LogEntry entry) => _emit(entry);

  /// Closes the underlying stream controller and cancels polling.
  void dispose() {
    _isDisposed = true;
    stop();
    _client.close();
    _controller.close();
  }
}

// =============================================================================
// RIVERPOD PROVIDERS
// =============================================================================

/// Riverpod provider for the global [SseClient] instance.
final sseClientProvider = Provider<SseClient>((ref) {
  final SseClient client = SseClient();
  ref.onDispose(() => client.dispose());
  return client;
});

/// Riverpod provider for the [ServerLogStreamService] instance.
final serverLogStreamServiceProvider = Provider<ServerLogStreamService>((ref) {
  final ServerLogStreamService service = ServerLogStreamService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Stream provider for live server logs stream from real backend polling.
final serverLogStreamProvider = StreamProvider.autoDispose<LogEntry>((ref) {
  final ServerLogStreamService service =
      ref.watch(serverLogStreamServiceProvider);
  return service.logStream;
});

