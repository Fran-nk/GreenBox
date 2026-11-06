import 'dart:async';

import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../core/services/ble_provisioning_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

enum _Step { scanning, connecting, form, sending }

/// Finds a GreenBox in Bluetooth setup mode, sends it the WiFi credentials and
/// pops with the device UUID once the ESP32 reports it is online.
class WifiSetupScreen extends StatefulWidget {
  const WifiSetupScreen({super.key});

  @override
  State<WifiSetupScreen> createState() => _WifiSetupScreenState();
}

class _WifiSetupScreenState extends State<WifiSetupScreen> {
  final _ble = BleProvisioningService();
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();

  _Step _step = _Step.scanning;
  final Map<String, BleDevice> _found = {};
  StreamSubscription<BleDevice>? _scanSub;
  StreamSubscription<String>? _statusSub;

  String? _connectedId;
  String? _deviceUuid;
  List<String> _networks = [];
  bool _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() {
      _step = _Step.scanning;
      _found.clear();
      _error = null;
    });
    try {
      await _scanSub?.cancel();
      _scanSub = _ble.scanResults.listen((device) {
        if (mounted) setState(() => _found[device.deviceId] = device);
      });
      await _ble.startScan();
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo buscar por Bluetooth. Activa el Bluetooth y concede los permisos.\n($e)');
    }
  }

  Future<void> _selectDevice(BleDevice device) async {
    await _ble.stopScan();
    setState(() {
      _step = _Step.connecting;
      _error = null;
    });
    try {
      await _ble.connect(device.deviceId);
      _connectedId = device.deviceId;
      final uuid = await _ble.readDeviceId(device.deviceId);
      final networks = await _ble.readNetworks(device.deviceId);
      if (!mounted) return;
      setState(() {
        _deviceUuid = uuid;
        _networks = networks;
        if (networks.isNotEmpty && _ssidController.text.isEmpty) {
          _ssidController.text = networks.first;
        }
        _step = _Step.form;
      });
    } catch (e) {
      await _ble.disconnect(device.deviceId);
      _connectedId = null;
      if (mounted) {
        setState(() => _error = 'No se pudo conectar con el GreenBox. Acércate e inténtalo de nuevo.');
        _startScan();
      }
    }
  }

  Future<void> _send() async {
    final id = _connectedId;
    final ssid = _ssidController.text.trim();
    if (id == null || ssid.isEmpty) return;
    setState(() {
      _step = _Step.sending;
      _error = null;
    });
    try {
      await _statusSub?.cancel();
      final status = await _ble.watchStatus(id);
      _statusSub = status.listen(_onStatus);
      await _ble.sendCredentials(id, ssid: ssid, password: _passwordController.text);
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = _Step.form;
          _error = 'No se pudo enviar la configuración. Inténtalo de nuevo.';
        });
      }
    }
  }

  void _onStatus(String status) {
    if (!mounted) return;
    switch (status) {
      case 'connected':
        // The ESP32 restarts in normal mode and drops the Bluetooth link.
        _statusSub?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GreenBox conectado al WiFi')),
        );
        Navigator.pop(context, _deviceUuid);
      case 'failed':
        setState(() {
          _step = _Step.form;
          _error = 'El GreenBox no pudo conectarse a "${_ssidController.text}". Revisa la contraseña y que sea una red de 2,4 GHz.';
        });
      case final s when s.startsWith('error'):
        setState(() {
          _step = _Step.form;
          _error = 'El GreenBox rechazó la configuración ($s).';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Configurar WiFi', style: AppTextStyles.greeting.copyWith(fontSize: 22)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                _buildError(_error!),
                const SizedBox(height: 20),
              ],
              ...switch (_step) {
                _Step.scanning => _buildScanning(),
                _Step.connecting => _buildBusy('Conectando con el GreenBox...'),
                _Step.form => _buildForm(),
                _Step.sending => _buildBusy('Conectando el GreenBox a "${_ssidController.text}"...\nEsto puede tardar hasta 20 segundos.'),
              },
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildScanning() {
    return [
      Text('1. Busca tu GreenBox', style: AppTextStyles.alertSubtitle),
      const SizedBox(height: 10),
      Text(
        'El GreenBox entra en modo configuración cuando no tiene WiFi. '
        'Para cambiar de red, mantén pulsado su botón BOOT 3 segundos.',
        style: AppTextStyles.chartFilter,
      ),
      const SizedBox(height: 20),
      _card(
        child: _found.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                    SizedBox(width: 12),
                    Text('Buscando dispositivos...'),
                  ],
                ),
              )
            : Column(
                children: _found.values
                    .map((d) => ListTile(
                          leading: const Icon(Icons.bluetooth, color: AppColors.phBlue),
                          title: Text(d.name ?? 'GreenBox', style: AppTextStyles.chartFilter),
                          subtitle: d.rssi != null ? Text('Señal: ${d.rssi} dBm') : null,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _selectDevice(d),
                        ))
                    .toList(),
              ),
      ),
      const SizedBox(height: 15),
      Center(
        child: TextButton.icon(
          onPressed: _startScan,
          icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
          label: const Text('Buscar de nuevo', style: TextStyle(color: AppColors.textSecondary)),
        ),
      ),
    ];
  }

  List<Widget> _buildForm() {
    return [
      Text('2. Elige la red WiFi', style: AppTextStyles.alertSubtitle),
      const SizedBox(height: 10),
      if (_networks.isNotEmpty) ...[
        _card(
          child: RadioGroup<String>(
            groupValue: _ssidController.text,
            onChanged: (v) => setState(() => _ssidController.text = v!),
            child: Column(
              children: _networks
                  .map((ssid) => RadioListTile<String>(
                        value: ssid,
                        activeColor: AppColors.primary,
                        title: Text(ssid, style: AppTextStyles.chartFilter),
                      ))
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
      _textField(_ssidController, 'Nombre de la red (SSID)', onChanged: (_) => setState(() {})),
      const SizedBox(height: 20),
      Text('3. Contraseña', style: AppTextStyles.alertSubtitle),
      const SizedBox(height: 10),
      _textField(
        _passwordController,
        'Contraseña del WiFi',
        obscure: _obscurePassword,
        suffix: IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      const SizedBox(height: 8),
      Text('Solo redes de 2,4 GHz.', style: AppTextStyles.chartLabel),
      const SizedBox(height: 30),
      SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton(
          onPressed: _ssidController.text.trim().isEmpty ? null : _send,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: const Text('CONECTAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ),
    ];
  }

  List<Widget> _buildBusy(String message) {
    return [
      const SizedBox(height: 60),
      const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      const SizedBox(height: 20),
      Center(child: Text(message, textAlign: TextAlign.center, style: AppTextStyles.chartFilter)),
    ];
  }

  Widget _buildError(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.alertRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.alertRed),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: AppTextStyles.chartFilter)),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: child,
    );
  }

  Widget _textField(
    TextEditingController controller,
    String hint, {
    bool obscure = false,
    Widget? suffix,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        autocorrect: false,
        enableSuggestions: false,
        onChanged: onChanged,
        decoration: InputDecoration(border: InputBorder.none, hintText: hint, suffixIcon: suffix),
        style: AppTextStyles.chartFilter.copyWith(color: AppColors.textPrimary),
      ),
    );
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _statusSub?.cancel();
    _ble.stopScan();
    final id = _connectedId;
    if (id != null) _ble.disconnect(id);
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
