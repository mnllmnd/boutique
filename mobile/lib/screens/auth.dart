import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../theme.dart';

class LoginPage extends StatefulWidget {
  final void Function(String phone, String? shop, int? id) onLogin;
  const LoginPage({super.key, required this.onLogin});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final phoneCtl = TextEditingController();
  final passCtl = TextEditingController();
  bool loading = false;
  bool obscurePassword = true;

  String get apiHost {
    if (kIsWeb) return 'http://localhost:3000/api';
    try { if (Platform.isAndroid) return 'http://10.0.2.2:3000/api'; } catch(_) {}
    return 'http://localhost:3000/api';
  }

  Future doLogin() async {
    if (phoneCtl.text.trim().isEmpty || passCtl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs'), backgroundColor: kDanger),
      );
      return;
    }
    setState((){loading=true;});
    try {
      final body = {'phone': phoneCtl.text.trim(), 'password': passCtl.text};
      final res = await http.post(Uri.parse('$apiHost/auth/login'), headers: {'Content-Type': 'application/json'}, body: json.encode(body)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final id = data['id'] is int ? data['id'] as int : (data['id'] is String ? int.tryParse(data['id']) : null);
        widget.onLogin(data['phone'], data['shop_name'], id);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connexion échouée: ${res.statusCode}'), backgroundColor: kDanger),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: kDanger),
      );
    } finally { setState(()=>loading=false); }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isSmallScreen = mq.size.width < 360;

    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo & Branding
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: kAccent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.receipt_long_outlined, color: kSurface, size: 44),
                  ),
                  const SizedBox(height: 32),

                  // Title
                  const Text(
                    'BOUTIQUE',
                    style: TextStyle(
                      color: kTextPrimary,
                      fontSize: kFontSize2XL,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Gestion des dettes',
                    style: TextStyle(
                      color: kMuted,
                      fontSize: kFontSizeM,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Form Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Subtitle
                          Text(
                            'Connexion',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 24),

                          // Phone field
                          TextField(
                            controller: phoneCtl,
                            keyboardType: TextInputType.phone,
                            enabled: !loading,
                            decoration: const InputDecoration(
                              labelText: 'Numéro de téléphone',
                              prefixIcon: Icon(Icons.phone_outlined, size: 20),
                              hintText: '+237...',
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Password field
                          TextField(
                            controller: passCtl,
                            obscureText: obscurePassword,
                            enabled: !loading,
                            decoration: InputDecoration(
                              labelText: 'Mot de passe',
                              prefixIcon: const Icon(Icons.lock_outline, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                                onPressed: () => setState(() => obscurePassword = !obscurePassword),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Login button
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: loading ? null : doLogin,
                              child: loading
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(kSurface)))
                                  : const Text('Se connecter', style: TextStyle(fontSize: kFontSizeM, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Signup link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Pas encore inscrit ? ', style: TextStyle(color: kTextSecondary, fontSize: kFontSizeS)),
                              TextButton(
                                onPressed: () {},
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                child: const Text('Créer un compte', style: TextStyle(color: kAccent, fontWeight: FontWeight.w600, fontSize: kFontSizeS)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class RegisterPage extends StatefulWidget {
  final void Function(String phone, String? shop, int? id) onRegister;
  const RegisterPage({super.key, required this.onRegister});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final phoneCtl = TextEditingController();
  final passCtl = TextEditingController();
  final shopCtl = TextEditingController();
  bool loading = false;
  bool obscurePassword = true;

  String get apiHost {
    if (kIsWeb) return 'http://localhost:3000/api';
    try { if (Platform.isAndroid) return 'http://10.0.2.2:3000/api'; } catch(_) {}
    return 'http://localhost:3000/api';
  }

  Future doRegister() async {
    if (phoneCtl.text.trim().isEmpty || passCtl.text.isEmpty || shopCtl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs'), backgroundColor: kDanger),
      );
      return;
    }
    setState(()=>loading=true);
    try {
      final body = {'phone': phoneCtl.text.trim(), 'password': passCtl.text, 'shop_name': shopCtl.text.trim()};
      final res = await http.post(Uri.parse('$apiHost/auth/register'), headers: {'Content-Type': 'application/json'}, body: json.encode(body)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 201) {
        final data = json.decode(res.body);
        final id = data['id'] is int ? data['id'] as int : (data['id'] is String ? int.tryParse(data['id']) : null);
        widget.onRegister(data['phone'], data['shop_name'], id);
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Inscription échouée: ${res.statusCode}'), backgroundColor: kDanger),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: kDanger),
      );
    } finally { setState(()=>loading=false); }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isSmallScreen = mq.size.width < 360;

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Créer un compte'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Inscription', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 24),
                      TextField(
                        controller: phoneCtl,
                        keyboardType: TextInputType.phone,
                        enabled: !loading,
                        decoration: const InputDecoration(
                          labelText: 'Numéro de téléphone',
                          prefixIcon: Icon(Icons.phone_outlined, size: 20),
                          hintText: '+237...',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: passCtl,
                        obscureText: obscurePassword,
                        enabled: !loading,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                            onPressed: () => setState(() => obscurePassword = !obscurePassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: shopCtl,
                        enabled: !loading,
                        decoration: const InputDecoration(
                          labelText: 'Nom de la boutique',
                          prefixIcon: Icon(Icons.storefront_outlined, size: 20),
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: loading ? null : doRegister,
                          child: loading
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(kSurface)))
                              : const Text('Créer un compte', style: TextStyle(fontSize: kFontSizeM, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Déjà inscrit ? ', style: TextStyle(color: kTextSecondary, fontSize: kFontSizeS)),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                            child: const Text('Se connecter', style: TextStyle(color: kAccent, fontWeight: FontWeight.w600, fontSize: kFontSizeS)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
