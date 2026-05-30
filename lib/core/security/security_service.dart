import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SecurityService {
  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  SecurityService({
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuth,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _localAuth = localAuth ?? LocalAuthentication();

  // Save seed phrase mnemonic securely
  Future<void> saveMnemonic(List<String> mnemonic) async {
    final phrase = mnemonic.join(' ');
    await _storage.write(key: 'secure_wallet_mnemonic', value: phrase);
  }

  // Read seed phrase mnemonic from keychain
  Future<List<String>?> getMnemonic() async {
    final phrase = await _storage.read(key: 'secure_wallet_mnemonic');
    if (phrase == null || phrase.isEmpty) return null;
    return phrase.split(' ');
  }

  // Purge credentials (useful on logout / reset)
  Future<void> wipeSecurityCredentials() async {
    await _storage.delete(key: 'secure_wallet_mnemonic');
    await _storage.delete(key: 'auth_jwt_token');
    await _storage.delete(key: 'auth_refresh_token');
  }

  // Biometric validation checker (Touch ID / Face ID)
  Future<bool> authenticateWithBiometrics() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!isAvailable || !isDeviceSupported) return false;

      return await _localAuth.authenticate(
        localizedReason: 'Scan biometrics to verify ZeroPay wallet credentials',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } on PlatformException catch (_) {
      return false;
    }
  }

  // Check if biometric authentication hardware exists
  Future<bool> hasBiometricHardware() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }
}

// Riverpod Provider
final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService();
});
