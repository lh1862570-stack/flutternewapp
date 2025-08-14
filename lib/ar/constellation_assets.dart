import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

Future<List<String>> loadConstellationAssetPaths() async {
  final String manifestContent = await rootBundle.loadString('AssetManifest.json');
  final Map<String, dynamic> manifestMap = jsonDecode(manifestContent) as Map<String, dynamic>;
  final List<String> assets = manifestMap.keys
      .where((String key) => key.startsWith('assets/constellations/') && key.endsWith('.png'))
      .toList()
    ..sort();
  return assets;
}


