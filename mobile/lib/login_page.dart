import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

// Colors (keep in sync with main theme)
const Color kBackground = Color(0xFF0F1113);
const Color kCard = Color(0xFF151718);
const Color kAccent = Color.fromARGB(199, 105, 60, 149);
const Color kMuted = Color.fromARGB(255, 164, 154, 166);
const Color kTextPrimary = Color(0xFFFFFFFF);
const Color kTextSecondary = Color.fromARGB(255, 163, 154, 166);

class LoginPage extends StatefulWidget {
  final void Function(String phone, String? shop, int? id, String? firstName, String? lastName) onLogin;
  LoginPage({required this.onLogin});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final phoneCtl = TextEditingController();
  final passCtl = TextEditingController();
  bool loading = false;

  String get apiHost {
    if (kIsWeb) return 'http://localhost:3000/api';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:3000/api';
    } catch (_) {}
    return 'http://localhost:3000/api';
  }

  Future doLogin() async {
    setState(() {
      loading = true;
    });
    try {
      final body = {'phone': phoneCtl.text.trim(), 'password': passCtl.text};
      final res = await http.post(
          Uri.parse('$apiHost/auth/login'.replaceFirst('\u007f', '')),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body)).timeout(Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final id = data['id'] is int
            ? data['id'] as int
            : (data['id'] is String ? int.tryParse(data['id']) : null);
        widget.onLogin(data['phone'], data['shop_name'], id, data['first_name'], data['last_name']);
      } else {
        final body = res.body;
        final lower = body.toLowerCase();
        String friendly;
        if (res.statusCode == 401 || lower.contains('invalid') || lower.contains('incorrect') || lower.contains('credentials') || lower.contains('wrong')) {
          friendly = 'Identifiants incorrects. Vérifiez le numéro et le mot de passe.';
        } else if (res.statusCode == 404 || lower.contains('not found')) {
          friendly = 'Compte introuvable. Vérifiez le numéro ou créez un compte.';
        } else {
          // try to show server message if available
          try {
            final parsed = json.decode(body);
            if (parsed is Map && parsed['message'] != null) friendly = parsed['message'].toString();
            else friendly = 'Connexion échouée (${res.statusCode}).';
          } catch (_) {
            friendly = 'Connexion échouée (${res.statusCode}).';
          }
        }
        await showDialog(
            context: context,
            builder: (c) => AlertDialog(
                  title: Text('Erreur'),
                  content: Text(friendly),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(c).pop(),
                        child: Text('OK'))
                  ],
                ));
      }
    } catch (e) {
      await showDialog(
          context: context,
          builder: (c) => AlertDialog(
                title: Text('Erreur'),
                content: Text('Erreur login: $e'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(c).pop(),
                      child: Text('OK'))
                ],
              ));
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context).size;
    final isNarrow = mq.width < 420;
    
    return Scaffold(
      backgroundColor: kBackground,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo/Brand Section
                Container(
                  margin: EdgeInsets.only(bottom: 40),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: kAccent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.receipt_long,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'GESTION DE DETTES',
                        style: TextStyle(
                          color: kTextPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Application Boutique',
                        style: TextStyle(
                          color: kTextSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Card - Style Zara
                Card(
                  color: kCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: Colors.black.withOpacity(0.3),
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title Section
                        Center(
                          child: Column(
                            children: [
                              Text(
                                'Connexion',
                                style: TextStyle(
                                  color: kTextPrimary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Accédez à votre espace',
                                style: TextStyle(
                                  color: kTextSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 32),

                        // Phone Field
                        TextField(
                          controller: phoneCtl,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(color: kTextPrimary),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.2),
                            labelText: 'Numéro de téléphone',
                            labelStyle: TextStyle(color: kTextSecondary),
                            prefixIcon: Icon(Icons.phone_rounded, color: kTextSecondary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          ),
                        ),
                        SizedBox(height: 16),

                        // Password Field
                        TextField(
                          controller: passCtl,
                          obscureText: true,
                          style: TextStyle(color: kTextPrimary),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.2),
                            labelText: 'Mot de passe',
                            labelStyle: TextStyle(color: kTextSecondary),
                            prefixIcon: Icon(Icons.lock_rounded, color: kTextSecondary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          ),
                        ),
                        SizedBox(height: 24),

                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: loading ? null : doLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kAccent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: loading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Se connecter',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        SizedBox(height: 16),

                        // Register Link
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RegisterPage(onRegister: (phone, shop, id, firstName, lastName) {
                                  widget.onLogin(phone, shop, id, firstName, lastName);
                                }),
                              ),
                            ),
                            child: RichText(
                              text: TextSpan(
                                text: 'Pas de compte ? ',
                                style: TextStyle(color: kTextSecondary),
                                children: [
                                  TextSpan(
                                    text: 'Créer un compte',
                                    style: TextStyle(
                                      color: kAccent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Version info
                Container(
                  margin: EdgeInsets.only(top: 24),
                  child: Text(
                    'Version debug',
                    style: TextStyle(
                      color: kTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  final void Function(String phone, String? shop, int? id, String? firstName, String? lastName) onRegister;
  RegisterPage({required this.onRegister});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final phoneCtl = TextEditingController();
  final passCtl = TextEditingController();
  final firstNameCtl = TextEditingController();
  final lastNameCtl = TextEditingController();
  final shopCtl = TextEditingController();
  bool loading = false;

  String get apiHost {
    if (kIsWeb) return 'http://localhost:3000/api';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:3000/api';
    } catch (_) {}
    return 'http://localhost:3000/api';
  }

  Future doRegister() async {
    setState(() => loading = true);
    try {
      final body = {
        'phone': phoneCtl.text.trim(),
        'password': passCtl.text,
        'first_name': firstNameCtl.text.trim(),
        'last_name': lastNameCtl.text.trim(),
        'shop_name': shopCtl.text.trim()
      };
      final res = await http.post(
          Uri.parse('$apiHost/auth/register'.replaceFirst('\u007f', '')),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body)).timeout(Duration(seconds: 8));
      if (res.statusCode == 201) {
        final data = json.decode(res.body);
        final id = data['id'] is int
            ? data['id'] as int
            : (data['id'] is String ? int.tryParse(data['id']) : null);
        widget.onRegister(data['phone'], data['shop_name'], id, data['first_name'], data['last_name']);
        Navigator.of(context).pop();
      } else {
        await showDialog(
            context: context,
            builder: (c) => AlertDialog(
                  title: Text('Erreur'),
                  content: Text('Inscription échouée: ${res.statusCode}\n${res.body}'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(c).pop(),
                        child: Text('OK'))
                  ],
                ));
      }
    } catch (e) {
      await showDialog(
          context: context,
          builder: (c) => AlertDialog(
                title: Text('Erreur'),
                content: Text('Erreur inscription: $e'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(c).pop(),
                      child: Text('OK'))
                ],
              ));
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Text('Créer un compte'),
        backgroundColor: kCard,
        foregroundColor: kTextPrimary,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 400),
            child: Column(
              children: [
                // Brand Logo
                Container(
                  margin: EdgeInsets.only(bottom: 32),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: kAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.storefront_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Nouvelle Boutique',
                        style: TextStyle(
                          color: kTextPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Registration Card
                Card(
                  color: kCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: Colors.black.withOpacity(0.3),
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            'Inscription',
                            style: TextStyle(
                              color: kTextPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Créez votre espace de gestion',
                            style: TextStyle(
                              color: kTextSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        SizedBox(height: 32),

                        TextField(
                          controller: firstNameCtl,
                          style: TextStyle(color: kTextPrimary),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.2),
                            labelText: 'Prénom',
                            labelStyle: TextStyle(color: kTextSecondary),
                            prefixIcon: Icon(Icons.person_rounded, color: kTextSecondary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          ),
                        ),
                        SizedBox(height: 16),

                        TextField(
                          controller: lastNameCtl,
                          style: TextStyle(color: kTextPrimary),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.2),
                            labelText: 'Nom',
                            labelStyle: TextStyle(color: kTextSecondary),
                            prefixIcon: Icon(Icons.person_rounded, color: kTextSecondary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          ),
                        ),
                        SizedBox(height: 16),

                        TextField(
                          controller: phoneCtl,
                          style: TextStyle(color: kTextPrimary),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.2),
                            labelText: 'Numéro de téléphone',
                            labelStyle: TextStyle(color: kTextSecondary),
                            prefixIcon: Icon(Icons.phone_rounded, color: kTextSecondary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          ),
                        ),
                        SizedBox(height: 16),

                        TextField(
                          controller: passCtl,
                          obscureText: true,
                          style: TextStyle(color: kTextPrimary),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.2),
                            labelText: 'Mot de passe',
                            labelStyle: TextStyle(color: kTextSecondary),
                            prefixIcon: Icon(Icons.lock_rounded, color: kTextSecondary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          ),
                        ),
                        SizedBox(height: 16),

                        TextField(
                          controller: shopCtl,
                          style: TextStyle(color: kTextPrimary),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.2),
                            labelText: 'Nom de la boutique (optionnel)',
                            labelStyle: TextStyle(color: kTextSecondary),
                            prefixIcon: Icon(Icons.storefront_rounded, color: kTextSecondary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          ),
                        ),
                        SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: loading ? null : doRegister,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kAccent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: loading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Créer un compte',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                        SizedBox(height: 16),

                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: RichText(
                              text: TextSpan(
                                text: 'Déjà un compte ? ',
                                style: TextStyle(color: kTextSecondary),
                                children: [
                                  TextSpan(
                                    text: 'Se connecter',
                                    style: TextStyle(
                                      color: kAccent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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
    );
  }
}