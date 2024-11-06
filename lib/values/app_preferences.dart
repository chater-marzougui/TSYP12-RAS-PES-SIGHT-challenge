import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  static const String _userId = 'userId';

  final SharedPreferences _prefs;

  AppPreferences(this._prefs);

  Future<bool> setUserId(String userId) async {
    try {
      return await _prefs.setString(_userId, userId);
    } catch (e) {
      return false;
    }
  }

  String getUserId() {
    try {
      return _prefs.getString(_userId) ?? 'user1';
    } catch (e) {
      return 'user1';
    }
  }

  Future<void> initDefaults() async {
    if (!_prefs.containsKey(_userId)) {
      String userId = 'user${DateTime.now().millisecondsSinceEpoch}';
      await setUserId(userId);
    }
  }

  Future<bool> clearAllPreferences() async {
    try {
      return await _prefs.clear();
    } catch (e) {
      return false;
    }
  }
}