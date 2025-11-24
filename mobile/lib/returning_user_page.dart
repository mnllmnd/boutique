import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'app_settings.dart';
import 'services/pin_auth_offline_service.dart';

class ReturningUserPage extends StatefulWidget {
  final String phone;
  final bool hasPinSet;
  final void Function(
    String phone,
    String? shop,
    int? id,
    String? firstName,
    String? lastName,
    bool? boutiqueModeEnabled,
  ) onLogin;

  final VoidCallback onBackToQuickSignup;

  const ReturningUserPage({
    super.key,
    required this.phone,
    required this.hasPinSet,
    required this.onLogin,
    required this.onBackToQuickSignup,
  });

  @override
  State<ReturningUserPage> createState() => _ReturningUserPageState();
}

class _ReturningUserPageState extends State<ReturningUserPage> {
  String pin = '';
  bool loading = false;

  String get apiHost {
    if (kIsWeb) return 'http://localhost:3000/api';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:3000/api';
    } catch (_) {}
    return 'http://localhost:3000/api';
  }

  @override
  void initState() {
    super.initState();
    if (!widget.hasPinSet) {
      Future.delayed(const Duration(milliseconds: 300), _doDirectLogin);
    }
  }

  Future<void> _doDirectLogin() async {
    setState(() => loading = true);
    try {
      final body = {'phone': widget.phone};

      final res = await http.post(
        Uri.parse('$apiHost/auth/login-phone'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final id = data['id'] is int
            ? data['id'] as int
            : (data['id'] is String ? int.tryParse(data['id']) : null);

        if (data['auth_token'] != null) {
          final settings = AppSettings();
          await settings.initForOwner(data['phone']);
          await settings.setAuthToken(data['auth_token']);
          if (data['boutique_mode_enabled'] != null) {
            await settings.setBoutiqueModeEnabled(data['boutique_mode_enabled']);
          }
        }

        await PinAuthOfflineService().cacheCredentials(
          pin: '',
          token: data['auth_token'],
          phone: data['phone'],
          firstName: data['first_name'] ?? '',
          lastName: data['last_name'] ?? '',
          shopName: data['shop_name'] ?? '',
          userId: id ?? 0,
        );

        if (mounted) {
          widget.onLogin(
            data['phone'],
            data['shop_name'],
            id,
            data['first_name'],
            data['last_name'],
            data['boutique_mode_enabled'],
          );
        }
      } else {
        setState(() => loading = false);
        _showError('Connexion échouée: ${res.statusCode}');
      }
    } catch (e) {
      setState(() => loading = false);
      _showError('Erreur connexion: $e');
    }
  }

  Future<void> _doLoginWithPin() async {
    if (pin.length != 4) return;

    setState(() => loading = true);

    try {
      final loginPhoneRes = await http.post(
        Uri.parse('$apiHost/auth/login-phone'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': widget.phone}),
      ).timeout(const Duration(seconds: 8));

      if (loginPhoneRes.statusCode != 200) {
        setState(() => loading = false);
        _showError('Utilisateur non trouvé');
        return;
      }

      final phoneLoginData = json.decode(loginPhoneRes.body);
      final tempToken =
          phoneLoginData['temp_token'] ?? phoneLoginData['auth_token'];

      final res = await http.post(
        Uri.parse('$apiHost/auth/login-pin'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tempToken',
        },
        body: json.encode({'pin': pin}),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);

        final id = data['id'] is int
            ? data['id']
            : (data['id'] is String ? int.tryParse(data['id']) : null);

        if (data['auth_token'] != null) {
          final settings = AppSettings();
          await settings.initForOwner(data['phone']);
          await settings.setAuthToken(data['auth_token']);
          if (data['boutique_mode_enabled'] != null) {
            await settings.setBoutiqueModeEnabled(data['boutique_mode_enabled']);
          }
        }

        await PinAuthOfflineService().cacheCredentials(
          pin: pin,
          token: data['auth_token'],
          phone: data['phone'],
          firstName: data['first_name'] ?? '',
          lastName: data['last_name'] ?? '',
          shopName: data['shop_name'] ?? '',
          userId: id ?? 0,
        );

        if (mounted) {
          widget.onLogin(
            data['phone'],
            data['shop_name'],
            id,
            data['first_name'],
            data['last_name'],
            data['boutique_mode_enabled'],
          );
        }
      } else if (res.statusCode == 401) {
        setState(() {
          loading = false;
          pin = '';
        });
        _showError('PIN incorrect');
      } else {
        setState(() => loading = false);
        _showError('Connexion échouée: ${res.statusCode}');
      }
    } catch (e) {
      setState(() => loading = false);
      _showError('Erreur connexion: $e');
    }
  }

  void _addPin(String digit) {
    if (pin.length < 4) {
      setState(() => pin += digit);
      if (pin.length == 4) {
        Future.delayed(const Duration(milliseconds: 200), _doLoginWithPin);
      }
    }
  }

  void _deletePin() {
    if (pin.isNotEmpty) {
      setState(() => pin = pin.substring(0, pin.length - 1));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: widget.onBackToQuickSignup,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Icon(Icons.lock, size: 32, color: textColor),
              const SizedBox(height: 12),
              Text('ENTREZ VOTRE PIN',
                  style: TextStyle(fontSize: 11, color: textColor)),
              const SizedBox(height: 6),
              Text(widget.phone,
                  style: TextStyle(
                      fontSize: 12, color: textColor.withOpacity(0.6))),
              const SizedBox(height: 20),

              if (widget.hasPinSet) ...[
                // ----- PIN DOTS -----
                SizedBox(
                  width: 100,
                  height: 24,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      4,
                      (index) => Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index < pin.length
                              ? textColor
                              : Colors.transparent,
                          border: Border.all(color: textColor, width: 1),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ----- KEYPAD FIXE (SOLUTION) -----
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildKeypadRow(['1', '2', '3'], textColor),
                    const SizedBox(height: 10),
                    _buildKeypadRow(['4', '5', '6'], textColor),
                    const SizedBox(height: 10),
                    _buildKeypadRow(['7', '8', '9'], textColor),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildActionButton(Icons.backspace, _deletePin, textColor),
                        const SizedBox(width: 16),
                        _buildKeyButton('0', textColor),
                        const SizedBox(width: 16),
                        _buildActionButton(Icons.clear, () => setState(() => pin = ''), textColor),
                      ],
                    ),
                  ],
                ),
              ] else
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Connexion...', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // KEYPAD FIXE - TOUS LES CHIFFRES VISIBLES
  // -------------------------------------------------------------

  Widget _buildKeypadRow(List<String> digits, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits.map((d) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _buildKeyButton(d, textColor),
        );
      }).toList(),
    );
  }

  Widget _buildKeyButton(String digit, Color textColor) {
    return InkWell(
      onTap: () => _addPin(digit),
      child: Container(
        width: 60,  // Taille parfaite pour mobile
        height: 60,
        decoration: BoxDecoration(
          border: Border.all(color: textColor.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            digit,
            style: TextStyle(fontSize: 18, color: textColor),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onTap, Color textColor) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          border: Border.all(color: textColor.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(icon, size: 20, color: textColor),
        ),
      ),
    );
  }
}