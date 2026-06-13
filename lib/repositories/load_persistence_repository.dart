import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/load_model.dart';

class LoadPersistenceRepository {
  static const String _loadsKey = 'saved_loads';

  Future<void> saveLoads(List<LoadModel> loads) async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(
      loads.map((load) => load.toJson()).toList(),
    );
    await prefs.setString(_loadsKey, encodedData);
  }

  Future<List<LoadModel>> loadLoads() async {
    final prefs = await SharedPreferences.getInstance();
    final String? loadsString = prefs.getString(_loadsKey);

    if (loadsString == null) return [];

    try {
      final List<dynamic> decodedData = jsonDecode(loadsString);
      return decodedData
          .map((item) => LoadModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }
}
