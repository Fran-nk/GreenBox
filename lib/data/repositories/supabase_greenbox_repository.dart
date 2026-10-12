import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/sensor_reading.dart';
import '../../domain/models/plant.dart';
import '../../domain/models/crop_card.dart';
import '../../domain/models/chart_data_point.dart';
import '../../domain/models/water_study.dart';
import '../../domain/repositories/greenbox_repository.dart';

/// Supabase implementation of [GreenBoxRepository].
/// 
/// Connects to PostgreSQL via PostgREST and uses Realtime for live updates.
class SupabaseGreenBoxRepository implements GreenBoxRepository {
  final SupabaseClient _client = Supabase.instance.client;

  @override
  Future<List<SensorReading>> getSensorReadings(String plantId) async {
    try {
      final data = await _client
          .from('sensor_data')
          .select()
          .eq('device_id', plantId)
          .order('time', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data == null) return [];

      final now = DateTime.parse(data['time']);
      return [
        SensorReading(sensorType: 'ph', value: (data['ph'] as num).toDouble(), unit: '', timestamp: now),
        SensorReading(sensorType: 'ce', value: (data['ec'] as num).toDouble(), unit: 'µS/cm', timestamp: now),
        SensorReading(sensorType: 'humedad', value: (data['humidity'] as num).toDouble(), unit: '%', timestamp: now),
      ];
    } catch (e) {
      return [];
    }
  }

