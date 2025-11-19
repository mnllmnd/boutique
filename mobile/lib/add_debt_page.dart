import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'data/audio_service.dart';

class AddDebtPage extends StatefulWidget {
  final String ownerPhone;
  final List clients;
  final int? preselectedClientId;

  const AddDebtPage({super.key, required this.ownerPhone, required this.clients, this.preselectedClientId});

  @override
  _AddDebtPageState createState() => _AddDebtPageState();
}

class _AddDebtPageState extends State<AddDebtPage> {
  final _formKey = GlobalKey<FormState>();
  int? _clientId;
  final TextEditingController _amountCtl = TextEditingController();
  final TextEditingController _notesCtl = TextEditingController();
  DateTime? _due;
  bool _saving = false;
  late AudioService _audioService;
  String? _audioPath;
  bool _isRecording = false;

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
    _audioService = AudioService();
    
    // Validate that preselected client exists in the list
    int? validClientId;
    if (widget.preselectedClientId != null && widget.clients.isNotEmpty) {
      final exists = widget.clients.any((c) => c['id'] == widget.preselectedClientId);
      if (exists) {
        validClientId = widget.preselectedClientId;
      }
    }
    
    _clientId = validClientId ?? (widget.clients.isNotEmpty ? widget.clients.first['id'] : null);
  }

  @override
  void dispose() {
    _audioService.dispose();
    _amountCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _createClientInline() async {
    final numberCtl = TextEditingController();
    final nameCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Ajouter un client'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Nom')),
          TextField(controller: numberCtl, decoration: const InputDecoration(labelText: 'Numéro (optionnel)')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Annuler')), ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Ajouter'))],
      ),
    );

    if (ok == true && nameCtl.text.trim().isNotEmpty) {
      try {
        final body = {'client_number': numberCtl.text.trim(), 'name': nameCtl.text.trim()};
        final headers = {'Content-Type': 'application/json', if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone};
        setState(() => _saving = true);
        final res = await http.post(Uri.parse('$apiHost/clients'), headers: headers, body: json.encode(body)).timeout(const Duration(seconds: 8));
        if (res.statusCode == 201) {
            try {
            final created = json.decode(res.body);
            setState(() {
              // insert created client at the top so it's visible, avoid duplicates by id
              if (created is Map && created['id'] != null) {
                final createdId = created['id'].toString();
                final exists = widget.clients.indexWhere((c) => c['id']?.toString() == createdId);
                if (exists == -1) {
                  widget.clients.insert(0, created);
                } else {
                  widget.clients[exists] = created; // update existing
                }
                _clientId = created['id'];
              }
            });
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Client ajouté')));
          } catch (_) {
            // fallback: reload clients from parent won't happen here; just inform user
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Client ajouté')));
          }
        } else {
          final bodyText = res.body;
          final lower = bodyText.toLowerCase();
          final isDuplicate = res.statusCode == 409 || lower.contains('duplicate') || lower.contains('already exists') || lower.contains('unique');
          // If server indicates duplicate OR even if it fails with a DB error, try to find existing by number
          if (numberCtl.text.trim().isNotEmpty) {
            try {
              final headersGet = {'Content-Type': 'application/json', if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone};
              final getRes = await http.get(Uri.parse('$apiHost/clients'), headers: headersGet).timeout(const Duration(seconds: 8));
              if (getRes.statusCode == 200) {
                final list = json.decode(getRes.body) as List;
                final found = list.firstWhere((c) => (c['client_number'] ?? '').toString() == numberCtl.text.trim(), orElse: () => null);
                if (found != null) {
                  // Show clear message that the user exists and offer to select
                  final choose = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                            title: const Text('Utilisateur existant'),
                            content: Text('Un utilisateur existe déjà avec ce numéro (${found['name']}). Voulez-vous le sélectionner ?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Non')),
                              ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Oui'))
                            ],
                          ));
                  if (choose == true) {
                    setState(() {
                      final foundId = found['id']?.toString();
                      final existsIndex = widget.clients.indexWhere((c) => c['id']?.toString() == foundId);
                      if (existsIndex == -1) {
                        widget.clients.insert(0, found);
                      } else {
                        widget.clients[existsIndex] = found;
                      }
                      _clientId = found['id'];
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Client sélectionné : ${found['name']}')));
                    return;
                  } else {
                    // user chose not to select existing; if server returned duplicate, show friendly message
                    if (isDuplicate) {
                      await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Info'), content: const Text('Cet utilisateur existe.'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))]));
                      return;
                    }
                  }
                }
              }
            } catch (_) {}
          }
          await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Erreur'), content: Text('Échec création client: ${res.statusCode}\n${res.body}'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))]));
        }
      } catch (e) {
        await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Erreur'), content: Text('Erreur création client: $e'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))]));
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
  }

  Future<void> _pickDue() async {
    final d = await showDatePicker(context: context, initialDate: _due ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (d != null) setState(() => _due = d);
  }

  Future<void> _startRecording() async {
    final ok = await _audioService.startRecording();
    if (ok) {
      setState(() => _isRecording = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enregistrement en cours...')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible de démarrer l\'enregistrement')));
    }
  }

  Future<void> _stopRecording() async {
    final path = await _audioService.stopRecording();
    if (path != null) {
      setState(() {
        _isRecording = false;
        _audioPath = path;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enregistrement sauvegardé')));
    } else {
      setState(() => _isRecording = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de l\'enregistrement')));
    }
  }

  Future<void> _playAudio() async {
    if (_audioPath != null) {
      await _audioService.playAudio(_audioPath!);
    }
  }

  Future<void> _deleteAudio() async {
    if (_audioPath != null) {
      await _audioService.deleteAudio(_audioPath!);
      setState(() => _audioPath = null);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enregistrement supprimé')));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_clientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez choisir un client')));
      return;
    }
    setState(() => _saving = true);
    try {
      final body = {
        'client_id': _clientId,
        'amount': double.tryParse(_amountCtl.text.replaceAll(',', '')) ?? 0.0,
        'due_date': _due == null ? null : DateFormat('yyyy-MM-dd').format(_due!),
        'notes': _notesCtl.text,
        if (_audioPath != null) 'audio_path': _audioPath,
      };
      final headers = {'Content-Type': 'application/json', if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone};
      final res = await http.post(Uri.parse('$apiHost/debts'), headers: headers, body: json.encode(body)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 201) {
        Navigator.of(context).pop(true);
      } else {
        await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Erreur'), content: Text('Échec création dette: ${res.statusCode}\n${res.body}'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))]));
      }
    } catch (e) {
      await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Erreur'), content: Text('Erreur création dette: $e'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))]));
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
        title: const Text('Ajouter une dette', style: TextStyle(fontWeight: FontWeight.w700)),
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
                      // Client selector
                      Text('Client', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: _clientId,
                              isExpanded: true,
                              items: widget.clients.map<DropdownMenuItem<int>>((cl) {
                                final clientNumber = (cl['client_number'] ?? '').toString().isNotEmpty ? ' (${cl['client_number']})' : '';
                                return DropdownMenuItem(
                                  value: cl['id'],
                                  child: Text('${cl['name'] ?? 'Client'}$clientNumber'),
                                );
                              }).toList(),
                              onChanged: (v) => setState(() => _clientId = v),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Theme.of(context).inputDecorationTheme.fillColor ?? Theme.of(context).scaffoldBackgroundColor,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _saving ? null : _createClientInline,
                              icon: Icon(Icons.person_add, size: 18, color: Theme.of(context).elevatedButtonTheme.style?.foregroundColor?.resolve({}) ?? Colors.white),
                              label: Text('', style: TextStyle(color: Theme.of(context).elevatedButtonTheme.style?.foregroundColor?.resolve({}) ?? Colors.white)),
                              style: ElevatedButton.styleFrom(backgroundColor: accent, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Amount field (large)
                      Text('Montant', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _amountCtl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Theme.of(context).textTheme.displayLarge?.color),
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3), fontSize: 28),
                          filled: true,
                          fillColor: Theme.of(context).inputDecorationTheme.fillColor ?? Theme.of(context).scaffoldBackgroundColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Entrez un montant' : null,
                        autofocus: true,
                      ),
                      const SizedBox(height: 14),

                      // Due date & quick info
                      Row(
                        children: [
                          Expanded(child: Text(_due == null ? 'Date Échéance : Aucune' : 'Date Échéance : ${DateFormat('dd/MM/yyyy').format(_due!)}', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color))),
                          TextButton(onPressed: _pickDue, child: Text('Choisir', style: TextStyle(color: accent)))
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Audio Recording
                      Text('Enregistrement audio (optionnel)', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).inputDecorationTheme.fillColor ?? Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            if (_audioPath == null)
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(_isRecording ? '🔴 Enregistrement en cours...' : '🎤 Pas d\'enregistrement', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
                                  ),
                                  ElevatedButton(
                                    onPressed: _saving ? null : (_isRecording ? _stopRecording : _startRecording),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isRecording ? Colors.red : accent,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: Text(_isRecording ? 'Arrêter' : 'Démarrer', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black)),
                                  ),
                                ],
                              )
                            else
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text('✅ Enregistrement sauvegardé', style: TextStyle(color: Colors.green)),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: _saving ? null : _playAudio,
                                    icon: const Icon(Icons.play_arrow, size: 16),
                                    label: const Text('Écouter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: accent,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                    onPressed: _saving ? null : _deleteAudio,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Notes
                      Text('Notes (optionnel)', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _notesCtl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Ex: 1 kg de sucre',
                          filled: true,
                          fillColor: Theme.of(context).inputDecorationTheme.fillColor ?? Theme.of(context).scaffoldBackgroundColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),

                      const SizedBox(height: 20),
                      Divider(color: Theme.of(context).dividerColor),

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
                                  : const Text('Enregistrer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
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
}
