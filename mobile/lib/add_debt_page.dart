import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'data/audio_service.dart';

class AddDebtPage extends StatefulWidget {
  final String ownerPhone;
  final List clients;
  final int? preselectedClientId;

  const AddDebtPage({super.key, required this.ownerPhone, required this.clients, this.preselectedClientId});

  @override
  _AddDebtPageState createState() => _AddDebtPageState();
}

class _AddDebtPageState extends State<AddDebtPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  int? _clientId;
  final TextEditingController _amountCtl = TextEditingController();
  final TextEditingController _notesCtl = TextEditingController();
  DateTime? _due;
  bool _saving = false;
  late AudioService _audioService;
  String? _audioPath;
  bool _isRecording = false;
  late AnimationController _pulseController;
  late AnimationController _amountAnimationCtl;
  final List<double> _recentAmounts = [];
  double _displayAmount = 0.0;

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
    _initializeDateFormatting();
    _audioService = AudioService();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _amountAnimationCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _amountCtl.addListener(_updateDisplayAmount);
    
    int? validClientId;
    if (widget.preselectedClientId != null && widget.clients.isNotEmpty) {
      final exists = widget.clients.any((c) => c['id'] == widget.preselectedClientId);
      if (exists) {
        validClientId = widget.preselectedClientId;
      }
    }
    
    _clientId = validClientId ?? (widget.clients.isNotEmpty ? widget.clients.first['id'] : null);
  }
  
  void _updateDisplayAmount() {
    final newAmount = double.tryParse(_amountCtl.text.replaceAll(',', '')) ?? 0.0;
    if (newAmount != _displayAmount) {
      _amountAnimationCtl.forward(from: 0.0);
      setState(() {
        _displayAmount = newAmount;
        if (newAmount > 0 && !_recentAmounts.contains(newAmount)) {
          _recentAmounts.insert(0, newAmount);
          if (_recentAmounts.length > 3) {
            _recentAmounts.removeLast();
          }
        }
      });
    }
  }

  Future<void> _initializeDateFormatting() async {
    try {
      await initializeDateFormatting('fr_FR', null);
    } catch (_) {
      // Ignore si déjà initialisé
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _amountAnimationCtl.dispose();
    _audioService.dispose();
    _amountCtl.removeListener(_updateDisplayAmount);
    _amountCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _createClientInline() async {
    final numberCtl = TextEditingController();
    final nameCtl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final textColorSecondary = isDark ? Colors.white70 : Colors.black54;
    
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black87,
      builder: (c) => Dialog(
        backgroundColor: Theme.of(context).cardColor,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NOUVEAU CLIENT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtl,
                autofocus: true,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: textColor),
                decoration: InputDecoration(
                  labelText: 'Nom du client',
                  labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textColorSecondary),
                  border: const OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: numberCtl,
                keyboardType: TextInputType.phone,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: textColor),
                decoration: InputDecoration(
                  labelText: 'Numéro de téléphone (optionnel)',
                  labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textColorSecondary),
                  border: const OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(c).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      foregroundColor: textColorSecondary,
                    ),
                    child: const Text(
                      'ANNULER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.of(c).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                    ),
                    child: const Text(
                      'AJOUTER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
              if (created is Map && created['id'] != null) {
                final createdId = created['id'].toString();
                final exists = widget.clients.indexWhere((c) => c['id']?.toString() == createdId);
                if (exists == -1) {
                  widget.clients.insert(0, created);
                } else {
                  widget.clients[exists] = created;
                }
                _clientId = created['id'];
              }
            });
            _showMinimalSnackbar('Client ajouté', isSuccess: true);
          } catch (_) {
            _showMinimalSnackbar('Client ajouté', isSuccess: true);
          }
        } else {
          final bodyText = res.body;
          final lower = bodyText.toLowerCase();
          final isDuplicate = res.statusCode == 409 || lower.contains('duplicate') || lower.contains('already exists') || lower.contains('unique');
          if (numberCtl.text.trim().isNotEmpty) {
            try {
              final headersGet = {'Content-Type': 'application/json', if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone};
              final getRes = await http.get(Uri.parse('$apiHost/clients'), headers: headersGet).timeout(const Duration(seconds: 8));
              if (getRes.statusCode == 200) {
                final list = json.decode(getRes.body) as List;
                final found = list.firstWhere((c) => (c['client_number'] ?? '').toString() == numberCtl.text.trim(), orElse: () => null);
                if (found != null) {
                  final choose = await _showExistingClientDialog(found);
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
                    _showMinimalSnackbar('Client sélectionné', isSuccess: true);
                    return;
                  } else if (isDuplicate) {
                    await _showMinimalDialog('Ce client existe déjà');
                    return;
                  }
                }
              }
            } catch (_) {}
          }
          await _showMinimalDialog('Erreur lors de la création');
        }
      } catch (e) {
        await _showMinimalDialog('Erreur réseau');
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
  }

  Future<bool?> _showExistingClientDialog(Map found) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final textColorSecondary = isDark ? Colors.white70 : Colors.black54;
    
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Theme.of(context).cardColor,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CLIENT TROUVÉ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Ce client existe déjà. Voulez-vous sélectionner ce client ?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Text(
                  '${found['name'] ?? 'Client'}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      foregroundColor: textColorSecondary,
                    ),
                    child: const Text(
                      'NON',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                    ),
                    child: const Text(
                      'SÉLECTIONNER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMinimalDialog(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    
    return showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Theme.of(context).cardColor,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ERREUR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : Colors.black,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                  ),
                  child: const Text(
                    'FERMER',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
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

  void _showMinimalSnackbar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: Colors.white,
          ),
        ),
        backgroundColor: isSuccess ? Colors.green.shade600 : Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        duration: const Duration(seconds: 2),
        elevation: 4,
      ),
    );
  }

  Future<void> _pickDue() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _due ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (d != null) setState(() => _due = d);
  }

  Future<void> _startRecording() async {
    final ok = await _audioService.startRecording();
    if (ok) {
      setState(() => _isRecording = true);
      _showMinimalSnackbar('Enregistrement démarré');
    } else {
      _showMinimalSnackbar('Erreur d\'enregistrement');
    }
  }

  Future<void> _stopRecording() async {
    final path = await _audioService.stopRecording();
    if (path != null) {
      setState(() {
        _isRecording = false;
        _audioPath = path;
      });
      _showMinimalSnackbar('Enregistrement sauvegardé', isSuccess: true);
    } else {
      setState(() => _isRecording = false);
      _showMinimalSnackbar('Erreur d\'enregistrement');
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
      _showMinimalSnackbar('Enregistrement supprimé');
    }
  }

  Future<void> _openNotesSheet() async {
    final localNotesCtl = TextEditingController(text: _notesCtl.text);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setStateSheet) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final borderColor = isDark ? Colors.white24 : Colors.black26;
            final textColor = isDark ? Colors.white : Colors.black;
            final textColorSecondary = isDark ? Colors.white70 : Colors.black54;
            
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(0)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with drag indicator
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white30 : Colors.black26,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DÉTAILS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.8,
                                color: textColorSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Note personnelle',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: Icon(Icons.close, size: 20, color: textColorSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Notes input - Style minimaliste
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: borderColor,
                          width: 0.5,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NOTE PERSONNELLE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                              color: textColorSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: localNotesCtl,
                            maxLines: 5,
                            style: TextStyle(
                              fontSize: 14,
                              color: textColor,
                              height: 1.5,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Décrire les détails de la dette...',
                              hintStyle: TextStyle(
                                color: textColorSecondary,
                                fontSize: 14,
                                height: 1.5,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Audio section - Style minimaliste
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: borderColor,
                          width: 0.5,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ENREGISTREMENT AUDIO',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                              color: textColorSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Audio controls
                          if (_audioPath == null && !_isRecording)
                            ElevatedButton.icon(
                              onPressed: () async {
                                await _startRecording();
                                setStateSheet(() {});
                              },
                              icon: const Icon(Icons.mic, size: 16),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? Colors.white : Colors.black,
                                foregroundColor: isDark ? Colors.black : Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                              ),
                              label: const Text(
                                'DÉMARRER',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                              ),
                            )
                          else if (_isRecording)
                            ElevatedButton.icon(
                              onPressed: () async {
                                await _stopRecording();
                                setStateSheet(() {});
                              },
                              icon: const Icon(Icons.stop, size: 16),
                              label: const Text(
                                'ARRÊTER',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                              ),
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      await _playAudio();
                                    },
                                    icon: const Icon(Icons.play_arrow, size: 16),
                                    label: const Text(
                                      'ÉCOUTER',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                                      side: BorderSide(color: borderColor, width: 0.5),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () async {
                                    await _deleteAudio();
                                    setStateSheet(() {});
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                                    side: BorderSide(color: Colors.red.shade300, width: 0.5),
                                  ),
                                  child: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 28),
                    
                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            foregroundColor: textColorSecondary,
                          ),
                          child: const Text(
                            'ANNULER',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            setState(() => _notesCtl.text = localNotesCtl.text);
                            Navigator.of(ctx).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.white : Colors.black,
                            foregroundColor: isDark ? Colors.black : Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                          ),
                          child: const Text(
                            'ENREGISTRER',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_clientId == null) {
      _showMinimalSnackbar('Veuillez choisir un client');
      return;
    }
    setState(() => _saving = true);
    try {
      final amount = double.tryParse(_amountCtl.text.replaceAll(',', '')) ?? 0.0;
      final headers = {'Content-Type': 'application/json', if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone};
      
      // ✅ NOUVEAU : Déterminer le type basé sur la page (debt ou loan)
      const debtType = 'debt'; // Cette page est pour les dettes
      
      // Chercher s'il existe une dette pour ce client
      final debtsRes = await http.get(Uri.parse('$apiHost/debts'), headers: headers).timeout(const Duration(seconds: 8));
      
      Map<String, dynamic>? existingDebtSameType;
      Map<String, dynamic>? existingDebtDifferentType;
      
      if (debtsRes.statusCode == 200) {
        final debtsList = json.decode(debtsRes.body) as List?;
        if (debtsList != null) {
          // Chercher une dette du MÊME type et du type OPPOSÉ
          for (final d in debtsList) {
            if (d != null && d['client_id'] == _clientId) {
              final existingType = d['type'] ?? 'debt';
              if (existingType == debtType) {
                existingDebtSameType = (d as Map).cast<String, dynamic>();
              } else {
                existingDebtDifferentType = (d as Map).cast<String, dynamic>();
              }
            }
          }
        }
      }
      
      // ✅ NOUVEAU : Si une dette de type différent existe, avertir l'utilisateur
      if (existingDebtDifferentType != null && existingDebtSameType == null) {
        setState(() => _saving = false);
        
        // Afficher un dialogue d'avertissement
        final create = await _showTypeConflictDialog(debtType);
        
        if (create != true) {
          return;
        }
        
        setState(() => _saving = true);
        // Continuer avec la création d'une nouvelle entrée
        existingDebtSameType = null;
      }
      
      if (existingDebtSameType != null) {
        // ✅ Ajouter comme montant ajouté à la dette existante du même type
        final additionBody = {
          'amount': amount,
          'added_at': DateTime.now().toIso8601String(),
          'notes': _notesCtl.text.isNotEmpty ? _notesCtl.text : 'Montant ajouté',
          if (_audioPath != null) 'audio_path': _audioPath,
        };
        
        final res = await http.post(
          Uri.parse('$apiHost/debts/${existingDebtSameType['id']}/add'),
          headers: headers,
          body: json.encode(additionBody),
        ).timeout(const Duration(seconds: 8));
        
        if (res.statusCode == 200 || res.statusCode == 201) {
          _showMinimalSnackbar('Montant ajouté à la dette existante', isSuccess: true);
          Navigator.of(context).pop(true);
        } else {
          await _showMinimalDialog('Erreur lors de l\'ajout du montant');
        }
      } else {
        // ✅ Créer une nouvelle dette
        final body = {
          'client_id': _clientId,
          'amount': amount,
          'type': debtType,
          'due_date': _due == null ? null : DateFormat('yyyy-MM-dd').format(_due!),
          'notes': _notesCtl.text,
          if (_audioPath != null) 'audio_path': _audioPath,
        };
        final res = await http.post(Uri.parse('$apiHost/debts'), headers: headers, body: json.encode(body)).timeout(const Duration(seconds: 8));
        if (res.statusCode == 201) {
          _showMinimalSnackbar('Prêt créé', isSuccess: true);
          Navigator.of(context).pop(true);
        } else {
          await _showMinimalDialog('Erreur lors de la création');
        }
      }
    } catch (e) {
      await _showMinimalDialog('Erreur réseau');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ✅ NOUVEAU : Dialogue d'avertissement pour conflit de type
  Future<bool?> _showTypeConflictDialog(String newType) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final textColorSecondary = isDark ? Colors.white70 : Colors.black54;
    
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Theme.of(context).cardColor,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning, size: 24, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'TYPE DIFFÉRENT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ce client a déjà ${newType == 'debt' ? 'un EMPRUNT' : 'une DETTE'}.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Créer une nouvelle ${newType == 'debt' ? 'DETTE' : 'EMPRUNT'} séparera les deux relations.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: textColorSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: textColorSecondary,
                    ),
                    child: const Text(
                      'ANNULER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                    ),
                    child: const Text(
                      'CRÉER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final textColorSecondary = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? Colors.white24 : Colors.black26;
    
    // Couleur subtile mauve/violette
    const subtleAccent = Color.fromARGB(255, 167, 139, 250);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(140),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.orange.withOpacity(0.08),
                Colors.orange.withOpacity(0.04),
                subtleAccent.withOpacity(0.06),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: Colors.orange.withOpacity(0.1),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Header top avec close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: Icon(Icons.close, color: textColor, size: 24),
                        padding: EdgeInsets.zero,
                        splashRadius: 24,
                      ),
                      const Spacer(),
                      // Indicateur décoratif
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.2),
                            width: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'EN COURS',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Title avec accent
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 3,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'NOUVEAU PRÊT',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 15),
                        child: Text(
                          'Je sors de l\'argent au client',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: textColorSecondary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Montant input - Style minimaliste
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: borderColor,
                                width: 0.5,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MONTANT',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.5,
                                    color: textColorSecondary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _amountCtl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w300,
                                    height: 1,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '0',
                                    hintStyle: TextStyle(
                                      color: textColorSecondary,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w300,
                                    ),
                                    suffix: Text(
                                      ' F',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
                                        color: subtleAccent.withOpacity(0.6),
                                      ),
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                                ),
                              ],
                            ),
                          ),

                          // 🌟 Montants récents avec animation
                          if (_recentAmounts.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ScaleTransition(
                              scale: Tween<double>(begin: 0.8, end: 1.0)
                                  .animate(CurvedAnimation(
                                parent: _amountAnimationCtl,
                                curve: Curves.elasticOut,
                              )),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: subtleAccent.withOpacity(0.08),
                                  border: Border.all(
                                    color: subtleAccent.withOpacity(0.2),
                                    width: 0.5,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'MONTANTS RÉCENTS',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.2,
                                        color: subtleAccent.withOpacity(0.5),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: _recentAmounts
                                          .map(
                                            (amount) => GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _amountCtl.text =
                                                      amount.toStringAsFixed(0);
                                                });
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: subtleAccent
                                                      .withOpacity(0.15),
                                                  border: Border.all(
                                                    color: subtleAccent
                                                        .withOpacity(0.3),
                                                    width: 0.5,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  NumberFormat('#,###', 'fr_FR')
                                                      .format(amount),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: subtleAccent,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Client selector - Minimaliste
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: borderColor,
                                width: 0.5,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CLIENT',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.5,
                                    color: textColorSecondary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<int>(
                                        initialValue: _clientId,
                                        isExpanded: true,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: textColor,
                                        ),
                                        items: widget.clients.map<DropdownMenuItem<int>>((cl) {
                                          final clientNumber = (cl['client_number'] ?? '').toString().isNotEmpty ? ' · ${cl['client_number']}' : '';
                                          return DropdownMenuItem(
                                            value: cl['id'],
                                            child: Text(
                                              '${cl['name'] ?? 'Client'}$clientNumber',
                                              style: TextStyle(color: textColor),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (v) => setState(() => _clientId = v),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: _saving ? null : _createClientInline,
                                      tooltip: 'Ajouter un client',
                                      icon: Icon(
                                        Icons.person_add_outlined,
                                        size: 20,
                                        color: subtleAccent.withOpacity(0.7),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Note - Minimaliste
                          InkWell(
                            onTap: _openNotesSheet,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: borderColor,
                                  width: 0.5,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'NOTE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.5,
                                      color: textColorSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _notesCtl.text.isEmpty ? 'Ajouter détails...' : _notesCtl.text,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400,
                                            color: _notesCtl.text.isEmpty ? textColorSecondary : textColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right,
                                        size: 18,
                                        color: subtleAccent.withOpacity(0.4),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Date - Style comme l'image
                          GestureDetector(
                            onTap: _pickDue,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  border: Border.all(
                                    color: Colors.orange.withOpacity(0.3),
                                    width: 0.5,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      size: 14,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _due == null
                                          ? 'AUJOURD\'HUI'
                                          : DateFormat('dd/MM/yyyy').format(_due!),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.edit,
                                      size: 12,
                                      color: Colors.orange.withOpacity(0.6),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Fixed Bottom Button - Minimaliste
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(
                    top: BorderSide(
                      color: borderColor,
                      width: 0.2,
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
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.orange,
                          disabledBackgroundColor: Colors.transparent,
                          disabledForegroundColor: Colors.orange.withOpacity(0.4),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: Colors.orange.withOpacity(0.5),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_saving)
                              const Padding(
                                padding: EdgeInsets.only(right: 10),
                                child: SizedBox(
                                  height: 14,
                                  width: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      Color.fromRGBO(213, 128, 1, 1),
                                    ),
                                  ),
                                ),
                              )
                            else
                              const Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: Icon(
                                  Icons.add,
                                  size: 18,
                                  color: Color.fromARGB(255, 215, 129, 0),
                                ),
                              ),
                            Text(
                              _saving ? 'CRÉATION...' : 'PRÊTER',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.2,
                                color: Color.fromARGB(255, 232, 140, 1),
                              ),
                            ),
                          ],
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
}