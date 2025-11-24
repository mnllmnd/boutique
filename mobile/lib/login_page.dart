import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'app_settings.dart';
import 'services/pin_auth_offline_service.dart';

class LoginPage extends StatefulWidget {
  final void Function(String phone, String? shop, int? id, String? firstName, String? lastName, bool? boutiqueModeEnabled) onLogin;
  const LoginPage({super.key, required this.onLogin});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool isLoginMode = true;
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

  Future _doLogin() async {
    setState(() => loading = true);
    try {
      // Check if user has a stored token (device is already registered)
      final offlineService = PinAuthOfflineService();
      final storedToken = await offlineService.getToken();
      final storedUserId = await offlineService.getUserId();
      
      if (storedToken == null || storedUserId == null) {
        setState(() => loading = false);
        await _showMinimalDialog('Erreur', 'Aucun compte trouvé sur cet appareil. Veuillez vous inscrire d\'abord.');
        return;
      }
      
      // Use stored token to identify user and verify PIN
      final body = {'pin': pin};
      final res = await http.post(
          Uri.parse('$apiHost/auth/login-pin'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $storedToken',
          },
          body: json.encode(body)).timeout(const Duration(seconds: 8));
      
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final id = data['id'] is int ? data['id'] as int : (data['id'] is String ? int.tryParse(data['id']) : null);
        
        // Update auth token and settings
        if (data['auth_token'] != null) {
          final settings = AppSettings();
          await settings.initForOwner(data['phone']);
          await settings.setAuthToken(data['auth_token']);
          if (data['boutique_mode_enabled'] != null) {
            await settings.setBoutiqueModeEnabled(data['boutique_mode_enabled'] as bool);
          }
        }
        
        // Update cached token
        await offlineService.cacheCredentials(
          pin: pin,
          token: data['auth_token'],
          phone: data['phone'],
          firstName: data['first_name'] ?? '',
          lastName: data['last_name'] ?? '',
          shopName: data['shop_name'] ?? '',
          userId: id ?? 0,
        );
        
        widget.onLogin(data['phone'], data['shop_name'], id, data['first_name'], data['last_name'], data['boutique_mode_enabled'] as bool?);
      } else if (res.statusCode == 401) {
        setState(() => loading = false);
        await _showMinimalDialog('Erreur', 'PIN incorrect');
      } else {
        setState(() => loading = false);
        await _showMinimalDialog('Erreur', 'Connexion échouée: ${res.statusCode}');
      }
    } catch (e) {
      setState(() => loading = false);
      await _showMinimalDialog('Erreur', 'Erreur connexion: $e');
    }
  }

  Future _doSignup() async {
    if (phoneCtl.text.isEmpty || firstNameCtl.text.isEmpty || lastNameCtl.text.isEmpty || pin.isEmpty) {
      await _showMinimalDialog('Erreur', 'Veuillez remplir tous les champs.');
      return;
    }
    
    if (pin.length != 4) {
      await _showMinimalDialog('Erreur', 'Le PIN doit contenir exactement 4 chiffres.');
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
          body: json.encode(body)).timeout(const Duration(seconds: 8));
      
      if (res.statusCode == 201) {
        final data = json.decode(res.body);
        final id = data['id'] is int ? data['id'] as int : (data['id'] is String ? int.tryParse(data['id']) : null);
        
        // Save auth token
        if (data['auth_token'] != null) {
          final settings = AppSettings();
          await settings.initForOwner(data['phone']);
          await settings.setAuthToken(data['auth_token']);
          if (data['boutique_mode_enabled'] != null) {
            await settings.setBoutiqueModeEnabled(data['boutique_mode_enabled'] as bool);
          }
        }
        
        // Cache offline
        await PinAuthOfflineService().cacheCredentials(
          pin: pin,
          token: data['auth_token'],
          phone: data['phone'],
          firstName: data['first_name'] ?? '',
          lastName: data['last_name'] ?? '',
          shopName: data['shop_name'] ?? '',
          userId: id ?? 0,
        );
        
        widget.onLogin(data['phone'], data['shop_name'], id, data['first_name'], data['last_name'], data['boutique_mode_enabled'] as bool?);
      } else {
        await _showMinimalDialog('Erreur', 'Inscription échouée: ${res.statusCode}');
      }
    } catch (e) {
      await _showMinimalDialog('Erreur', 'Erreur inscription: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  void _showPinConfirmDialog() {
    final TextEditingController confirmPinCtl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final borderColor = isDark ? Colors.white24 : Colors.black26;
    
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Theme.of(context).cardColor,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('CONFIRMER LE PIN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
              const SizedBox(height: 16),
              const Text('Entrez à nouveau votre PIN à 4 chiffres', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
              const SizedBox(height: 24),
              // PIN input field with system keyboard
              TextField(
                controller: confirmPinCtl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor, letterSpacing: 10),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(borderSide: BorderSide(width: 2)),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor, width: 2)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: textColor, width: 2)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (confirmPinCtl.text == pin) {
                          Navigator.pop(ctx);
                          _doSignup();
                        } else {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Les PINs ne correspondent pas')));
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                      child: const Text('Confirmer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMinimalDialog(String title, String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    
    return showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Theme.of(context).cardColor,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : Colors.black,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                  ),
                  child: Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                      color: isDark ? Colors.black : Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final textColorSecondary = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? Colors.white24 : Colors.black26;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          bottom: TabBar(
            tabs: const [
              Tab(text: 'CONNEXION'),
              Tab(text: 'INSCRIPTION'),
            ],
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            onTap: (index) => setState(() => isLoginMode = (index == 0)),
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              // Login Tab
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(color: isDark ? Colors.white : Colors.black),
                          child: Icon(Icons.receipt_long, color: isDark ? Colors.black : Colors.white, size: 32),
                        ),
                        const SizedBox(height: 16),
                        Text('GESTION DE DETTES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 2, color: textColor)),
                        const SizedBox(height: 4),
                        Text('Connexion PIN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w300, color: textColorSecondary)),
                        const SizedBox(height: 32),

                        Text('ENTREZ VOTRE PIN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: textColorSecondary)),
                        const SizedBox(height: 16),

                        // PIN input field with system keyboard
                        TextField(
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          obscureText: !showPin,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textColor, letterSpacing: 12),
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(borderSide: BorderSide(width: 2)),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor, width: 2)),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: textColor, width: 2)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                            counterText: '',
                            suffixIcon: IconButton(
                              icon: Icon(showPin ? Icons.visibility : Icons.visibility_off, size: 20),
                              onPressed: () => setState(() => showPin = !showPin),
                            ),
                          ),
                          onChanged: (value) {
                            setState(() => pin = value);
                            if (value.length == 4 && isLoginMode) {
                              _doLogin();
                            }
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),

              // Signup Tab
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Text('INSCRIPTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: textColorSecondary)),
                        const SizedBox(height: 16),

                        TextField(
                          controller: firstNameCtl,
                          style: TextStyle(color: textColor, fontSize: 15),
                          decoration: InputDecoration(
                            labelText: 'Prénom',
                            border: const OutlineInputBorder(borderSide: BorderSide(width: 0.5)),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor, width: 0.5)),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: textColor, width: 1)),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextField(
                          controller: lastNameCtl,
                          style: TextStyle(color: textColor, fontSize: 15),
                          decoration: InputDecoration(
                            labelText: 'Nom',
                            border: const OutlineInputBorder(borderSide: BorderSide(width: 0.5)),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor, width: 0.5)),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: textColor, width: 1)),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextField(
                          controller: phoneCtl,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(color: textColor, fontSize: 15),
                          decoration: InputDecoration(
                            labelText: 'Téléphone',
                            border: const OutlineInputBorder(borderSide: BorderSide(width: 0.5)),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor, width: 0.5)),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: textColor, width: 1)),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextField(
                          controller: shopNameCtl,
                          style: TextStyle(color: textColor, fontSize: 15),
                          decoration: InputDecoration(
                            labelText: 'Nom boutique (optionnel)',
                            border: const OutlineInputBorder(borderSide: BorderSide(width: 0.5)),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor, width: 0.5)),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: textColor, width: 1)),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Text('CHOISIR UN PIN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: textColorSecondary)),
                        const SizedBox(height: 12),

                        // PIN input field for signup
                        TextField(
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          obscureText: !showPin,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textColor, letterSpacing: 12),
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(borderSide: BorderSide(width: 2)),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor, width: 2)),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: textColor, width: 2)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                            counterText: '',
                            suffixIcon: IconButton(
                              icon: Icon(showPin ? Icons.visibility : Icons.visibility_off, size: 20),
                              onPressed: () => setState(() => showPin = !showPin),
                            ),
                          ),
                          onChanged: (value) {
                            setState(() => pin = value);
                          },
                        ),
                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: (loading || pin.length != 4) ? null : _showPinConfirmDialog,
                            style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.white : Colors.black),
                            child: Text(pin.length == 4 ? 'CONFIRMER PIN' : 'Entrez 4 chiffres', style: TextStyle(color: isDark ? Colors.black : Colors.white)),
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
