// Centralized Demplot ↔ Device mapping for AGRI-MOTION.
//
// This file is the **single source of truth** for the frontend to know
// which Demplot contains which Node Sensors (devices).
//
// All UUIDs here mirror the PostgreSQL database exactly.
// When a new Demplot or Node is added in the backend, update this file.

/// Represents a single IoT node sensor device within a Demplot.
class DeviceNode {
  /// PostgreSQL UUID of the device (used as `deviceId` query parameter).
  final String deviceId;

  /// Human-readable device code (e.g., "node-1a").
  final String deviceCode;

  /// Display label for UI (e.g., "Node 1A").
  final String label;

  const DeviceNode({
    required this.deviceId,
    required this.deviceCode,
    required this.label,
  });
}

/// Represents a Demplot (demonstration plot / farm).
class Demplot {
  /// PostgreSQL UUID of the farm.
  final String farmId;

  /// Display name (e.g., "Demplot 1").
  final String name;

  /// Commodity grown in this Demplot (e.g., "Padi").
  final String commodity;

  /// Emoji icon for visual identification in the UI.
  final String icon;

  /// List of sensor nodes deployed in this Demplot.
  final List<DeviceNode> devices;

  const Demplot({
    required this.farmId,
    required this.name,
    required this.commodity,
    required this.icon,
    required this.devices,
  });

  /// Whether this Demplot has multiple sensor nodes.
  bool get isMultiNode => devices.length > 1;
}

/// Static registry of all Demplots and their Node Sensors.
///
/// UUIDs must match the backend PostgreSQL database exactly.
/// Using invalid UUIDs will cause HTTP 400 (Bad Request) errors.
class DemplotConfig {
  DemplotConfig._(); // Prevent instantiation

  static const List<Demplot> demplots = [
    // ── Demplot 1: Padi (2 nodes) ──────────────────────────────────────
    Demplot(
      farmId: '11111111-1111-1111-1111-111111111111',
      name: 'Demplot 1',
      commodity: 'Padi',
      icon: '🌾',
      devices: [
        DeviceNode(
          deviceId: '10000000-0000-0000-0000-000000000001',
          deviceCode: 'node-1a',
          label: 'Node 1A',
        ),
        DeviceNode(
          deviceId: '10000000-0000-0000-0000-000000000002',
          deviceCode: 'node-1b',
          label: 'Node 1B',
        ),
      ],
    ),

    // ── Demplot 2: Bunga Pacar Air (1 node) ────────────────────────────
    Demplot(
      farmId: '22222222-2222-2222-2222-222222222222',
      name: 'Demplot 2',
      commodity: 'Bunga Pacar Air',
      icon: '🌸',
      devices: [
        DeviceNode(
          deviceId: '20000000-0000-0000-0000-000000000001',
          deviceCode: 'node-2a',
          label: 'Node 2A',
        ),
      ],
    ),

    // ── Demplot 3: Sayuran Hijau (1 node) ──────────────────────────────
    Demplot(
      farmId: '33333333-3333-3333-3333-333333333333',
      name: 'Demplot 3',
      commodity: 'Sayuran Hijau',
      icon: '🥬',
      devices: [
        DeviceNode(
          deviceId: '30000000-0000-0000-0000-000000000001',
          deviceCode: 'node-3a',
          label: 'Node 3A',
        ),
      ],
    ),
  ];

  /// Lookup a Demplot by its farm UUID.
  static Demplot? findByFarmId(String farmId) {
    try {
      return demplots.firstWhere((d) => d.farmId == farmId);
    } catch (_) {
      return null;
    }
  }

  /// Lookup a DeviceNode by its device UUID across all Demplots.
  static DeviceNode? findDeviceById(String deviceId) {
    for (final demplot in demplots) {
      for (final device in demplot.devices) {
        if (device.deviceId == deviceId) return device;
      }
    }
    return null;
  }

  /// Get all device UUIDs for a given Demplot (by index).
  static List<String> deviceIdsForDemplot(int index) {
    if (index < 0 || index >= demplots.length) return [];
    return demplots[index].devices.map((d) => d.deviceId).toList();
  }
}
