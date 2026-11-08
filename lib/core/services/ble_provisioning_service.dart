import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

/// Talks to a GreenBox ESP32 in Bluetooth setup mode to send it WiFi
/// credentials. UUIDs must match ESP32GreenBox/src/main.cpp.
///
/// Every GATT operation has its own timeout: on Android a lost link or a
/// stale GATT cache can leave a call pending forever, which used to keep the
/// setup screen spinning with no way out.
class BleProvisioningService {
  static const serviceUuid = '6e1d0001-8f0b-4c55-9a3e-2b7c1e5a9f01';
  static const _deviceIdChar = '6e1d0002-8f0b-4c55-9a3e-2b7c1e5a9f01';
  static const _networksChar = '6e1d0003-8f0b-4c55-9a3e-2b7c1e5a9f01';
  static const _credentialsChar = '6e1d0004-8f0b-4c55-9a3e-2b7c1e5a9f01';
  static const _statusChar = '6e1d0005-8f0b-4c55-9a3e-2b7c1e5a9f01';

  static const _opTimeout = Duration(seconds: 8);

  /// Emits GreenBox devices in setup mode as they are found.
  Stream<BleDevice> get scanResults => UniversalBle.scanStream;

  Future<void> startScan() async {
    await UniversalBle.stopScan();
    await UniversalBle.startScan(
      scanFilter: ScanFilter(withServices: [serviceUuid]),
    );
  }

  Future<void> stopScan() => UniversalBle.stopScan();

  /// Connects and discovers services, retrying once: the first GATT
  /// connection after a scan often fails on Android (status 133).
  Future<void> connect(String deviceId) async {
    for (var attempt = 1;; attempt++) {
      try {
        await UniversalBle.connect(deviceId, timeout: const Duration(seconds: 15))
            .timeout(const Duration(seconds: 17));
        // Give the link a moment to settle before discovery (Android).
        await Future<void>.delayed(const Duration(milliseconds: 400));
        try {
          // Larger MTU so the network list and credentials fit in one packet.
          await UniversalBle.requestMtu(deviceId, 247).timeout(_opTimeout);
        } catch (_) {
          // Not supported on every platform; long reads/writes still work.
        }
        await UniversalBle.discoverServices(deviceId).timeout(const Duration(seconds: 12));
        return;
      } catch (_) {
        await disconnect(deviceId);
        if (attempt >= 2) rethrow;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
  }

  Future<void> disconnect(String deviceId) async {
    try {
      await UniversalBle.disconnect(deviceId).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<String> readDeviceId(String deviceId) async => utf8.decode(
      await UniversalBle.read(deviceId, serviceUuid, _deviceIdChar).timeout(_opTimeout));

  /// WiFi networks the ESP32 can see, strongest first.
  Future<List<String>> readNetworks(String deviceId) async {
    final raw = utf8.decode(
        await UniversalBle.read(deviceId, serviceUuid, _networksChar).timeout(_opTimeout));
    final decoded = jsonDecode(raw.trim().isEmpty ? '[]' : raw);
    return decoded is List ? decoded.map((e) => e.toString()).toList() : <String>[];
  }

  /// Asks the ESP32 to scan WiFi again and polls the list until it has
  /// networks or [timeout] runs out. Older firmware cannot be asked to rescan;
  /// then the list is just read again.
  Future<List<String>> rescanNetworks(String deviceId, {Duration timeout = const Duration(seconds: 15)}) async {
    try {
      await UniversalBle.write(
        deviceId,
        serviceUuid,
        _networksChar,
        Uint8List.fromList(utf8.encode('scan')),
      ).timeout(_opTimeout);
    } catch (_) {}
    final deadline = DateTime.now().add(timeout);
    var networks = <String>[];
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      networks = await readNetworks(deviceId);
      if (networks.isNotEmpty) break;
    }
    return networks;
  }

  /// Setup status: waiting, connecting, connected, failed or `error:reason`.
  Future<Stream<String>> watchStatus(String deviceId) async {
    await UniversalBle.subscribeNotifications(deviceId, serviceUuid, _statusChar).timeout(_opTimeout);
    return UniversalBle.characteristicValueStream(deviceId, _statusChar).map(utf8.decode);
  }

  Future<void> sendCredentials(String deviceId, {required String ssid, required String password}) {
    final payload = jsonEncode({'ssid': ssid, 'pass': password});
    return UniversalBle.write(
      deviceId,
      serviceUuid,
      _credentialsChar,
      Uint8List.fromList(utf8.encode(payload)),
    ).timeout(_opTimeout);
  }
}
