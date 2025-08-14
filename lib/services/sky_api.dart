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
}


