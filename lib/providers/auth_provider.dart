import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:dokkan/data/repositories/app_settings_repository.dart';

class AuthProvider extends ChangeNotifier {
  final AppSettingsRepository _settingsRepo = AppSettingsRepository();

  bool _isAdminMode = false;
  bool _pinIsDefault = true;
  bool _isInitialized = false;

  bool get isAdminMode => _isAdminMode;
  bool get pinIsDefault => _pinIsDefault;
  bool get isInitialized => _isInitialized;

  AuthProvider() {
    init();
  }

  Future<void> init() async {
    _pinIsDefault = await _settingsRepo.isPinDefault();
    _isInitialized = true;
    notifyListeners();
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<bool> verifyPin(String pin) async {
    final storedHash = await _settingsRepo.getPinHash();
    final inputHash = _hashPin(pin);
    
    // If PIN hash is default ('1234' hash) and not set, or matches
    if (storedHash == null) {
      // Fallback if DB didn't initialize correctly
      final defaultHash = _hashPin('1234');
      if (inputHash == defaultHash) {
        _isAdminMode = true;
        notifyListeners();
        return true;
      }
      return false;
    }

    if (storedHash == inputHash) {
      _isAdminMode = true;
      notifyListeners();
      return true;
    }
    
    return false;
  }

  Future<void> updatePin(String newPin) async {
    final newHash = _hashPin(newPin);
    await _settingsRepo.savePinHash(newHash);
    _pinIsDefault = false;
    _isAdminMode = true; // Automatically log in as admin when PIN is setup
    notifyListeners();
  }

  void logout() {
    _isAdminMode = false;
    notifyListeners();
  }

  void setAdminMode(bool value) {
    _isAdminMode = value;
    notifyListeners();
  }
}
