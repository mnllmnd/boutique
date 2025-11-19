import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

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

  String get apiHost {
    if (kIsWeb) return 'http://localhost:3000/api';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:3000/api';
    } catch (_) {}
    return 'http://localhost:3000/api';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final body = {
        'name': _nameCtl.text.trim(),
        'client_number': _numberCtl.text.trim(),
      };
      final headers = {'Content-Type': 'application/json', if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone};
      final res = await http.post(Uri.parse('$apiHost/clients'), headers: headers, body: json.encode(body)).timeout(const Duration(seconds: 8));

      if (res.statusCode == 201) {
        try {
          final created = json.decode(res.body);
          Navigator.of(context).pop(created);
        } catch (_) {
          Navigator.of(context).pop(true);
        }
      } else {
        final bodyText = res.body;
        final lower = bodyText.toLowerCase();
        final isDuplicate = res.statusCode == 409 || lower.contains('duplicate') || lower.contains('already exists') || lower.contains('unique');

        if (isDuplicate) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Client existant'),
              content: const Text('Un client avec ce numéro existe déjà.'),
              actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
            ),
          );
        } else {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Erreur'),
              content: Text('Échec création client: ${res.statusCode}\n${res.body}'),
              actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
            ),
          );
        }
      }
    } catch (e) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Erreur'),
          content: Text('Erreur création client: $e'),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final cardColor = Theme.of(context).cardColor;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: const Text('Ajouter un client', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Card(
                color: cardColor,
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name field
                        Text('Nom du client', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameCtl,
                          style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.displayLarge?.color),
                          decoration: InputDecoration(
                            hintText: 'Ex: Lamine Diallo',
                            hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3)),
                            filled: true,
                            fillColor: Theme.of(context).inputDecorationTheme.fillColor ?? Theme.of(context).scaffoldBackgroundColor,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Entrez un nom' : null,
                          autofocus: true,
                        ),
                        const SizedBox(height: 16),

                        // Phone number field
                        Text('Numéro de téléphone (optionnel)', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _numberCtl,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.displayLarge?.color),
                          decoration: InputDecoration(
                            hintText: 'Ex: 77 123 45 67',
                            hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3)),
                            filled: true,
                            fillColor: Theme.of(context).inputDecorationTheme.fillColor ?? Theme.of(context).scaffoldBackgroundColor,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Actions
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _saving ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accent,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: _saving
                                    ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary, strokeWidth: 2))
                                    : const Text('Créer le client', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                            child: Text('Annuler', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
