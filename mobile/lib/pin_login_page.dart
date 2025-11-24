import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'app_settings.dart';

class PinLoginPage extends StatefulWidget {
  final void Function(String phone, String? shop, int? id, String? firstName, String? lastName, bool? boutiqueModeEnabled) onLogin;
  const PinLoginPage({super.key, required this.onLogin});
  
  @override
  State<PinLoginPage> createState() => _PinLoginPageState();
}

class _PinLoginPageState extends State<PinLoginPage> {
  String pin = '';
  bool loading = false;
  bool showPin = false;

  String get apiHost {
    if (kIsWeb) return 'http://localhost:3000/api';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:3000/api';
    } catch (_) {}
    return 'http://localhost:3000/api';
  }

  void _addPin(String digit) {
    if (pin.length < 4) {
      setState(() {
        pin += digit;
      });
      // Auto-login when 4 digits reached
      if (pin.length == 4) {
        Future.delayed(const Duration(milliseconds: 300), _doLogin);
      }
    }
  }

  void _deletePin() {
    if (pin.isNotEmpty) {
      setState(() {
        pin = pin.substring(0, pin.length - 1);
      });
    }
  }

  void _clearPin() {
    setState(() {
      pin = '';
    });
  }

  Future<void> _doLogin() async {
    if (pin.length != 4) {
      _showError('Erreur', 'Le PIN doit contenir 4 chiffres');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final body = {'pin': pin};
      final res = await http.post(
        Uri.parse('$apiHost/auth/login-pin'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final id = data['id'] is int
            ? data['id'] as int
            : (data['id'] is String ? int.tryParse(data['id']) : null);

        // Save auth token
        if (data['auth_token'] != null) {
          final settings = AppSettings();
          await settings.initForOwner(data['phone']);
          await settings.setAuthToken(data['auth_token']);
          if (data['boutique_mode_enabled'] != null) {
            await settings.setBoutiqueModeEnabled(data['boutique_mode_enabled'] as bool);
          }
        }

        if (mounted) {
          widget.onLogin(
            data['phone'],
            data['shop_name'],
            id,
            data['first_name'],
            data['last_name'],
            data['boutique_mode_enabled'] as bool?,
          );
        }
      } else {
        if (mounted) {
          _showError('Erreur', 'PIN incorrect. Réessayez.');
          _clearPin();
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Erreur', 'Erreur de connexion: $e');
        _clearPin();
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _showError(String title, String message) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildPinButton(String label, VoidCallback onPressed) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.blue,
            disabledBackgroundColor: Colors.grey,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                const Text(
                  'BOUTIQUE',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Gestion des dettes',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 48),

                // PIN Display
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Entrez votre PIN',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          4,
                          (index) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: index < pin.length
                                    ? Colors.blue
                                    : Colors.white,
                                border: Border.all(
                                  color: Colors.blue,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: index < pin.length
                                    ? (showPin
                                        ? Text(
                                            pin[index],
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.circle,
                                            color: Colors.white,
                                            size: 20,
                                          ))
                                    : const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // PIN Keypad
                Column(
                  children: [
                    Row(
                      children: [
                        _buildPinButton('1', () => _addPin('1')),
                        _buildPinButton('2', () => _addPin('2')),
                        _buildPinButton('3', () => _addPin('3')),
                      ],
                    ),
                    Row(
                      children: [
                        _buildPinButton('4', () => _addPin('4')),
                        _buildPinButton('5', () => _addPin('5')),
                        _buildPinButton('6', () => _addPin('6')),
                      ],
                    ),
                    Row(
                      children: [
                        _buildPinButton('7', () => _addPin('7')),
                        _buildPinButton('8', () => _addPin('8')),
                        _buildPinButton('9', () => _addPin('9')),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ElevatedButton(
                              onPressed: loading
                                  ? null
                                  : () {
                                      setState(() {
                                        showPin = !showPin;
                                      });
                                    },
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: Colors.grey[600],
                                disabledBackgroundColor: Colors.grey,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Icon(
                                showPin ? Icons.visibility : Icons.visibility_off,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                        _buildPinButton('0', () => _addPin('0')),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ElevatedButton(
                              onPressed:
                                  loading || pin.isEmpty ? null : _deletePin,
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: Colors.red,
                                disabledBackgroundColor: Colors.grey,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Icon(
                                Icons.backspace,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Clear button
                if (pin.isNotEmpty)
                  TextButton(
                    onPressed: loading ? null : _clearPin,
                    child: const Text(
                      'Effacer tout',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),

                if (loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
