import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/errors/app_exceptions.dart';
import '../models/system_settings_model.dart';

class SettingsPersistenceRepository {
  static const _settingsKey = 'system_settings_v1';
  static const _schemaVersion = 2;

  Future<SystemSettingsModel> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_settingsKey);
    if (encoded == null) return const SystemSettingsModel();
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) {
        throw const PersistenceFailure('بنية الإعدادات المحفوظة غير صالحة.');
      }
      final map = Map<String, dynamic>.from(decoded);
      if (map['schemaVersion'] != _schemaVersion) {
        return _migrate(map);
      }
      return SystemSettingsModel.fromJson(map);
    } on AppException {
      rethrow;
    } catch (error) {
      throw PersistenceFailure('تعذر قراءة إعدادات النظام المحفوظة: $error');
    }
  }

  Future<void> saveSettings(SystemSettingsModel settings) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      'schemaVersion': _schemaVersion,
      ...settings.toJson(),
    };
    final success = await prefs.setString(_settingsKey, jsonEncode(payload));
    if (!success) {
      throw const PersistenceFailure('تعذر حفظ إعدادات النظام.');
    }
  }

  SystemSettingsModel _migrate(Map<String, dynamic> old) {
    // Previous schemas have no safetyDesign field. The model supplies an empty,
    // jurisdiction-neutral audit design so old installations remain readable.
    return SystemSettingsModel.fromJson(old);
  }
}
