import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:boutique_mobile/config/api_config.dart';

class AddClientPage extends StatefulWidget {
  final String ownerPhone;

  const AddClientPage({super.key, required this.ownerPhone});

  @override
  _AddClientPageState createState() => _AddClientPageState();
}

class _AddClientPageState extends State<AddClientPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtl = TextEditingController();
  final TextEditingController _numberCtl = TextEditingController();
  bool _saving = false;
  String? selectedCountryCode;
  List<Map<String, dynamic>> countries = [];
  bool loadingCountries = true;

  @override
  void initState() {
    super.initState();
    _loadCountries();
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
          // ❌ PAS DE DÉFAUT - Laisser null pour que l'utilisateur choisisse
          selectedCountryCode = null;
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

  String get apiHost => ApiConfig.getBaseUrl();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // ✅ PAS d'obligation de sélectionner un pays
    setState(() => _saving = true);
    try {
      final phoneNumber = _numberCtl.text.trim();
      final normalizedPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      
      // ✅ Construire le body conditionnellement
      final body = {
        'name': _nameCtl.text.trim(),
        // ✅ Envoyer client_number SEULEMENT si l'utilisateur a saisi un numéro
        if (phoneNumber.isNotEmpty) 'client_number': phoneNumber,
        // ✅ Envoyer country_code SEULEMENT si l'utilisateur a choisi un pays
        if (selectedCountryCode != null) 'country_code': selectedCountryCode,
      };
      
      final headers = {
        'Content-Type': 'application/json', 
        if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone
      };
      final res = await http.post(
        Uri.parse('$apiHost/clients'), 
        headers: headers, 
        body: json.encode(body)
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 201) {
        _showMinimalSnackbar('Client créé');
        try {
          final created = json.decode(res.body);
          Navigator.of(context).pop(created);
        } catch (_) {
          Navigator.of(context).pop(true);
        }
      } else {
        final bodyText = res.body;
        final lower = bodyText.toLowerCase();
        
        // ✅ Essayer de parser l'erreur JSON du backend
        String errorMessage = 'Erreur lors de la création du client';
        try {
          final errorJson = json.decode(bodyText);
          if (errorJson['error'] != null) {
            errorMessage = errorJson['error'].toString();
          }
        } catch (_) {
          // Si pas du JSON, utiliser le texte brut
          if (bodyText.isNotEmpty && bodyText.length < 200) {
            errorMessage = bodyText;
          }
        }
        
        final isDuplicate = res.statusCode == 409 || 
            lower.contains('duplicate') || 
            lower.contains('already exists') || 
            lower.contains('unique') ||
            lower.contains('existe');

        await _showMinimalDialog(errorMessage);
      }
    } catch (e) {
      await _showMinimalDialog('Erreur réseau');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showMinimalDialog(String message) {
    return showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        contentPadding: const EdgeInsets.all(32),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message, 
              style: TextStyle(
                fontSize: 14, 
                fontWeight: FontWeight.w300, 
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                  foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                ),
                child: Text(
                  'OK', 
                  style: TextStyle(
                    fontSize: 11, 
                    fontWeight: FontWeight.w600, 
                    letterSpacing: 1, 
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
            color: Colors.white
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
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final textColorSecondary = isDark ? Colors.white70 : Colors.black54;
    final textColorTertiary = isDark ? Colors.white38 : Colors.black38;
    final textColorHint = isDark ? Colors.white12 : Colors.black12;
    final borderColor = isDark ? Colors.white24 : Colors.black26;
    
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor, size: 24),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text(
          'NOUVEAU CLIENT',
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
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name Section
                          Text(
                            'NOM DU CLIENT', 
                            style: TextStyle(
                              fontSize: 11, 
                              fontWeight: FontWeight.w600, 
                              letterSpacing: 1.5, 
                              color: textColorSecondary
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _nameCtl,
                            autofocus: true,
                            style: TextStyle(
                              fontSize: 15, 
                              fontWeight: FontWeight.w400, 
                              color: textColor
                            ),
                            decoration: InputDecoration(
                              hintText: 'Ex: Lamine Diallo',
                              hintStyle: TextStyle(
                                fontSize: 14, 
                                fontWeight: FontWeight.w300, 
                                color: borderColor
                              ),
                              border: const OutlineInputBorder(borderSide: BorderSide(width: 0.5)),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: borderColor, width: 0.5)
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: textColor, width: 1)
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                          ),

                          const SizedBox(height: 48),

                          // Country Selector
                          Text(
                            'PAYS', 
                            style: TextStyle(
                              fontSize: 11, 
                              fontWeight: FontWeight.w600, 
                              letterSpacing: 1.5, 
                              color: textColorSecondary
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (loadingCountries)
                            Container(
                              height: 56,
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
                            DropdownButtonFormField<String?>(
                              initialValue: selectedCountryCode,
                              isExpanded: true,
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(borderSide: BorderSide(width: 0.5)),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: borderColor, width: 0.5)
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: textColor, width: 1)
                                ),
                                contentPadding: const EdgeInsets.all(16),
                              ),
                              items: [
                                DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(
                                    'Aucun (optionnel)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: textColorSecondary,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                                // ✅ Sénégal en premier pour accès rapide
                                ...countries.where((c) => c['code'] == '221').map((country) {
                                  return DropdownMenuItem<String?>(
                                    value: country['code'],
                                    child: Row(
                                      children: [
                                        Text(country['flag_emoji'] ?? '', style: const TextStyle(fontSize: 18)),
                                        const SizedBox(width: 12),
                                        Text(
                                          '${country['country_name']} (+${country['code']})',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: textColor,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                // ✅ Autres pays
                                ...countries.where((c) => c['code'] != '221').map((country) {
                                  return DropdownMenuItem<String?>(
                                    value: country['code'],
                                    child: Row(
                                      children: [
                                        Text(country['flag_emoji'] ?? '', style: const TextStyle(fontSize: 18)),
                                        const SizedBox(width: 12),
                                        Text(
                                          '${country['country_name']} (+${country['code']})',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: textColor,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                              onChanged: (value) {
                                setState(() => selectedCountryCode = value);
                              },
                            ),

                          const SizedBox(height: 48),

                          // Phone Number Section
                          Text(
                            'NUMÉRO DE TÉLÉPHONE (OPTIONNEL)', 
                            style: TextStyle(
                              fontSize: 11, 
                              fontWeight: FontWeight.w600, 
                              letterSpacing: 1.5, 
                              color: textColorSecondary
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _numberCtl,
                            keyboardType: TextInputType.phone,
                            style: TextStyle(
                              fontSize: 15, 
                              fontWeight: FontWeight.w400, 
                              color: textColor
                            ),
                            decoration: InputDecoration(
                              hintText: 'Ex: 77 123 45 67',
                              hintStyle: TextStyle(
                                fontSize: 14, 
                                fontWeight: FontWeight.w300, 
                                color: borderColor
                              ),
                              border: const OutlineInputBorder(borderSide: BorderSide(width: 0.5)),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: borderColor, width: 0.5)
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: textColor, width: 1)
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                          ),

                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Fixed Bottom Button
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? Colors.white12 : Colors.black12, 
                      width: 0.5
                    ),
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.white : Colors.black,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          disabledBackgroundColor: isDark ? Colors.white24 : Colors.black26,
                          disabledForegroundColor: isDark ? Colors.black38 : Colors.white54,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'CRÉER LE CLIENT',
                                style: TextStyle(
                                  fontSize: 12, 
                                  fontWeight: FontWeight.w600, 
                                  letterSpacing: 1.5
                                ),
                              ),
                      ),
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
  void dispose() {
    _nameCtl.dispose();
    _numberCtl.dispose();
    super.dispose();
  }
}