import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/load_model.dart';

class LoadPersistenceRepository {
  static const String _loadsKey = 'saved_loads_data';

  Future<void> saveLoads(List<LoadModel> loads) async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(loads.map((e) => e.toJson()).toList());
    await prefs.setString(_loadsKey, encodedData);
  }

  Future<List<LoadModel>> loadLoads() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString(_loadsKey);
    if (encodedData != null && encodedData.isNotEmpty) {
      try {
        final List<dynamic> decodedData = jsonDecode(encodedData);
        return decodedData.map((e) => LoadModel.fromJson(e as Map<String, dynamic>)).toList();
      } catch (e) {
        return [];
      }
    }
    return [];
  }
}
