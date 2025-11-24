import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'app_settings.dart';
import 'stats_screen.dart';

class SettingsScreen extends StatefulWidget {
  final List? debts;
  final List? clients;

  const SettingsScreen({
    super.key,
    this.debts,
    this.clients,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppSettings _settings = AppSettings();
  bool _boutiqueModeEnabled = false;

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
    _boutiqueModeEnabled = _settings.boutiqueModeEnabled;
    _settings.addListener(_apply);
  }

  void _apply() => setState(() {});

  @override
  void dispose() {
    _settings.removeListener(_apply);
    super.dispose();
  }

  void _showMinimalSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showProfileSheet() {
    final colors = Theme.of(context).colorScheme;
    
    final firstNameCtl = TextEditingController(text: _settings.firstName ?? '');
    final lastNameCtl = TextEditingController(text: _settings.lastName ?? '');
    final shopNameCtl = TextEditingController(text: _settings.shopName ?? '');
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Profil',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            
            TextField(
              controller: firstNameCtl,
              decoration: InputDecoration(
                labelText: 'Prénom',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            
            TextField(
              controller: lastNameCtl,
              decoration: InputDecoration(
                labelText: 'Nom',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            
            TextField(
              controller: shopNameCtl,
              decoration: InputDecoration(
                labelText: 'Boutique (optionnel)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : () async {
                  setState(() => isLoading = true);
                  await _saveProfile(firstNameCtl.text, lastNameCtl.text, shopNameCtl.text);
                  setState(() => isLoading = false);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Enregistrer'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile(String firstName, String lastName, String shopName) async {
    if (firstName.isEmpty || lastName.isEmpty) {
      _showMinimalSnackbar('Le prénom et le nom sont obligatoires');
      return;
    }

    try {
      final body = {
        'phone': _settings.ownerPhone,
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'shop_name': shopName.trim(),
      };
      
      final headers = {
        'Content-Type': 'application/json',
        if (_settings.ownerPhone != null) 'x-owner': _settings.ownerPhone!,
      };
      
      final res = await http.patch(
        Uri.parse('$apiHost/auth/profile'),
        headers: headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        await _settings.setProfileInfo(firstName, lastName, shopName);
        _showMinimalSnackbar('Profil enregistré avec succès');
      } else {
        _showMinimalSnackbar('Erreur lors de l\'enregistrement');
      }
    } catch (e) {
      _showMinimalSnackbar('Erreur: $e');
    }
  }

  void _showPinSheet() {
    final colors = Theme.of(context).colorScheme;
    final pinCtl = TextEditingController();
    bool showPin = false;
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.onSurface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Configurer le PIN',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Définissez un code PIN à 4 chiffres pour sécuriser votre compte',
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 24),
                
                TextField(
                  controller: pinCtl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: !showPin,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(16),
                    counterText: '',
                    suffixIcon: IconButton(
                      icon: Icon(
                        showPin ? Icons.visibility : Icons.visibility_off,
                        color: colors.onSurface.withOpacity(0.6),
                      ),
                      onPressed: () {
                        setDialogState(() => showPin = !showPin);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : () async {
                      if (pinCtl.text.length != 4 || !RegExp(r'^\d+$').hasMatch(pinCtl.text)) {
                        _showMinimalSnackbar('Le PIN doit contenir exactement 4 chiffres');
                        return;
                      }
                      
                      setDialogState(() => isLoading = true);
                      await _updatePin(pinCtl.text);
                      setDialogState(() => isLoading = false);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Définir le PIN'),
                  ),
                ),
                const SizedBox(height: 12),
                
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _updatePin(String pin) async {
    try {
      final body = {
        'auth_token': _settings.authToken,
        'pin': pin,
      };

      final res = await http.patch(
        Uri.parse('$apiHost/auth/update-pin'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        _showMinimalSnackbar('PIN défini avec succès');
      } else {
        _showMinimalSnackbar('Erreur lors de la définition du PIN');
      }
    } catch (e) {
      _showMinimalSnackbar('Erreur: $e');
    }
  }

  void _showCurrencySheet() {
    final colors = Theme.of(context).colorScheme;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Devise principale',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            
            _currencyOption('XOF', 'XOF'),
            _currencyOption('EUR', 'EUR'),
            _currencyOption('USD', 'USD'),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _currencyOption(String label, String value) {
    final colors = Theme.of(context).colorScheme;
    final isSelected = _settings.currency == value;
    
    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? colors.primary : colors.onSurface.withOpacity(0.5),
      ),
      title: Text(label, style: TextStyle(color: colors.onSurface)),
      onTap: () {
        _settings.setCurrency(value);
        Navigator.pop(context);
        _showMinimalSnackbar('Devise définie: $label');
      },
    );
  }

  void _showAppearanceSheet() {
    final colors = Theme.of(context).colorScheme;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Apparence',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            
            // Thème
            ListTile(
              leading: Icon(Icons.brightness_6, color: colors.onSurface),
              title: Text('Mode sombre', style: TextStyle(color: colors.onSurface)),
              trailing: Switch(
                value: !_settings.lightMode,
                onChanged: (v) {
                  _settings.setLightMode(!v);
                  setState(() {});
                },
              ),
            ),
            
            // Langue
            ListTile(
              leading: Icon(Icons.language, color: colors.onSurface),
              title: Text('Langue', style: TextStyle(color: colors.onSurface)),
              subtitle: Text(
                _settings.locale == 'fr_FR' ? 'Français' : 'English',
                style: TextStyle(color: colors.onSurface.withOpacity(0.6))
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showLanguageSheet();
              },
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showLanguageSheet() {
    final colors = Theme.of(context).colorScheme;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Langue',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            
            _languageOption('Français', 'fr_FR'),
            _languageOption('English', 'en_US'),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _languageOption(String label, String value) {
    final colors = Theme.of(context).colorScheme;
    final isSelected = _settings.locale == value;
    
    return ListTile(
      leading: Icon(
        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
        color: isSelected ? colors.primary : colors.onSurface.withOpacity(0.5),
      ),
      title: Text(label, style: TextStyle(color: colors.onSurface)),
      onTap: () {
        _settings.setLocale(value);
        Navigator.pop(context);
        _showMinimalSnackbar('Langue définie: $label');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasIncompleteProfile = _settings.firstName?.isEmpty == true || _settings.lastName?.isEmpty == true;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.close, color: colors.onBackground, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Paramètres',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colors.onBackground,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bannière de profil incomplet
              if (hasIncompleteProfile)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Complétez votre profil',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ajoutez votre nom pour personnaliser votre compte',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // STATISTIQUES BUTTON
              if (widget.debts != null && widget.clients != null)
                _SettingsCard(
                  title: 'Statistiques',
                  subtitle: 'Analyse détaillée de vos données',
                  icon: Icons.bar_chart_outlined,
                  color: Colors.orange,
                  onTap: () {
                    double totalUnpaid = 0;
                    for (final d in widget.debts!) {
                      final amt = double.tryParse(d['amount']?.toString() ?? '0') ?? 0.0;
                      double rem = amt;
                      try {
                        if (d != null && d['remaining'] != null) {
                          rem = double.tryParse(d['remaining'].toString()) ?? rem;
                        } else if (d != null && d['total_paid'] != null) {
                          rem = amt - (double.tryParse(d['total_paid'].toString()) ?? 0.0);
                        }
                      } catch (_) {}
                      if (rem > 0) totalUnpaid += rem;
                    }

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StatsScreen(
                          debts: widget.debts!,
                          clients: widget.clients!,
                          totalUnpaid: totalUnpaid,
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 12),

              // PROFIL SECTION
              _SettingsCard(
                title: 'Profil',
                subtitle: _settings.firstName?.isNotEmpty == true 
                    ? '${_settings.firstName} ${_settings.lastName}' 
                    : 'Compléter votre profil',
                icon: Icons.person_outline,
                color: colors.primary,
                onTap: _showProfileSheet,
              ),

              const SizedBox(height: 12),

              // SÉCURITÉ (PIN)
              _SettingsCard(
                title: 'Sécurité',
                subtitle: 'Configurer le code PIN',
                icon: Icons.lock_outline,
                color: Colors.red,
                onTap: _showPinSheet,
              ),

              const SizedBox(height: 12),

              // BOUTIQUE MODE
              _SettingsCard(
                title: 'Mode boutique',
                subtitle: _boutiqueModeEnabled ? 'Activé - Gestion complète' : 'Désactivé - Gestion simple',
                icon: Icons.storefront,
                color: Colors.orange,
                trailing: Switch(
                  value: _boutiqueModeEnabled,
                  onChanged: (val) async {
                    setState(() => _boutiqueModeEnabled = val);
                    await _settings.syncBoutiqueModeToServer(val);
                    _showMinimalSnackbar(
                      val ? 'Mode boutique activé' : 'Mode boutique désactivé',
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // APPARENCE
              _SettingsCard(
                title: 'Apparence',
                subtitle: 'Thème, langue, personnalisation',
                icon: Icons.palette_outlined,
                color: Colors.purple,
                onTap: _showAppearanceSheet,
              ),

              const SizedBox(height: 12),

              // DEVISE
              _SettingsCard(
                title: 'Devise',
                subtitle: _settings.currency,
                icon: Icons.currency_exchange,
                color: Colors.green,
                onTap: _showCurrencySheet,
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    
    return Card(
      color: colors.surface,
      elevation: 1,
      shadowColor: colors.shadow.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: colors.onSurface.withOpacity(0.6),
          ),
        ),
        trailing: trailing ?? Icon(
          Icons.chevron_right, 
          color: colors.onSurface.withOpacity(0.4),
          size: 20,
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}