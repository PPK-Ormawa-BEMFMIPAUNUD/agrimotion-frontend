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

  /// Human-readable device code (e.g., "node-1b", "node-2a").
  final String deviceCode;

  /// Display label for UI (e.g., "Node 1", "Node 2A").
  final String label;

  /// Whether the device is physically installed and active.
  final bool isInstalled;

  const DeviceNode({
    required this.deviceId,
    required this.deviceCode,
    required this.label,
    this.isInstalled = true,
  });
}

/// Represents a Demplot (demonstration plot / farm).
class Demplot {
  /// PostgreSQL UUID of the farm.
  final String farmId;

  /// Display name (e.g., "Demplot 1").
  final String name;

  /// Commodity grown in this Demplot (e.g., "Bunga Pacah", "Sawi", "Cabai").
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
/// UUIDs match the backend database.
class DemplotConfig {
  DemplotConfig._(); // Prevent instantiation

  static const List<Demplot> demplots = [
    // ── Demplot 1: Bunga Pacah (Node 1 / dulunya 1B) ────────────────────
    Demplot(
      farmId: '11111111-1111-1111-1111-111111111111',
      name: 'Demplot 1',
      commodity: 'Bunga Pacah',
      icon: '🌸',
      devices: [
        DeviceNode(
          deviceId: '10000000-0000-0000-0000-000000000002',
          deviceCode: 'node-1b',
          label: 'Node 1',
          isInstalled: true,
        ),
      ],
    ),

    // ── Demplot 2: Sawi (Node 2A / dulunya 1A & Node 2B belum terpasang)
    Demplot(
      farmId: '22222222-2222-2222-2222-222222222222',
      name: 'Demplot 2',
      commodity: 'Sawi',
      icon: '🥬',
      devices: [
        DeviceNode(
          deviceId: '10000000-0000-0000-0000-000000000001',
          deviceCode: 'node-1a',
          label: 'Node 2A',
          isInstalled: true,
        ),
        DeviceNode(
          deviceId: '20000000-0000-0000-0000-000000000002',
          deviceCode: 'node-2b',
          label: 'Node 2B',
          isInstalled: false,
        ),
      ],
    ),

    // ── Demplot 3: Cabai (Node 3A) ─────────────────────────────────────
    Demplot(
      farmId: '33333333-3333-3333-3333-333333333333',
      name: 'Demplot 3',
      commodity: 'Cabai',
      icon: '🌶️',
      devices: [
        DeviceNode(
          deviceId: '30000000-0000-0000-0000-000000000001',
          deviceCode: 'node-3a',
          label: 'Node 3A',
          isInstalled: true,
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
