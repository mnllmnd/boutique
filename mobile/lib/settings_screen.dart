import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

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

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Taux enregistrés')));
  }

  Future<void> _saveProfile() async {
    if (_firstNameCtl.text.isEmpty || _lastNameCtl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le prénom et le nom sont obligatoires')),
      );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil enregistré avec succès')),
          );
        }
      } else {
        final errorMsg = res.body.isNotEmpty ? json.decode(res.body)['message'] ?? 'Erreur serveur' : 'Erreur serveur';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $errorMsg')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Paramètres"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [

              // ---------------------- PROFIL ----------------------------
              _sectionCard(
                title: "Votre profil",
                description: "Modifiez vos informations personnelles et votre boutique",
                child: Column(
                  children: [
                    TextField(
                      controller: _firstNameCtl,
                      decoration: InputDecoration(
                        labelText: 'Prénom',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _lastNameCtl,
                      decoration: InputDecoration(
                        labelText: 'Nom',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _shopNameCtl,
                      decoration: InputDecoration(
                        labelText: 'Nom de la boutique',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneCtl,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Numéro de téléphone',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        suffixIcon: const Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSavingProfile ? null : _saveProfile,
                        child: _isSavingProfile
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text("Enregistrer le profil"),
                      ),
                    )
                  ],
                ),
              ),

              // ---------------------- THEME ----------------------------
              _sectionCard(
                title: "Thème",
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _settings.lightMode ? "Mode clair" : "Mode sombre",
                      style: const TextStyle(fontSize: 16),
                    ),
                    Switch(
                      value: _settings.lightMode,
                      onChanged: (v) => _settings.setLightMode(v),
                    ),
                  ],
                ),
              ),

              // ---------------------- LANGUE ----------------------------
              _sectionCard(
                title: "Langue",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Actuelle : ${_settings.locale}"),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _pillButton("Français", () => _settings.setLocale("fr_FR")),
                        _pillButton("English", () => _settings.setLocale("en_US")),
                      ],
                    ),
                  ],
                ),
              ),

              // ---------------------- DEVISE ----------------------------
              _sectionCard(
                title: "Devise",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Actuelle : ${_settings.currency}"),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _pillButton("XOF (FCFA)", () => _settings.setCurrency("XOF")),
                        _pillButton("EUR (€)", () => _settings.setCurrency("EUR")),
                        _pillButton("USD (\$)", () => _settings.setCurrency("USD")),
                      ],
                    ),
                  ],
                ),
              ),

              // ---------------------- TAUX ----------------------------
              _sectionCard(
                title: "Taux de change",
                description: "Définissez les taux pour convertir les montants en autres devises",
                child: Column(
                  children: [
                    _simpleRateInput("1 EUR = ? XOF", _eurCtl),
                    const SizedBox(height: 12),
                    _simpleRateInput("1 USD = ? XOF", _usdCtl),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveRates,
                        child: const Text("Enregistrer les taux"),
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------

  Widget _sectionCard({required String title, String? description, required Widget child}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                )),
            if (description != null) ...[
              const SizedBox(height: 6),
              Text(description, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  Widget _simpleRateInput(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: "Ex: 655.957",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _pillButton(String label, VoidCallback onTap) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        shape: StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      ),
      onPressed: onTap,
      child: Text(label),
    );
  }
}