  @override
  Future<Plant> getActivePlant(String plantId) async {
    final response = await _client
        .from('devices')
        .select('*, plants(*), thresholds(*)')
        .eq('id', plantId)
        .single();

    final plantData = response['plants'];
    final thresholdsData = response['thresholds'];
    final Map<String, dynamic>? thresholdMap = (thresholdsData is List && thresholdsData.isNotEmpty)
        ? thresholdsData.first as Map<String, dynamic>
        : (thresholdsData is Map ? thresholdsData as Map<String, dynamic> : null);

    final List<dynamic> stagesJson = plantData['growth_stages'] ?? [];

    final double minHumidity = thresholdMap != null && thresholdMap['min_humidity'] != null
        ? (thresholdMap['min_humidity'] as num).toDouble()
        : (plantData['recommended_min_humidity'] != null
            ? (plantData['recommended_min_humidity'] as num).toDouble()
            : 60.0);

    final double maxHumidity = thresholdMap != null && thresholdMap['max_humidity'] != null
        ? (thresholdMap['max_humidity'] as num).toDouble()
        : (plantData['recommended_max_humidity'] != null
            ? (plantData['recommended_max_humidity'] as num).toDouble()
            : 80.0);

    final List<String> activeSensors = (response['active_sensors'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        ['ph', 'ce', 'humedad', 'luz', 'temperatura'];

    return Plant(
      id: plantData['id'],
      commonName: plantData['common_name'],
      scientificName: plantData['scientific_name'] ?? '',
      imageUrl: plantData['image_url'] ?? '',
      currentDay: 10, // MVP: Logic to calculate days since creation could be added
      totalDays: plantData['total_days'] ?? 30,
      isHealthy: true,
      growthProgress: 0.33,
      recommendedMinHumidity: minHumidity,
      recommendedMaxHumidity: maxHumidity,
      activeSensors: activeSensors,
      typicalHarvestWeightKg: plantData['typical_harvest_weight_kg'] != null
          ? (plantData['typical_harvest_weight_kg'] as num).toDouble()
          : Plant.defaultHarvestWeightFor(plantData['common_name'] ?? ''),
      growthStages: stagesJson.map((s) => GrowthStage(
        name: s['name'],
        days: s['days'],
        isCurrent: s['isCurrent'] ?? false,
      )).toList(),
    );
  }

  @override
  Future<List<CropCard>> getCrops() async {
    final List<dynamic> response = await _client
        .from('devices')
        .select('*, plants(*)');

    return response.map<CropCard>((d) {
      final plant = d['plants'];
      return CropCard(
        id: d['id'],
        name: d['name'] ?? (plant != null ? plant['common_name'] : 'Dispositivo'),
        imageUrl: plant != null ? plant['image_url'] : '',
        progress: 0.42, // MVP: Mock progress
      );
    }).toList();
  }

  @override
  Future<List<ChartDataPoint>> getChartData({
    required String plantId,
    required String sensorType,
    required ChartTimeRange timeRange,
  }) async {
    // Map sensorType from UI to DB column
    final lowerType = sensorType.toLowerCase();
    String column = lowerType == 'ce'
        ? 'ec'
        : (lowerType == 'humedad' || lowerType == 'humidity')
            ? 'humidity'
            : (lowerType == 'temperatura' || lowerType == 'temp' || lowerType == 'temperature')
                ? 'temperature'
                : (lowerType == 'luz' || lowerType == 'light')
                    ? 'light'
                    : 'ph';

    final response = await _client
        .from('sensor_data')
        .select('time, $column')
        .eq('device_id', plantId)
        .order('time', ascending: true);

    return response.map<ChartDataPoint>((d) {
      final value = (d[column] as num).toDouble();
      return ChartDataPoint(
        timestamp: DateTime.parse(d['time']),
        value: value,
        isInRange: value >= 5.5 && value <= 7.5, // Simple threshold logic
      );
    }).toList();
  }

  @override
  Stream<List<SensorReading>> watchSensorReadings(String plantId) {
    final controller = StreamController<List<SensorReading>>.broadcast();
    
    // Join the channel named after the device ID
    final channel = _client.channel('device:$plantId');
    
    void handlePayload(Map<String, dynamic> rawPayload) {
      final now = DateTime.now();
      final List<SensorReading> readings = [];

      // Dependiendo de la versión de supabase_flutter, el payload real puede venir dentro de una llave 'payload'
      final payload = rawPayload.containsKey('payload') && rawPayload['payload'] is Map
          ? rawPayload['payload'] as Map<String, dynamic>
          : rawPayload;

      // Parse humidity (resilient parsing supporting multiple variations)
      final rawHum = payload['humidity'] ?? payload['humedad'] ?? payload['humidity_env'];
      if (rawHum != null) {
        readings.add(SensorReading(
          sensorType: 'humedad',
          value: (rawHum as num).toDouble(),
          unit: '%',
          timestamp: now,
        ));
      }

      // Parse ph
      final rawPh = payload['ph'] ?? payload['pH'];
      if (rawPh != null) {
        readings.add(SensorReading(
          sensorType: 'ph',
          value: (rawPh as num).toDouble(),
          unit: '',
          timestamp: now,
        ));
      }

      // Parse conductivity
      final rawCe = payload['ce'] ?? payload['ec'] ?? payload['electroconductivity'];
      if (rawCe != null) {
        readings.add(SensorReading(
          sensorType: 'ce',
          value: (rawCe as num).toDouble(),
          unit: 'µS/cm',
          timestamp: now,
        ));
      }

      // Parse temperature
      final rawTemp = payload['temperature'] ?? payload['temperatura'] ?? payload['temp'];
      if (rawTemp != null) {
        readings.add(SensorReading(
          sensorType: 'temperatura',
          value: (rawTemp as num).toDouble(),
          unit: '°C',
          timestamp: now,
        ));
      }

      // Parse light
      final rawLight = payload['light'] ?? payload['luz'] ?? payload['lux'];
      if (rawLight != null) {
        readings.add(SensorReading(
          sensorType: 'luz',
          value: (rawLight as num).toDouble(),
          unit: 'lx',
          timestamp: now,
        ));
      }

      // Parse hydrostatic pressure (kPa) for the water footprint study
      final rawPressure = payload['pressure'] ?? payload['presion'] ?? payload['water_pressure'];
      if (rawPressure != null) {
        readings.add(SensorReading(
          sensorType: 'presion',
          value: (rawPressure as num).toDouble(),
          unit: 'kPa',
          timestamp: now,
        ));
      }

      if (readings.isNotEmpty) {
        controller.add(readings);
      }
    }

    // Bind to both telemetry and sensor_reading events for bulletproof compatibility
    channel.onBroadcast(
      event: 'telemetry',
      callback: (payload) => handlePayload(payload),
    ).onBroadcast(
      event: 'sensor_reading',
      callback: (payload) => handlePayload(payload),
    ).subscribe();

    controller.onCancel = () {
      _client.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  @override
  Future<List<Plant>> getPlantTemplates() async {
    try {
      final List<dynamic> response = await _client.from('plants').select();

      if (response.isEmpty) {
        return Plant.getDefaultTemplates();
      }

      return response.map<Plant>((p) {
        final List<dynamic> stagesJson = p['growth_stages'] ?? [];
        return Plant(
          id: p['id'],
          commonName: p['common_name'],
          scientificName: p['scientific_name'] ?? '',
          imageUrl: p['image_url'] ?? '',
          currentDay: 0,
          totalDays: p['total_days'] ?? 30,
          recommendedMinHumidity: p['recommended_min_humidity'] != null
              ? (p['recommended_min_humidity'] as num).toDouble()
              : 60.0,
          recommendedMaxHumidity: p['recommended_max_humidity'] != null
              ? (p['recommended_max_humidity'] as num).toDouble()
              : 80.0,
          typicalHarvestWeightKg: p['typical_harvest_weight_kg'] != null
              ? (p['typical_harvest_weight_kg'] as num).toDouble()
              : Plant.defaultHarvestWeightFor(p['common_name'] ?? ''),
          growthStages: stagesJson.map((s) => GrowthStage(
            name: s['name'],
            days: s['days'],
            isCurrent: s['isCurrent'] ?? false,
          )).toList(),
        );
      }).toList();
    } catch (e) {
      // Fallback to default local templates if DB is not setup or network fails
      return Plant.getDefaultTemplates();
    }
  }

  @override
  Future<void> addDevice({
    required String deviceId,
    required String name,
    required String plantTemplateId,
    required Map<String, double> thresholds,
    List<String>? activeSensors,
  }) async {
    // 1. Create the device entry
    // Note: owner_id should be the current authenticated user's ID
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    await _client.from('devices').upsert({
      'id': deviceId,
      'name': name,
      'plant_id': plantTemplateId,
      'owner_id': user.id,
      'active_sensors': activeSensors ?? ['ph', 'ce', 'humedad', 'luz'],
    });

    // 2. Create the thresholds entry using the correct database column names
    await _client.from('thresholds').upsert({
      'device_id': deviceId,
      'min_ph': 5.5,
      'max_ph': 6.5,
      'min_humidity': thresholds['humidity_min'] ?? 60.0,
      'max_humidity': thresholds['humidity_max'] ?? 80.0,
      'min_ec': 1.2,
      'max_ec': 2.0,
    });
  }

  @override
  Future<void> deleteDevice(String deviceId) async {
    // Clean up thresholds first to prevent reference issues
    try {
      await _client.from('thresholds').delete().eq('device_id', deviceId);
    } catch (_) {}

    // Clean up water footprint studies (refills cascade from the study)
    try {
      await _client.from('water_footprint_studies').delete().eq('device_id', deviceId);
    } catch (_) {}

    // Clean up sensor data
    try {
      await _client.from('sensor_data').delete().eq('device_id', deviceId);
    } catch (_) {}

    // Delete the device itself
    await _client.from('devices').delete().eq('id', deviceId);
  }

  @override
  Future<void> updateDevice(String deviceId, {
    required String name,
    required String plantTemplateId,
    required Map<String, double> thresholds,
    List<String>? activeSensors,
  }) async {
    final updateData = <String, dynamic>{
      'name': name,
      'plant_id': plantTemplateId,
    };
    if (activeSensors != null) {
      updateData['active_sensors'] = activeSensors;
    }

    await _client.from('devices').update(updateData).eq('id', deviceId);

    await _client.from('thresholds').update({
      'min_humidity': thresholds['humidity_min'] ?? 60.0,
      'max_humidity': thresholds['humidity_max'] ?? 80.0,
    }).eq('device_id', deviceId);
  }

  @override
  Future<TankDimensions?> getTankDimensions(String deviceId) async {
    final data = await _client
        .from('devices')
        .select('tank_width_cm, tank_length_cm, tank_height_cm')
        .eq('id', deviceId)
        .maybeSingle();

    if (data == null ||
        data['tank_width_cm'] == null ||
        data['tank_length_cm'] == null ||
        data['tank_height_cm'] == null) {
      return null;
    }

    return TankDimensions(
      widthCm: (data['tank_width_cm'] as num).toDouble(),
      lengthCm: (data['tank_length_cm'] as num).toDouble(),
      heightCm: (data['tank_height_cm'] as num).toDouble(),
    );
  }

  @override
  Future<void> saveTankDimensions(String deviceId, TankDimensions dimensions) async {
    await _client.from('devices').update({
      'tank_width_cm': dimensions.widthCm,
      'tank_length_cm': dimensions.lengthCm,
      'tank_height_cm': dimensions.heightCm,
    }).eq('id', deviceId);
  }

  @override
  Future<WaterStudy?> getActiveStudy(String deviceId) async {
    final data = await _client
        .from('water_footprint_studies')
        .select()
        .eq('device_id', deviceId)
        .eq('status', 'active')
        .order('started_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return data == null ? null : WaterStudy.fromJson(data);
  }

  @override
  Future<WaterStudy> startStudy({
    required String deviceId,
    String? plantId,
    required double initialPressureKpa,
    required double initialVolumeL,
  }) async {
    final data = await _client
        .from('water_footprint_studies')
        .insert({
          'device_id': deviceId,
          'plant_id': plantId,
          'status': 'active',
          'started_at': DateTime.now().toUtc().toIso8601String(),
          'initial_pressure_kpa': initialPressureKpa,
          'initial_volume_l': initialVolumeL,
        })
        .select()
        .single();

    return WaterStudy.fromJson(data);
  }

  @override
  Future<WaterRefill> addRefill({
    required String studyId,
    required double volumeBeforeL,
    required double volumeAfterL,
  }) async {
    final data = await _client
        .from('water_refills')
        .insert({
          'study_id': studyId,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'volume_before_l': volumeBeforeL,
          'volume_after_l': volumeAfterL,
        })
        .select()
        .single();

    return WaterRefill.fromJson(data);
  }

  @override
  Future<List<WaterRefill>> getRefills(String studyId) async {
    final List<dynamic> response = await _client
        .from('water_refills')
        .select()
        .eq('study_id', studyId)
        .order('created_at', ascending: true);

    return response.map<WaterRefill>((r) => WaterRefill.fromJson(r)).toList();
  }

  @override
  Future<void> finishStudy({
    required String studyId,
    required double finalPressureKpa,
    required double finalVolumeL,
    required double totalConsumptionL,
    required int plantCount,
    required double harvestWeightKg,
    required double waterFootprintLPerKg,
  }) async {
    await _client.from('water_footprint_studies').update({
      'status': 'finished',
      'finished_at': DateTime.now().toUtc().toIso8601String(),
      'final_pressure_kpa': finalPressureKpa,
      'final_volume_l': finalVolumeL,
      'total_consumption_l': totalConsumptionL,
      'plant_count': plantCount,
      'harvest_weight_kg': harvestWeightKg,
      'water_footprint_l_per_kg': waterFootprintLPerKg,
    }).eq('id', studyId);
  }

  @override
  Future<List<WaterStudy>> getStudyHistory(String deviceId) async {
    final List<dynamic> response = await _client
        .from('water_footprint_studies')
        .select()
        .eq('device_id', deviceId)
        .eq('status', 'finished')
        .order('finished_at', ascending: false);

    return response.map<WaterStudy>((s) => WaterStudy.fromJson(s)).toList();
  }

  @override
  void dispose() {
    // Subscriptions are usually handled by the UI/Bloc/Provider
  }
}
