import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:disaster360/services/gis_service.dart';

class GisCacheService {
  static final GisCacheService _instance = GisCacheService._internal();
  factory GisCacheService() => _instance;
  GisCacheService._internal();

  List<MapRegion>? _provinces;
  List<MapRegion>? _districts;
  List<MapRegion>? _localUnits;
  
  bool _isLoading = false;
  bool _isLoaded = false;

  Future<void> init() async {
    if (_isLoaded || _isLoading) return;
    _isLoading = true;
    final gisService = GisService();
    try {
      // These run in background isolates via compute inside GisService.
      _provinces = await gisService.loadLayer('Province', 'assets/maps/province0.json');
      _districts = await gisService.loadLayer('District', 'assets/maps/districts0.json');
      _localUnits = await gisService.loadLayer('LocalUnit', 'assets/maps/local_unit.json');
      _isLoaded = true;
    } catch (e) {
      debugPrint("Failed to load map regions: $e");
    } finally {
      _isLoading = false;
    }
  }

  /// Returns [Province, District, LocalUnit] based on Point-in-Polygon check.
  Future<List<String>> identifyAdministrativeAreas(double lat, double lng) async {
    await init(); // Ensure layers are loaded
    final point = LatLng(lat, lng);
    final gisService = GisService();
    
    final province = _provinces != null ? gisService.identifyRegion(point, _provinces!) : null;
    final district = _districts != null ? gisService.identifyRegion(point, _districts!) : null;
    final localUnit = _localUnits != null ? gisService.identifyRegion(point, _localUnits!) : null;

    return [
      province ?? "Unknown",
      district ?? "Unknown",
      localUnit ?? "Unknown"
    ];
  }
}
