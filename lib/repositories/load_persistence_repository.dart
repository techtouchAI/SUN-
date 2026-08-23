import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/errors/app_exceptions.dart';
import '../models/load_model.dart';

class LoadPersistenceRepository {
  static const String _loadsKey = 'saved_loads_v1';
  static const String _backupKey = 'saved_loads_v1_backup';
  static const int _schemaVersion = 1;
  Future<void> _writeQueue = Future<void>.value();

  Future<void> saveLoads(List<LoadModel> loads) {
    final snapshot = List<LoadModel>.unmodifiable(loads);
    _writeQueue = _writeQueue.then((_) => _saveSnapshot(snapshot));
    return _writeQueue;
  }

  Future<List<LoadModel>> loadLoads() async {
    final prefs = await SharedPreferences.getInstance();
    final primary = prefs.getString(_loadsKey);
    if (primary == null) return <LoadModel>[];

    try {
      return _decodeLoads(primary);
    } catch (primaryError) {
      final backup = prefs.getString(_backupKey);
      if (backup != null) {
        try {
          return _decodeLoads(backup);
        } catch (_) {
          throw PersistenceFailure(
            'تعذر قراءة الأحمال الأساسية والنسخة الاحتياطية: $primaryError',
          );
        }
      }
      throw PersistenceFailure(
        'بيانات الأحمال تالفة ولا توجد نسخة احتياطية قابلة للاسترداد: $primaryError',
      );
    }
  }

  List<LoadModel> _decodeLoads(String encoded) {
    final decoded = jsonDecode(encoded);
    List<dynamic> rawItems;
    if (decoded is List) {
      // Compatibility with the pre-versioned format.
      rawItems = decoded;
    } else if (decoded is Map &&
        decoded['schemaVersion'] == _schemaVersion &&
        decoded['loads'] is List) {
      rawItems = decoded['loads'] as List<dynamic>;
    } else {
      throw const PersistenceFailure('مخطط بيانات الأحمال غير معروف.');
    }

    return rawItems
        .map((item) {
          if (item is! Map) {
            throw const PersistenceFailure('أحد سجلات الأحمال غير صالح.');
          }
          try {
            return LoadModel.fromJson(Map<String, dynamic>.from(item));
          } catch (error) {
            throw PersistenceFailure('سجل حمل محفوظ غير صالح: $error');
          }
        })
        .toList(growable: false);
  }

  Future<void> _saveSnapshot(List<LoadModel> loads) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString(_loadsKey);
    if (previous != null) {
      final backupSaved = await prefs.setString(_backupKey, previous);
      if (!backupSaved) {
        throw const PersistenceFailure('تعذر إنشاء نسخة احتياطية من الأحمال.');
      }
    }
    final payload = jsonEncode({
      'schemaVersion': _schemaVersion,
      'loads': loads.map((load) => load.toJson()).toList(),
    });
    final saved = await prefs.setString(_loadsKey, payload);
    if (!saved) {
      throw const PersistenceFailure('تعذر حفظ الأحمال.');
    }
  }
}
