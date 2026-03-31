import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/email.dart';

class AuthProvider extends ChangeNotifier {
  String? _apiKey;
  String? _defaultFrom;
  String? _displayName;
  bool _isInitialized = false;

  String? get apiKey => _apiKey;
  String? get defaultFrom => _defaultFrom;
  String? get displayName => _displayName;
  String? get formattedFrom => _defaultFrom == null
      ? null
      : formatMailbox(_defaultFrom!, name: _displayName);
  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _apiKey != null && _apiKey!.isNotEmpty;

  AuthProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString('api_key');
    _defaultFrom = prefs.getString('default_from');
    _displayName = prefs.getString('display_name');
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> login(
    String apiKey,
    String defaultFrom,
    String displayName,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key', apiKey);
    await prefs.setString('default_from', defaultFrom);
    await prefs.setString('display_name', displayName);
    _apiKey = apiKey;
    _defaultFrom = defaultFrom;
    _displayName = displayName;
    notifyListeners();
  }

  Future<void> updateProfile({
    required String defaultFrom,
    required String displayName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_from', defaultFrom);
    await prefs.setString('display_name', displayName);
    _defaultFrom = defaultFrom;
    _displayName = displayName;
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_key');
    await prefs.remove('default_from');
    await prefs.remove('display_name');
    _apiKey = null;
    _defaultFrom = null;
    _displayName = null;
    notifyListeners();
  }
}
