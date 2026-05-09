import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/storage_constants.dart';
import '../../models/repo_config.dart';

class SettingsLocalDataSource {
  SettingsLocalDataSource(this._prefs);

  final SharedPreferences _prefs;

  Future<RepoConfig?> loadConfig() async {
    final raw = _prefs.getString(StorageConstants.configKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return RepoConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>)
        .normalized();
  }

  Future<void> saveConfig(RepoConfig config) async {
    await _prefs.setString(
      StorageConstants.configKey,
      jsonEncode(config.normalized().toJson()),
    );
  }
}
