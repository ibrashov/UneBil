import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/learning_fact.dart';
import '../models/topic.dart';

class StorageService {
  StorageService(this._prefs);

  static const _topicsKey = 'unebil.topics';
  static const _factsKey = 'unebil.facts';
  static const _settingsKey = 'unebil.settings';

  final SharedPreferences _prefs;
  bool _hadReadError = false;

  bool get hadReadError => _hadReadError;

  void resetReadError() => _hadReadError = false;

  List<Topic> loadTopics() {
    final raw = _prefs.getString(_topicsKey);
    if (raw == null) {
      return <Topic>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <Topic>[];
      }
      return decoded
          .whereType<Map>()
          .map((item) => Topic.fromJson(Map<String, dynamic>.from(item)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      _hadReadError = true;
      return <Topic>[];
    }
  }

  Future<void> saveTopics(List<Topic> topics) {
    return _prefs.setString(
      _topicsKey,
      jsonEncode(topics.map((topic) => topic.toJson()).toList()),
    );
  }

  List<LearningFact> loadFacts() {
    final raw = _prefs.getString(_factsKey);
    if (raw == null) {
      return <LearningFact>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <LearningFact>[];
      }
      return decoded
          .whereType<Map>()
          .map((item) => LearningFact.fromJson(Map<String, dynamic>.from(item)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      _hadReadError = true;
      return <LearningFact>[];
    }
  }

  bool get factsNeedReadStateMigration {
    final raw = _prefs.getString(_factsKey);
    if (raw == null) {
      return false;
    }
    try {
      final decoded = jsonDecode(raw);
      return decoded is List &&
          decoded.whereType<Map>().any((item) => !item.containsKey('readAt'));
    } catch (_) {
      return false;
    }
  }

  Future<void> saveFacts(List<LearningFact> facts) {
    return _prefs.setString(
      _factsKey,
      jsonEncode(facts.map((fact) => fact.toJson()).toList()),
    );
  }

  AppSettings loadSettings() {
    final raw = _prefs.getString(_settingsKey);
    if (raw == null) {
      return AppSettings.defaultSettings;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return AppSettings.defaultSettings;
      }
      return AppSettings.fromJson(decoded);
    } catch (_) {
      _hadReadError = true;
      return AppSettings.defaultSettings;
    }
  }

  Future<void> saveSettings(AppSettings settings) {
    return _prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }
}
