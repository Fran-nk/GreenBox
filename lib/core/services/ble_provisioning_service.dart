import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

/// Talks to a GreenBox ESP32 in Bluetooth setup mode to send it WiFi
/// credentials. UUIDs must match ESP32GreenBox/src/main.cpp.
class BleProvisioningService {
  static const serviceUuid = '6e1d0001-8f0b-4c55-9a3e-2b7c1e5a9f01';
  static const _deviceIdChar = '6e1d0002-8f0b-4c55-9a3e-2b7c1e5a9f01';
  static const _networksChar = '6e1d0003-8f0b-4c55-9a3e-2b7c1e5a9f01';
  static const _credentialsChar = '6e1d0004-8f0b-4c55-9a3e-2b7c1e5a9f01';
  static const _statusChar = '6e1d0005-8f0b-4c55-9a3e-2b7c1e5a9f01';

  /// Emits GreenBox devices in setup mode as they are found.
  Stream<BleDevice> get scanResults => UniversalBle.scanStream;

  Future<void> startScan() async {
    await UniversalBle.stopScan();
    await UniversalBle.startScan(
      scanFilter: ScanFilter(withServices: [serviceUuid]),
    );
  }

  Future<void> stopScan() => UniversalBle.stopScan();

  Future<void> connect(String deviceId) async {
    await UniversalBle.connect(deviceId, timeout: const Duration(seconds: 15));
    await UniversalBle.discoverServices(deviceId);
    try {
      // Larger MTU so the network list and credentials fit in one packet.
      await UniversalBle.requestMtu(deviceId, 247);
    } catch (_) {
      // Not supported on every platform; long reads/writes still work.
    }
  }

  Future<void> disconnect(String deviceId) async {
    try {
      await UniversalBle.disconnect(deviceId);
    } catch (_) {}
  }

  Future<String> readDeviceId(String deviceId) async =>
      utf8.decode(await UniversalBle.read(deviceId, serviceUuid, _deviceIdChar));

  /// WiFi networks the ESP32 can see, strongest first.
  Future<List<String>> readNetworks(String deviceId) async {
    final raw = utf8.decode(await UniversalBle.read(deviceId, serviceUuid, _networksChar));
    return (jsonDecode(raw) as List).cast<String>();
  }

  /// Setup status: waiting, connecting, connected, failed or `error:reason`.
  Future<Stream<String>> watchStatus(String deviceId) async {
    await UniversalBle.subscribeNotifications(deviceId, serviceUuid, _statusChar);
    return UniversalBle.characteristicValueStream(deviceId, _statusChar).map(utf8.decode);
  }

  Future<void> sendCredentials(String deviceId, {required String ssid, required String password}) {
    final payload = jsonEncode({'ssid': ssid, 'pass': password});
    return UniversalBle.write(
      deviceId,
      serviceUuid,
      _credentialsChar,
      Uint8List.fromList(utf8.encode(payload)),
    );
  }
}
