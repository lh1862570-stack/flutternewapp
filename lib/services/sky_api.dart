import 'dart:convert';
import 'package:http/http.dart' as http;

class SkyApiClient {
  SkyApiClient({required this.baseUrl});

  final String baseUrl;
  static const Map<int, String> _friendly400s = <int, String>{
    400: 'Solicitud inválida (400) – revisa parámetros',
    404: 'Endpoint no encontrado (404) – revisa la URL base',
    422: 'Validación fallida (422) – revisa tipos y nombres de query params',
  };

  Future<List<Map<String, dynamic>>> fetchVisibleStars({
    required double latitude,
    required double longitude,
    String? atIsoUtc,
    int? limit,
    double? maxMag,
  }) async {
    final Uri uri = Uri.parse('${baseUrl.replaceAll(RegExp(r"/+$"), '')}/visible-stars').replace(queryParameters: <String, String>{
      'lat': '$latitude',
      'lon': '$longitude',
      if (atIsoUtc != null) 'at': atIsoUtc,
      'limit': '${limit ?? 200}',
      'max_mag': '${maxMag ?? 8.5}',
    });

    final http.Response response = await http.get(
      uri,
      headers: const <String, String>{'Accept': 'application/json'},
    );
    if (response.statusCode != 200) {
      final String msg = _friendly400s[response.statusCode] ?? 'HTTP ${response.statusCode}';
      throw Exception('$msg: ${response.body}');
    }
    final List<dynamic> decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchConstellationFrame({
    required String name,
    required double latitude,
    required double longitude,
    String? atIsoUtc,
    double minAltitudeDeg = -90.0,
  }) async {
    final Uri uri = Uri.parse('${baseUrl.replaceAll(RegExp(r"/+$"), '')}/constellation-frame')
        .replace(queryParameters: <String, String>{
      'name': name,
      'lat': '$latitude',
      'lon': '$longitude',
      if (atIsoUtc != null) 'at': atIsoUtc,
      'min_alt': '$minAltitudeDeg',
    });
    final http.Response response = await http.get(
      uri,
      headers: const <String, String>{'Accept': 'application/json'},
    );
    if (response.statusCode != 200) {
      final String msg = _friendly400s[response.statusCode] ?? 'HTTP ${response.statusCode}';
      throw Exception('$msg: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchVisibleBodies({
    required double latitude,
    required double longitude,
    String? atIsoUtc,
    int? limit,
  }) async {
    final Uri uri = Uri.parse('${baseUrl.replaceAll(RegExp(r"/+$"), '')}/visible-bodies').replace(queryParameters: <String, String>{
      'lat': '$latitude',
      'lon': '$longitude',
      if (atIsoUtc != null) 'at': atIsoUtc,
      if (limit != null) 'limit': '$limit',
    });
    final http.Response response = await http.get(
      uri,
      headers: const <String, String>{'Accept': 'application/json'},
    );
    if (response.statusCode != 200) {
      final String msg = _friendly400s[response.statusCode] ?? 'HTTP ${response.statusCode}';
      throw Exception('$msg: ${response.body}');
    }
    final List<dynamic> decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchIauInFov({
    required double latitude,
    required double longitude,
    required double yawDeg,
    required double pitchDeg,
    required double fovHDeg,
    required double fovVDeg,
    int cacheBucketSeconds = 1,
  }) async {
    final Uri uri = Uri.parse('${baseUrl.replaceAll(RegExp(r"/+$$"), '')}/iau-in-fov').replace(
      queryParameters: <String, String>{
        'lat': '$latitude',
        'lon': '$longitude',
        'yaw_deg': '$yawDeg',
        'pitch_deg': '$pitchDeg',
        'fov_h_deg': '$fovHDeg',
        'fov_v_deg': '$fovVDeg',
        'cache_bucket_s': '$cacheBucketSeconds',
      },
    );
    final http.Response response = await http.get(
      uri,
      headers: const <String, String>{'Accept': 'application/json'},
    );
    if (response.statusCode != 200) {
      final String msg = _friendly400s[response.statusCode] ?? 'HTTP ${response.statusCode}';
      throw Exception('$msg: ${response.body}');
    }
    final dynamic decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{'data': decoded};
  }

  Future<List<Map<String, dynamic>>> fetchConstellationsScreen({
    required double latitude,
    required double longitude,
    required double yawDeg,
    required double pitchDeg,
    required double fovHDeg,
    required double fovVDeg,
    required int widthPx,
    required int heightPx,
    bool clipEdgesToFov = true,
    int cacheBucketSeconds = 1,
  }) async {
    final Uri uri = Uri.parse('${baseUrl.replaceAll(RegExp(r"/+$$"), '')}/constellations-screen').replace(
      queryParameters: <String, String>{
        'lat': '$latitude',
        'lon': '$longitude',
        'yaw_deg': '$yawDeg',
        'pitch_deg': '$pitchDeg',
        'fov_h_deg': '$fovHDeg',
        'fov_v_deg': '$fovVDeg',
        'width_px': '$widthPx',
        'height_px': '$heightPx',
        'clip_edges_to_fov': clipEdgesToFov ? 'true' : 'false',
        'cache_bucket_s': '$cacheBucketSeconds',
      },
    );
    final http.Response response = await http.get(
      uri,
      headers: const <String, String>{'Accept': 'application/json'},
    );
    if (response.statusCode != 200) {
      final String msg = _friendly400s[response.statusCode] ?? 'HTTP ${response.statusCode}';
      throw Exception('$msg: ${response.body}');
    }
    final dynamic decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    if (decoded is Map<String, dynamic>) {
      if (decoded['constellations'] is List) {
        return (decoded['constellations'] as List).cast<Map<String, dynamic>>();
      }
      if (decoded['data'] is List) {
        return (decoded['data'] as List).cast<Map<String, dynamic>>();
      }
    }
    throw Exception('Respuesta no reconocida en /constellations-screen: ${response.body}');
  }
}


