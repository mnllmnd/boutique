import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:boutique_mobile/config/api_config.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:boutique_mobile/widgets/smart_calculator.dart';
import 'data/audio_service.dart';

// Extension pour trouver le premier élément ou null
extension FirstWhereOrNull<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

class AddLoanPage extends StatefulWidget {
  final String ownerPhone;
  final List clients;

  const AddLoanPage({super.key, required this.ownerPhone, required this.clients});

  @override
  _AddLoanPageState createState() => _AddLoanPageState();
}

class _AddLoanPageState extends State<AddLoanPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  int? _clientId;
  final TextEditingController _amountCtl = TextEditingController();
  final TextEditingController _notesCtl = TextEditingController();
  DateTime? _due;
  bool _saving = false;
  late AudioService _audioService;
  String? _audioPath;
  final bool _isRecording = false;
  final List<double> _recentAmounts = [];
  double _displayAmount = 0.0;

  String get apiHost => ApiConfig.getBaseUrl();

  @override
  void initState() {
    super.initState();
    _initializeDateFormatting();
    _audioService = AudioService();
    
    _amountCtl.addListener(_updateDisplayAmount);
    
    _clientId = widget.clients.isNotEmpty ? widget.clients.first['id'] : null;
  }
  
  void _updateDisplayAmount() {
    final newAmount = double.tryParse(_amountCtl.text.replaceAll(',', '')) ?? 0.0;
    if (newAmount != _displayAmount) {
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
    } catch (_) {}
  }

  @override
  void dispose() {
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
                'NOUVEAU PRÊTEUR',
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
                  labelText: 'Nom du prêteur',
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
        final phoneNumber = numberCtl.text.trim();
        final body = {
          if (phoneNumber.isNotEmpty) 'client_number': phoneNumber,
          'name': nameCtl.text.trim()
        };
        final headers = {'Content-Type': 'application/json', if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone};
        setState(() => _saving = true);
        final res = await http.post(Uri.parse('$apiHost/clients'), headers: headers, body: json.encode(body)).timeout(const Duration(seconds: 8));
        
        if (res.statusCode == 201 || res.statusCode == 200) {
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
            _showMinimalSnackbar('Prêteur ajouté', isSuccess: true);
          } catch (_) {
            _showMinimalSnackbar('Prêteur ajouté', isSuccess: true);
          }
        } else if (res.statusCode == 400) {
          _showMinimalDialog('Un client avec ce numéro existe déjà');
        } else {
          _showMinimalDialog('Erreur lors de la création');
        }
      } catch (e) {
        _showMinimalDialog('Erreur réseau');
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
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

  void _openCalculator() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => SmartCalculator(
        initialValue: double.tryParse(_amountCtl.text.replaceAll(',', '')) ?? 0,
        onResultSelected: (result) {
          setState(() {
            _amountCtl.text = result.toStringAsFixed(2);
          });
        },
        title: 'CALCULATRICE - MONTANT EMPRUNTÉ',
        isDark: isDark,
      ),
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
      const loanType = 'loan'; // Cette page est pour les emprunts
      
      // Chercher s'il existe un emprunt pour ce client
      final debtsRes = await http.get(Uri.parse('$apiHost/debts'), headers: headers).timeout(const Duration(seconds: 8));
      
      Map<String, dynamic>? existingLoanSameType;
      Map<String, dynamic>? existingDebtDifferentType;
      
      if (debtsRes.statusCode == 200) {
        final debtsList = json.decode(debtsRes.body) as List?;
        if (debtsList != null) {
          // Chercher un emprunt du MÊME type et une dette du type OPPOSÉ
          for (final d in debtsList) {
            if (d != null && d['client_id'] == _clientId) {
              final existingType = d['type'] ?? 'debt';
              if (existingType == loanType) {
                existingLoanSameType = (d as Map).cast<String, dynamic>();
              } else {
                existingDebtDifferentType = (d as Map).cast<String, dynamic>();
              }
            }
          }
        }
      }
      
      // ✅ NOUVEAU : Si une dette de type différent existe, avertir l'utilisateur
      if (existingDebtDifferentType != null && existingLoanSameType == null) {
        setState(() => _saving = false);
        
        // Afficher un dialogue d'avertissement
        final create = await _showTypeConflictDialog(loanType);
        
        if (create != true) {
          return;
        }
        
        setState(() => _saving = true);
        // Continuer avec la création d'une nouvelle entrée
        existingLoanSameType = null;
      }
      
      if (existingLoanSameType != null) {
        // ✅ Ajouter comme montant ajouté à l'emprunt existant du même type
        final additionBody = {
          'amount': amount,
          'added_at': DateTime.now().toIso8601String(),
          'notes': _notesCtl.text.isNotEmpty ? _notesCtl.text : 'Montant ajouté',
          if (_audioPath != null) 'audio_path': _audioPath,
        };
        
        final res = await http.post(
          Uri.parse('$apiHost/debts/${existingLoanSameType['id']}/add'),
          headers: headers,
          body: json.encode(additionBody),
        ).timeout(const Duration(seconds: 8));
        
        if (res.statusCode == 200 || res.statusCode == 201) {
          _showMinimalSnackbar('Montant ajouté à l\'emprunt existant', isSuccess: true);
          Navigator.of(context).pop(true);
        } else {
          await _showMinimalDialog('Erreur lors de l\'ajout du montant');
        }
      } else {
        // ✅ Créer un nouvel emprunt (type = 'loan')
        final body = {
          'client_id': _clientId,
          'amount': amount,
          'type': 'loan',
          'due_date': _due == null ? null : DateFormat('yyyy-MM-dd').format(_due!),
          'notes': _notesCtl.text,
          if (_audioPath != null) 'audio_path': _audioPath,
        };
        
        final res = await http.post(
          Uri.parse('$apiHost/debts'),
          headers: headers,
          body: json.encode(body),
        ).timeout(const Duration(seconds: 8));
        
        if (res.statusCode == 201) {
          _showMinimalSnackbar('Emprunt créé', isSuccess: true);
          Navigator.of(context).pop(true);
        } else {
          await _showMinimalDialog('Erreur lors de la création de l\'emprunt');
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
                  const Icon(Icons.warning, size: 24, color: Colors.purple),
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
                  color: Colors.purple.withOpacity(0.1),
                  border: Border.all(color: Colors.purple.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ce client a déjà une DETTE.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Créer un nouvel EMPRUNT séparera les deux relations.',
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
    final borderColor = isDark ? const Color(0xFF333333) : const Color(0xFFDDDDDD);
    
    const subtleAccent = Color.fromARGB(255, 141, 47, 219); // Violet pour les emprunts

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
                subtleAccent.withOpacity(0.08),
                subtleAccent.withOpacity(0.04),
                const Color.fromARGB(255, 167, 139, 250).withOpacity(0.06),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: subtleAccent.withOpacity(0.1),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: Icon(Icons.close, color: textColor, size: 24),
                        padding: EdgeInsets.zero,
                        splashRadius: 24,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: subtleAccent.withOpacity(0.1),
                          border: Border.all(
                            color: subtleAccent.withOpacity(0.2),
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
                                color: subtleAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'EMPRUNT',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                                color: subtleAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 3,
                            height: 24,
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 135, 41, 212),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'NOUVEL EMPRUNT',
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
                          'Je reçois de l\'argent du client',
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
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: borderColor, width: 0.5),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'MONTANT EMPRUNTÉ',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.5,
                                        color: textColorSecondary,
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: _openCalculator,
                                      icon: const Icon(Icons.calculate, size: 16),
                                      label: const Text('CALC'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue[400],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
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

                          if (_recentAmounts.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: subtleAccent.withOpacity(0.08),
                                border: Border.all(color: subtleAccent.withOpacity(0.2), width: 0.5),
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
                                    children: _recentAmounts.map((amount) => GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _amountCtl.text = amount.toStringAsFixed(0);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: subtleAccent.withOpacity(0.15),
                                          border: Border.all(color: subtleAccent.withOpacity(0.3), width: 0.5),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          NumberFormat('#,###', 'fr_FR').format(amount),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: subtleAccent,
                                          ),
                                        ),
                                      ),
                                    )).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: borderColor, width: 0.5),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PRÊTEUR',
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
                                              '${cl['name'] ?? 'Prêteur'}$clientNumber',
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
                                      tooltip: 'Ajouter un prêteur',
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

                          GestureDetector(
                            onTap: _pickDue,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: subtleAccent.withOpacity(0.1),
                                  border: Border.all(
                                    color: subtleAccent.withOpacity(0.3),
                                    width: 0.5,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_today, size: 14, color: subtleAccent),
                                    const SizedBox(width: 8),
                                    Text(
                                      _due == null ? 'DATE DE REMBOURSEMENT' : DateFormat('dd/MM/yyyy').format(_due!),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: subtleAccent,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(Icons.edit, size: 12, color: subtleAccent.withOpacity(0.6)),
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

              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(top: BorderSide(color: borderColor, width: 0.2)),
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
                          foregroundColor: subtleAccent,
                          disabledBackgroundColor: Colors.transparent,
                          disabledForegroundColor: subtleAccent.withOpacity(0.4),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: subtleAccent.withOpacity(0.5),
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
                                    valueColor: AlwaysStoppedAnimation(subtleAccent),
                                  ),
                                ),
                              )
                            else
                              const Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: Icon(Icons.account_balance_wallet, size: 18, color: subtleAccent),
                              ),
                            Text(
                              _saving ? 'CRÉATION...' : 'EMPRUNTER',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.2,
                                color: subtleAccent,
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