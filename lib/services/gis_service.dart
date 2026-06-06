import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

class MapRegion {
  final String name;
  final String type;
  final LatLngBounds bounds;
  final List<List<LatLng>> polygons;

  MapRegion({
    required this.name,
    required this.type,
    required this.bounds,
    required this.polygons,
  });
}

class GisService {
  /// Loads and parses GeoJSON layers in the background using Isolates
  Future<List<MapRegion>> loadLayer(String type, String assetPath) async {
    final String jsonString = await rootBundle.loadString(assetPath);
    return await compute(_parseGeoJson, {'type': type, 'json': jsonString});
  }

  /// Parsing logic that runs inside the Isolate
  static List<MapRegion> _parseGeoJson(Map<String, dynamic> args) {
    final String type = args['type'];
    final String jsonString = args['json'];
    final Map<String, dynamic> data = jsonDecode(jsonString);
    final List<MapRegion> regions = [];

    if (!data.containsKey('features')) return regions;

    for (var feature in data['features']) {
      final properties = feature['properties'] as Map<String, dynamic>? ?? {};
      final geometry = feature['geometry'] as Map<String, dynamic>?;
      if (geometry == null) continue;

      String name = 'Unknown';
      if (type == 'Province') {
        name = properties['Name_E']?.toString() ?? 'Unknown';
      } else if (type == 'District') {
        name = properties['DISTRICT']?.toString() ?? 'Unknown';
      } else if (type == 'LocalUnit' || type == 'Ward') {
        name = properties['GaPa_NaPa']?.toString() ?? 'Unknown';
      }

      final String geomType = geometry['type'];
      final coordinates = geometry['coordinates'];

      if (coordinates == null) continue;

      List<List<LatLng>> polys = [];
      double minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;

      void processPolygon(List ring) {
        List<LatLng> poly = [];
        for (var coord in ring) {
          if (coord is List && coord.length >= 2) {
            double lng = (coord[0] as num).toDouble();
            double lat = (coord[1] as num).toDouble();
            
            // Filter invalid coordinates
            if (lat < -90 || lat > 90 || lng < -180 || lng > 180) continue;

            if (lat < minLat) minLat = lat;
            if (lat > maxLat) maxLat = lat;
            if (lng < minLng) minLng = lng;
            if (lng > maxLng) maxLng = lng;
            
            poly.add(LatLng(lat, lng));
          }
        }
        // Basic simplification can be done here if needed, but flutter_map's 
        // PolygonLayer has simplification tolerance which we can use instead.
        if (poly.isNotEmpty) {
          polys.add(poly);
        }
      }

      if (geomType == 'Polygon') {
        // coordinates[0] is the exterior ring
        processPolygon(coordinates[0]);
      } else if (geomType == 'MultiPolygon') {
        for (var poly in coordinates) {
          if (poly is List && poly.isNotEmpty) {
            processPolygon(poly[0]);
          }
        }
      }

      if (polys.isNotEmpty) {
        regions.add(MapRegion(
          name: name,
          type: type,
          bounds: LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)),
          polygons: polys,
        ));
      }
    }
    return regions;
  }

  /// Identifies which region was tapped using bounds broad-phase and ray-casting narrow-phase
  String? identifyRegion(LatLng point, List<MapRegion> regions) {
    for (var region in regions) {
      if (region.bounds.contains(point)) {
        for (var poly in region.polygons) {
          if (_isPointInPolygon(point, poly)) {
            return region.name;
          }
        }
      }
    }
    return null;
  }

  /// Ray-Casting algorithm for point-in-polygon
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    bool c = false;
    int j = polygon.length - 1;
    for (int i = 0; i < polygon.length; i++) {
      if (((polygon[i].latitude > point.latitude) != (polygon[j].latitude > point.latitude)) &&
          (point.longitude < (polygon[j].longitude - polygon[i].longitude) * 
          (point.latitude - polygon[i].latitude) / (polygon[j].latitude - polygon[i].latitude) + polygon[i].longitude)) {
        c = !c;
      }
      j = i;
    }
    return c;
  }
}
