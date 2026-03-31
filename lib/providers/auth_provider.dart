import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  String? _apiKey;
  String? _defaultFrom;
  bool _isInitialized = false;

  String? get apiKey => _apiKey;
  String? get defaultFrom => _defaultFrom;
  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _apiKey != null && _apiKey!.isNotEmpty;

  AuthProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString('api_key');
    _defaultFrom = prefs.getString('default_from');
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> login(String apiKey, String defaultFrom) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key', apiKey);
    await prefs.setString('default_from', defaultFrom);
    _apiKey = apiKey;
    _defaultFrom = defaultFrom;
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_key');
    await prefs.remove('default_from');
    _apiKey = null;
    _defaultFrom = null;
    notifyListeners();
  }
}
