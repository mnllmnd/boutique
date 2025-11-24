import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'app_settings.dart';
import 'services/pin_auth_offline_service.dart';

class QuickLoginPage extends StatefulWidget {
  final void Function(String phone, String? shop, int? id, String? firstName, String? lastName, bool? boutiqueModeEnabled) onLogin;
  const QuickLoginPage({super.key, required this.onLogin});
  @override
  State<QuickLoginPage> createState() => _QuickLoginPageState();
}

class _QuickLoginPageState extends State<QuickLoginPage> {
  bool loading = false;
  late TextEditingController phoneCtl;
  late TextEditingController pinCtl;
  String? tempToken;

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
    pinCtl = TextEditingController();
  }

  @override
  void dispose() {
    phoneCtl.dispose();
    pinCtl.dispose();
    super.dispose();
  }

  Future _doQuickSignup() async {
    final phone = phoneCtl.text.trim();
    
    if (phone.isEmpty) {
      _showError('Veuillez entrer votre numéro');
      return;
    }

    setState(() => loading = true);
    try {
      final res = await http.post(
        Uri.parse('$apiHost/auth/register-quick'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': phone}),
      ).timeout(const Duration(seconds: 8));
      
      if (res.statusCode == 201) {
        final data = json.decode(res.body);
        final id = data['id'] is int ? data['id'] as int : (data['id'] is String ? int.tryParse(data['id']) : null);
        
        if (data['auth_token'] != null) {
          final settings = AppSettings();
          await settings.initForOwner(data['phone']);
          await settings.setAuthToken(data['auth_token']);
          if (data['boutique_mode_enabled'] != null) {
            await settings.setBoutiqueModeEnabled(data['boutique_mode_enabled'] as bool);
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
        
        widget.onLogin(data['phone'], data['shop_name'], id, data['first_name'], data['last_name'], data['boutique_mode_enabled'] as bool?);
      } else if (res.statusCode == 409) {
        setState(() => loading = false);
        _showConfirmDialog(
          'Numéro existant',
          'Ce numéro est déjà inscrit. Voulez-vous vous connecter ?',
          onConfirm: () => _attemptAutoLogin(phone),
        );
      } else {
        setState(() => loading = false);
        _showError('Inscription échouée: ${res.statusCode}');
      }
    } catch (e) {
      setState(() => loading = false);
      _showError('Erreur connexion: $e');
    }
  }

  Future<void> _attemptAutoLogin(String phone) async {
    setState(() => loading = true);
    try {
      final res = await http.post(
        Uri.parse('$apiHost/auth/login-phone'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': phone}),
      ).timeout(const Duration(seconds: 8));
      
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final id = data['id'] is int ? data['id'] as int : (data['id'] is String ? int.tryParse(data['id']) : null);
        
        if (data['pin_required'] == true) {
          setState(() {
            loading = false;
            tempToken = data['temp_token'];
          });
          _showPinDialog(phone, data['id']);
          return;
        }
        
        if (data['auth_token'] != null) {
          final settings = AppSettings();
          await settings.initForOwner(data['phone']);
          await settings.setAuthToken(data['auth_token']);
          if (data['boutique_mode_enabled'] != null) {
            await settings.setBoutiqueModeEnabled(data['boutique_mode_enabled'] as bool);
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
        
        widget.onLogin(data['phone'], data['shop_name'], id, data['first_name'], data['last_name'], data['boutique_mode_enabled'] as bool?);
      } else if (res.statusCode == 404) {
        setState(() => loading = false);
        _showError('Ce numéro n\'existe pas');
      } else {
        setState(() => loading = false);
        _showError('Erreur connexion: ${res.statusCode}');
      }
    } catch (e) {
      setState(() => loading = false);
      _showError('Erreur lors de la connexion: $e');
    }
  }

  void _showConfirmDialog(String title, String message, {required VoidCallback onConfirm}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title, style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        )),
        content: Text(message, style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Annuler', style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            )),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('Se connecter'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showPinDialog(String phone, dynamic userId) {
    pinCtl.clear();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Icon(Icons.lock_outline, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text('Vérification PIN', style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            )),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Entrez votre code PIN', style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            )),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                hintText: '••••',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Annuler', style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            )),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _verifyPin(phone, userId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('Vérifier'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyPin(String phone, dynamic userId) async {
    final pin = pinCtl.text.trim();
    
    if (pin.isEmpty) {
      _showError('Veuillez entrer votre PIN');
      _showPinDialog(phone, userId);
      return;
    }

    setState(() => loading = true);
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (tempToken != null) 'Authorization': 'Bearer $tempToken',
      };
      
      final res = await http.post(
        Uri.parse('$apiHost/auth/login-pin'),
        headers: headers,
        body: json.encode({'pin': pin}),
      ).timeout(const Duration(seconds: 8));
      
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final id = data['id'] is int ? data['id'] as int : (data['id'] is String ? int.tryParse(data['id']) : null);
        
        if (data['auth_token'] != null) {
          final settings = AppSettings();
          await settings.initForOwner(data['phone']);
          await settings.setAuthToken(data['auth_token']);
          if (data['boutique_mode_enabled'] != null) {
            await settings.setBoutiqueModeEnabled(data['boutique_mode_enabled'] as bool);
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
        
        widget.onLogin(data['phone'], data['shop_name'], id, data['first_name'], data['last_name'], data['boutique_mode_enabled'] as bool?);
      } else if (res.statusCode == 401) {
        setState(() => loading = false);
        _showError('PIN incorrect');
        _showPinDialog(phone, userId);
      } else {
        setState(() => loading = false);
        _showError('Erreur vérification PIN: ${res.statusCode}');
        _showPinDialog(phone, userId);
      }
    } catch (e) {
      setState(() => loading = false);
      _showError('Erreur lors de la vérification: $e');
      _showPinDialog(phone, userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 12),
                
                // Header
                Icon(Icons.account_balance_wallet, size: 48, color: colors.primary),
                const SizedBox(height: 12),
                Text('Gestion de Dettes', style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors.onBackground,
                )),
                const SizedBox(height: 4),
                Text('Inscription rapide', style: TextStyle(
                  fontSize: 14,
                  color: colors.onBackground.withOpacity(0.6),
                )),
                const SizedBox(height: 28),

                // Phone Input
                TextField(
                  controller: phoneCtl,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(fontSize: 16, color: colors.onBackground),
                  decoration: InputDecoration(
                    labelText: 'Numéro de téléphone',
                    hintText: '77 123 45 67',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: loading ? null : _doQuickSignup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      disabledBackgroundColor: colors.primary.withOpacity(0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: loading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text('Continuer', style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colors.onPrimary,
                          )),
                  ),
                ),
                const SizedBox(height: 16),

                // Benefits
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.outline.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBenefit('✓ Accès immédiat à l\'app'),
                      _buildBenefit('✓ Créer dettes et clients'),
                      _buildBenefit('✓ Profil complétable plus tard'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBenefit(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(text, style: TextStyle(
        fontSize: 13,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
      )),
    );
  }
}