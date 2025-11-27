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
  String? selectedCountryCode;
  List<Map<String, dynamic>> countries = [];
  bool loadingCountries = true;

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
    _loadCountries();
  }

  @override
  void dispose() {
    phoneCtl.dispose();
    pinCtl.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    try {
      final res = await http.get(
        Uri.parse('$apiHost/countries'),
      ).timeout(const Duration(seconds: 5));
      
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        setState(() {
          countries = List<Map<String, dynamic>>.from(
            data.map((item) => {
              'code': item['code'],
              'country_name': item['country_name'],
              'flag_emoji': item['flag_emoji'] ?? '',
            })
          );
          // Défaut: Sénégal (221)
          selectedCountryCode = '221';
          loadingCountries = false;
        });
      } else {
        setState(() => loadingCountries = false);
      }
    } catch (e) {
      print('[COUNTRIES] Erreur chargement: $e');
      setState(() => loadingCountries = false);
    }
  }

  Future _doQuickSignup() async {
    final phone = phoneCtl.text.trim();
    
    if (phone.isEmpty) {
      _showError('Veuillez entrer votre numéro');
      return;
    }

    if (selectedCountryCode == null) {
      _showError('Veuillez sélectionner un pays');
      return;
    }

    setState(() => loading = true);
    try {
      final normalizedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final fullPhone = '+$selectedCountryCode$normalizedPhone';
      
      final res = await http.post(
        Uri.parse('$apiHost/auth/register-quick'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': fullPhone, 'country_code': selectedCountryCode}),
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
      final normalizedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final fullPhone = '+$selectedCountryCode$normalizedPhone';
      
      final res = await http.post(
        Uri.parse('$apiHost/auth/login-phone'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': fullPhone, 'country_code': selectedCountryCode}),
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
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) => Dialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.3,
              )),
              const SizedBox(height: 16),
              Text(message, 
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  fontWeight: FontWeight.w300,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                )),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('ANNULER', style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                    )),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onConfirm();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('CONTINUER', style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                    )),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w300,
          letterSpacing: 0.2,
        )),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    );
  }

  void _showPinDialog(String phone, dynamic userId) {
    pinCtl.clear();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) => Dialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Code PIN', style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.3,
              )),
              const SizedBox(height: 8),
              Text('Entrez votre code à 4 chiffres', 
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                )),
              const SizedBox(height: 32),
              TextField(
                controller: pinCtl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32, 
                  letterSpacing: 16, 
                  fontWeight: FontWeight.w300,
                ),
                decoration: InputDecoration(
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  hintText: '••••',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                    letterSpacing: 16,
                  ),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('ANNULER', style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                    )),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _verifyPin(phone, userId);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('VÉRIFIER', style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                    )),
                  ),
                ],
              ),
            ],
          ),
        ),
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

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Minimal Header
                  Column(
                    children: [
                      Text('Borr', style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w300,
                        color: colors.onSurface,
                        letterSpacing: -1,
                        height: 1.1,
                      )),
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 1,
                        color: colors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 64),

                  // Country Selector
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pays', style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.5,
                        color: colors.onSurface.withOpacity(0.5),
                      )),
                      const SizedBox(height: 12),
                      if (loadingCountries)
                        Container(
                          width: double.infinity,
                          height: 48,
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: colors.primary,
                            ),
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          value: selectedCountryCode,
                          isExpanded: true,
                          decoration: InputDecoration(
                            border: UnderlineInputBorder(
                              borderSide: BorderSide(color: colors.outline.withOpacity(0.2)),
                            ),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: colors.outline.withOpacity(0.2)),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: colors.primary),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          items: countries.map((country) {
                            return DropdownMenuItem<String>(
                              value: country['code'],
                              child: Row(
                                children: [
                                  Text(country['flag_emoji'] ?? '', style: const TextStyle(fontSize: 18)),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${country['country_name']} (+${country['code']})',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: colors.onSurface,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => selectedCountryCode = value);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Phone Input
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Numéro de téléphone', style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.5,
                        color: colors.onSurface.withOpacity(0.5),
                      )),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneCtl,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(
                          fontSize: 16, 
                          color: colors.onSurface,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 0.5,
                        ),
                        decoration: InputDecoration(
                          hintText: '77 123 45 67',
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(color: colors.outline.withOpacity(0.2)),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: colors.outline.withOpacity(0.2)),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: colors.primary),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          hintStyle: TextStyle(
                            color: colors.onSurface.withOpacity(0.3),
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),

                  // Continue Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: loading ? null : _doQuickSignup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        disabledBackgroundColor: colors.primary.withOpacity(0.3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                      child: loading 
                          ? SizedBox(
                              width: 18, 
                              height: 18, 
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: colors.onPrimary,
                              ),
                            )
                          : Text('CONTINUER', style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 2,
                              color: colors.onPrimary,
                            )),
                    ),
                  ),
                  const SizedBox(height: 64),

                  // Benefits Section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMinimalBenefit('Accès immédiat'),
                      _buildMinimalBenefit('Gestion simplifiée'),
                      _buildMinimalBenefit('Sécurisé'),
                    ],
                  ),
                  const SizedBox(height: 48),
                  
                  // Footer
                  Text('Aucune information bancaire requise', style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                    color: colors.onSurface.withOpacity(0.3),
                    letterSpacing: 0.5,
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalBenefit(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Text(text, style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w300,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            letterSpacing: 0.3,
          )),
        ],
      ),
    );
  }
}