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
  final _eurCtl = TextEditingController();
  final _usdCtl = TextEditingController();
  final _firstNameCtl = TextEditingController();
  final _lastNameCtl = TextEditingController();
  final _shopNameCtl = TextEditingController();
  late TextEditingController _phoneCtl;
  bool _isSavingProfile = false;
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
    _eurCtl.text = (_settings.rates['EUR'] ?? 655.957).toString();
    _usdCtl.text = (_settings.rates['USD'] ?? 606.371).toString();
    _firstNameCtl.text = _settings.firstName ?? '';
    _lastNameCtl.text = _settings.lastName ?? '';
    _shopNameCtl.text = _settings.shopName ?? '';
    _phoneCtl = TextEditingController(text: _settings.ownerPhone ?? '');
    _boutiqueModeEnabled = _settings.boutiqueModeEnabled;
    _settings.addListener(_apply);
  }

  void _apply() => setState(() {});

  @override
  void dispose() {
    _settings.removeListener(_apply);
    _eurCtl.dispose();
    _usdCtl.dispose();
    _firstNameCtl.dispose();
    _lastNameCtl.dispose();
    _shopNameCtl.dispose();
    _phoneCtl.dispose();
    super.dispose();
  }

  Future<void> _saveRates() async {
    final eur = double.tryParse(_eurCtl.text) ?? 655.957;
    final usd = double.tryParse(_usdCtl.text) ?? 606.371;

    final m = Map<String, double>.from(_settings.rates);
    m['EUR'] = eur;
    m['USD'] = usd;

    await _settings.setRates(m);

    _showMinimalSnackbar('Taux enregistrés');
  }

  Future<void> _saveProfile() async {
    if (_firstNameCtl.text.isEmpty || _lastNameCtl.text.isEmpty) {
      _showMinimalSnackbar('Le prénom et le nom sont obligatoires');
      return;
    }

    setState(() => _isSavingProfile = true);

    try {
      // Update profile in backend
      final body = {
        'phone': _settings.ownerPhone,
        'first_name': _firstNameCtl.text.trim(),
        'last_name': _lastNameCtl.text.trim(),
        'shop_name': _shopNameCtl.text.trim(),
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
        // Update local storage
        await _settings.setProfileInfo(
          _firstNameCtl.text,
          _lastNameCtl.text,
          _shopNameCtl.text,
        );

        if (mounted) {
          _showMinimalSnackbar('Profil enregistré avec succès');
        }
      } else {
        final errorMsg = res.body.isNotEmpty ? json.decode(res.body)['message'] ?? 'Erreur serveur' : 'Erreur serveur';
        if (mounted) {
          _showMinimalSnackbar('Erreur: $errorMsg');
        }
      }
    } catch (e) {
      if (mounted) {
        _showMinimalSnackbar('Erreur: $e');
      }
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  void _showMinimalSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final textColorSecondary = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? Colors.white24 : Colors.black26;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'PARAMÈTRES',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            color: textColor,
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
              // STATISTIQUES BUTTON
              if (widget.debts != null && widget.clients != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Calculate total unpaid
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.bar_chart_outlined, size: 20),
                      label: const Text(
                        'VOIR LES STATISTIQUES',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              // PROFIL SECTION
              Text(
                'PROFIL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: textColorSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor, width: 0.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INFORMATIONS PERSONNELLES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: textColorSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _firstNameCtl,
                        style: TextStyle(color: textColor, fontSize: 15),
                        decoration: InputDecoration(
                          labelText: 'Prénom',
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: textColorSecondary,
                          ),
                          border: const OutlineInputBorder(borderSide: BorderSide(width: 0.5)),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: borderColor, width: 0.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: textColor, width: 1),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _lastNameCtl,
                        style: TextStyle(color: textColor, fontSize: 15),
                        decoration: InputDecoration(
                          labelText: 'Nom',
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: textColorSecondary,
                          ),
                          border: const OutlineInputBorder(borderSide: BorderSide(width: 0.5)),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: borderColor, width: 0.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: textColor, width: 1),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _phoneCtl,
                        readOnly: true,
                        style: TextStyle(color: textColorSecondary, fontSize: 15),
                        decoration: InputDecoration(
                          labelText: 'Numéro de téléphone',
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: textColorSecondary,
                          ),
                          border: const OutlineInputBorder(borderSide: BorderSide(width: 0.5)),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: borderColor, width: 0.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: textColorSecondary, width: 1),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSavingProfile ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.white : Colors.black,
                            foregroundColor: isDark ? Colors.black : Colors.white,
                            disabledBackgroundColor: isDark ? Colors.white24 : Colors.black26,
                            disabledForegroundColor: isDark ? Colors.black38 : Colors.white54,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                          ),
                          child: _isSavingProfile
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  'ENREGISTRER LE PROFIL',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.5,
                                    color: isDark ? Colors.black : Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // 💎 MODE BOUTIQUE SECTION
              Text(
                'MODE BOUTIQUE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: textColorSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor, width: 0.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Activez le mode boutique pour accéder à la gestion complète des clients et des statistiques. Laissez-le désactivé pour une gestion simple des dettes.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: textColorSecondary,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'MODE BOUTIQUE',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                              color: textColor,
                            ),
                          ),
                          Switch(
                            value: _boutiqueModeEnabled,
                            onChanged: (val) async {
                              setState(() => _boutiqueModeEnabled = val);
                              await _settings.syncBoutiqueModeToServer(val);
                              if (mounted) {
                                _showMinimalSnackbar(
                                  val ? 'Mode boutique activé' : 'Mode boutique désactivé',
                                );
                              }
                            },
                            activeThumbColor: Colors.orange,
                            inactiveThumbColor: textColorSecondary,
                          ),
                        ],
                      ),
                      if (_boutiqueModeEnabled) ...[
                        const SizedBox(height: 20),
                        TextField(
                          controller: _shopNameCtl,
                          style: TextStyle(color: textColor, fontSize: 15),
                          decoration: InputDecoration(
                            labelText: 'Nom de la boutique',
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: textColorSecondary,
                            ),
                            border: const OutlineInputBorder(borderSide: BorderSide(width: 0.5)),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: borderColor, width: 0.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: textColor, width: 1),
                            ),
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 45,
                          child: ElevatedButton(
                            onPressed: _isSavingProfile ? null : () async {
                              await _settings.setShopName(_shopNameCtl.text.trim());
                              if (mounted) {
                                _showMinimalSnackbar('Nom de boutique enregistré');
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.withOpacity(0.1),
                              foregroundColor: Colors.orange,
                              disabledBackgroundColor: Colors.orange.withOpacity(0.05),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                                side: BorderSide(color: Colors.orange.withOpacity(0.3), width: 0.5),
                              ),
                            ),
                            child: const Text(
                              'ENREGISTRER LE NOM',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // APPARENCE SECTION
              Text(
                'APPARENCE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: textColorSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor, width: 0.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'THÈME',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: textColorSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _settings.lightMode ? 'MODE CLAIR' : 'MODE SOMBRE',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: textColor,
                            ),
                          ),
                          Switch(
                            value: _settings.lightMode,
                            onChanged: (v) => _settings.setLightMode(v),
                            activeThumbColor: isDark ? Colors.white : Colors.black,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // LANGUE SECTION
              Text(
                'LANGUE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: textColorSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor, width: 0.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LANGUE DE L\'APPLICATION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: textColorSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Actuelle : ${_settings.locale.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _languageButton('FRANÇAIS', 'fr_FR'),
                          const SizedBox(width: 12),
                          _languageButton('ENGLISH', 'en_US'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // DEVISE SECTION
              Text(
                'DEVISE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: textColorSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor, width: 0.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DEVISE PRINCIPALE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: textColorSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Actuelle : ${_settings.currency}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _currencyButton('XOF', 'XOF'),
                          const SizedBox(width: 12),
                          _currencyButton('EUR', 'EUR'),
                          const SizedBox(width: 12),
                          _currencyButton('USD', 'USD'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // TAUX DE CHANGE SECTION
              Text(
                'TAUX DE CHANGE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: textColorSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor, width: 0.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CONVERSION DE DEVISES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: textColorSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _eurCtl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: textColor, fontSize: 15),
                        decoration: InputDecoration(
                          labelText: '1 EUR = ? XOF',
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: textColorSecondary,
                          ),
                          border: const OutlineInputBorder(borderSide: BorderSide(width: 0.5)),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: borderColor, width: 0.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: textColor, width: 1),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _usdCtl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: textColor, fontSize: 15),
                        decoration: InputDecoration(
                          labelText: '1 USD = ? XOF',
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: textColorSecondary,
                          ),
                          border: const OutlineInputBorder(borderSide: BorderSide(width: 0.5)),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: borderColor, width: 0.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: textColor, width: 1),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saveRates,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.white : Colors.black,
                            foregroundColor: isDark ? Colors.black : Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                          ),
                          child: Text(
                            'ENREGISTRER LES TAUX',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                              color: isDark ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _languageButton(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final isSelected = _settings.locale == value;
    
    return Expanded(
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? textColor : Theme.of(context).dividerColor,
            width: isSelected ? 1 : 0.5,
          ),
        ),
        child: TextButton(
          onPressed: () => _settings.setLocale(value),
          style: TextButton.styleFrom(
            foregroundColor: textColor,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _currencyButton(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final isSelected = _settings.currency == value;
    
    return Expanded(
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? textColor : Theme.of(context).dividerColor,
            width: isSelected ? 1 : 0.5,
          ),
        ),
        child: TextButton(
          onPressed: () => _settings.setCurrency(value),
          style: TextButton.styleFrom(
            foregroundColor: textColor,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}