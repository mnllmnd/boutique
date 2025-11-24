import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'app_settings.dart';
import 'services/pin_auth_offline_service.dart';

/// Page d'authentification unifiée - Login ou Signup avec PIN
class PinAuthPage extends StatefulWidget {
  final void Function(String phone, String? shop, int? id, String? firstName, String? lastName, bool? boutiqueModeEnabled) onLogin;
  
  const PinAuthPage({super.key, required this.onLogin});

  @override
  State<PinAuthPage> createState() => _PinAuthPageState();
}

class _PinAuthPageState extends State<PinAuthPage> {
  bool isLoginMode = true; // true = login, false = signup
  String pin = '';
  bool loading = false;
  bool showPin = false;

  // Signup fields
  late TextEditingController phoneCtl;
  late TextEditingController firstNameCtl;
  late TextEditingController lastNameCtl;
  late TextEditingController shopNameCtl;

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
    phoneCtl = TextEditingController();
    firstNameCtl = TextEditingController();
    lastNameCtl = TextEditingController();
    shopNameCtl = TextEditingController();
  }

  @override
  void dispose() {
    phoneCtl.dispose();
    firstNameCtl.dispose();
    lastNameCtl.dispose();
    shopNameCtl.dispose();
    super.dispose();
  }

  void _addPin(String digit) {
    if (pin.length < 4) {
      setState(() {
        pin += digit;
      });
      if (pin.length == 4) {
        Future.delayed(const Duration(milliseconds: 300), 
          isLoginMode ? _doLogin : _validateAndShowPinConfirm);
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

    setState(() => loading = true);

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

        // Cache PIN locally
        final pinService = PinAuthOfflineService();
        await pinService.cacheCredentials(
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

  Future<void> _validateAndShowPinConfirm() async {
    // In signup mode, show confirmation dialog for PIN
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmez votre PIN'),
        content: Text('Vous avez entré le PIN: $pin\n\nCette page va maintenant basculer pour confirmation.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _clearPin();
            },
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showPinConfirmationDialog();
            },
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPinConfirmationDialog() async {
    String confirmPin = '';
    bool showConfirmPin = false;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Confirmez le PIN'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Veuillez entrer à nouveau votre PIN pour confirmation'),
                const SizedBox(height: 20),
                // PIN Display
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    4,
                    (index) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: index < confirmPin.length ? Colors.blue : Colors.white,
                          border: Border.all(color: Colors.blue, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: index < confirmPin.length
                            ? (showConfirmPin
                                ? Center(
                                    child: Text(
                                      confirmPin[index],
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.circle, color: Colors.white, size: 14))
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Number pad
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  children: [
                    for (int i = 1; i <= 9; i++)
                      _buildSmallButton(i.toString(), () {
                        if (confirmPin.length < 4) {
                          setStateDialog(() => confirmPin += i.toString());
                        }
                      }),
                    _buildSmallButton(
                      Icons.visibility.toString(),
                      () => setStateDialog(() => showConfirmPin = !showConfirmPin),
                      isIcon: true,
                      icon: showConfirmPin ? Icons.visibility : Icons.visibility_off,
                    ),
                    _buildSmallButton('0', () {
                      if (confirmPin.length < 4) {
                        setStateDialog(() => confirmPin += '0');
                      }
                    }),
                    _buildSmallButton(
                      'DEL',
                      () {
                        if (confirmPin.isNotEmpty) {
                          setStateDialog(() => confirmPin = confirmPin.substring(0, confirmPin.length - 1));
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _clearPin();
              },
              child: const Text('Annuler'),
            ),
            if (confirmPin == pin)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _doSignup();
                },
                child: const Text('Confirmer'),
              )
            else if (confirmPin.length == 4)
              const ElevatedButton(
                onPressed: null,
                child: Text('PINs ne correspondent pas'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallButton(
    String label,
    VoidCallback onPressed, {
    bool isIcon = false,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[300],
          padding: const EdgeInsets.all(8),
        ),
        child: isIcon
            ? Icon(icon, size: 16)
            : Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Future<void> _doSignup() async {
    if (firstNameCtl.text.isEmpty || lastNameCtl.text.isEmpty || phoneCtl.text.isEmpty) {
      _showError('Erreur', 'Veuillez remplir tous les champs');
      return;
    }

    setState(() => loading = true);

    try {
      final body = {
        'phone': phoneCtl.text.trim(),
        'pin': pin,
        'first_name': firstNameCtl.text.trim(),
        'last_name': lastNameCtl.text.trim(),
        'shop_name': shopNameCtl.text.trim().isEmpty ? null : shopNameCtl.text.trim(),
      };

      final res = await http.post(
        Uri.parse('$apiHost/auth/register-pin'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 201) {
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

        // Cache PIN locally
        final pinService = PinAuthOfflineService();
        await pinService.cacheCredentials(
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
            data['boutique_mode_enabled'] as bool?,
          );
        }
      } else {
        final errorMsg = json.decode(res.body)['error'] ?? 'Inscription échouée';
        if (mounted) {
          _showError('Erreur', errorMsg);
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Erreur', 'Erreur inscription: $e');
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Mode Switch
            if (!loading)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isLoginMode ? null : () => setState(() {
                          isLoginMode = true;
                          _clearPin();
                        }),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isLoginMode ? Colors.blue : Colors.grey[300],
                        ),
                        child: Text(
                          'Connexion',
                          style: TextStyle(
                            color: isLoginMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isLoginMode ? () => setState(() {
                          isLoginMode = false;
                          _clearPin();
                        }) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: !isLoginMode ? Colors.blue : Colors.grey[300],
                        ),
                        child: Text(
                          'Inscription',
                          style: TextStyle(
                            color: !isLoginMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
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
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2.0),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Gestion des dettes',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 48),

                        // Content based on mode
                        if (isLoginMode) ...[
                          // LOGIN MODE
                          const Text(
                            'Entrez votre PIN',
                            style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 32),

                          // PIN Display
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                4,
                                (index) => Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: index < pin.length ? Colors.blue : Colors.white,
                                      border: Border.all(color: Colors.blue, width: 2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
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
                                            : const Icon(Icons.circle, color: Colors.white, size: 20))
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          // SIGNUP MODE
                          const Text(
                            'Créer un nouveau compte',
                            style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 24),

                          // Name fields
                          TextField(
                            controller: firstNameCtl,
                            enabled: !loading,
                            decoration: InputDecoration(
                              labelText: 'Prénom',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 16),

                          TextField(
                            controller: lastNameCtl,
                            enabled: !loading,
                            decoration: InputDecoration(
                              labelText: 'Nom',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 16),

                          TextField(
                            controller: phoneCtl,
                            enabled: !loading,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Numéro de téléphone',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 16),

                          TextField(
                            controller: shopNameCtl,
                            enabled: !loading,
                            decoration: InputDecoration(
                              labelText: 'Nom du magasin (optionnel)',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 32),

                          const Text(
                            'Choisissez un PIN (4 chiffres)',
                            style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 16),

                          // PIN Display for signup
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                4,
                                (index) => Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: index < pin.length ? Colors.blue : Colors.white,
                                      border: Border.all(color: Colors.blue, width: 2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: index < pin.length
                                        ? (showPin
                                            ? Text(
                                                pin[index],
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Icon(Icons.circle, color: Colors.white, size: 14))
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 32),

                        // PIN Keypad (only visible in relevant mode)
                        if (isLoginMode || pin.isEmpty)
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
                                        onPressed: loading ? null : () {
                                          setState(() => showPin = !showPin);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          backgroundColor: Colors.grey[600],
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
                                        onPressed: loading || pin.isEmpty ? null : _deletePin,
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          backgroundColor: Colors.red,
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

                        if (pin.isNotEmpty && (isLoginMode || pin.length == 4))
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: TextButton(
                              onPressed: loading ? null : _clearPin,
                              child: const Text('Effacer tout', style: TextStyle(color: Colors.red)),
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
            ),
          ],
        ),
      ),
    );
  }
}
