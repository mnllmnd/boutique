import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';

class AddPaymentPage extends StatefulWidget {
  final String ownerPhone;
  final Map debt;
  final bool isLoan; // ✅ NOUVEAU : Paramètre pour savoir si c'est un emprunt

  const AddPaymentPage({
    super.key, 
    required this.ownerPhone, 
    required this.debt,
    this.isLoan = false, // ✅ VALEUR PAR DÉFAUT
  });

  @override
  _AddPaymentPageState createState() => _AddPaymentPageState();
}

class _AddPaymentPageState extends State<AddPaymentPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountCtl = TextEditingController();
  final TextEditingController _notesCtl = TextEditingController();
  DateTime? _paidAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // ✅ NOUVEAU : Écouter les changements du montant pour validation en temps réel
    _amountCtl.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _amountCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  String get apiHost {
    if (kIsWeb) return 'http://localhost:3000/api';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:3000/api';
    } catch (_) {}
    return 'http://localhost:3000/api';
  }

  // ✅ FONCTIONS POUR ADAPTER LES TEXTES SELON LE TYPE
  String _getTitle() => widget.isLoan ? 'REMBOURSER EMPRUNT' : 'AJOUTER PAIEMENT';
  String _getAmountLabel() => widget.isLoan ? 'Montant remboursé' : 'Montant payé';
  String _getNotesLabel() => widget.isLoan ? 'Notes du remboursement' : 'Notes du paiement';
  String _getButtonText() => widget.isLoan ? 'ENREGISTRER REMBOURSEMENT' : 'ENREGISTRER PAIEMENT';
  String _getSuccessMessage() => widget.isLoan ? 'Remboursement enregistré' : 'Paiement enregistré';

  // ✅ NOUVEAU : Récupérer le montant restant
  double _getRemainingAmount() {
    return (widget.debt['remaining'] as num?)?.toDouble() ?? 0.0;
  }

  // ✅ NOUVEAU : Vérifier si le montant saisi est valide
  double _getEnteredAmount() {
    return double.tryParse(_amountCtl.text.replaceAll(',', '')) ?? 0.0;
  }

  // ✅ NOUVEAU : Vérifier si le paiement dépasse la dette
  bool _isAmountExceeding() {
    final entered = _getEnteredAmount();
    final remaining = _getRemainingAmount();
    return entered > 0 && remaining > 0 && entered > remaining;
  }

  // ✅ NOUVEAU : Message d'erreur si dépassement
  String? _getAmountErrorMessage() {
    if (!_isAmountExceeding()) return null;
    final remaining = _getRemainingAmount();
    return 'Montant max: ${remaining.toStringAsFixed(2)} F';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _saving = true);
    try {
      final amount = double.tryParse(_amountCtl.text.replaceAll(',', '')) ?? 0.0;
      final headers = {
        'Content-Type': 'application/json', 
        if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone
      };
      
      final body = {
        'amount': amount,
        'paid_at': _paidAt == null ? null : DateFormat('yyyy-MM-ddTHH:mm:ss').format(_paidAt!),
        'notes': _notesCtl.text,
      };
      
      final res = await http.post(
        Uri.parse('$apiHost/debts/${widget.debt['id']}/pay'),
        headers: headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 8));
      
      if (res.statusCode == 201) {
        // ✅ MESSAGE ADAPTÉ SELON LE TYPE
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getSuccessMessage()),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else if (res.statusCode == 400) {
        // ✅ NOUVEAU : Afficher l'erreur du serveur avec détails
        try {
          final error = json.decode(res.body);
          final errorMsg = error['error'] ?? 'Montant invalide';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        } catch (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Montant invalide'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de l\'enregistrement'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur réseau: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _paidAt ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() => _paidAt = d);
    }
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
          onPressed: () => Navigator.of(context).pop(false),
        ),
        // ✅ TITRE ADAPTÉ
        title: Text(
          _getTitle(),
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
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Montant
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor, width: 0.5),
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
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 24,
                                fontWeight: FontWeight.w300,
                              ),
                              decoration: InputDecoration(
                                // ✅ LABEL ADAPTÉ
                                hintText: _getAmountLabel(),
                                hintStyle: TextStyle(
                                  color: textColorSecondary,
                                  fontSize: 16,
                                ),
                                border: InputBorder.none,
                                suffix: Text(
                                  ' F',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: textColorSecondary,
                                  ),
                                ),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Montant requis' : null,
                            ),
                            // ✅ NOUVEAU : Message d'erreur si dépassement
                            if (_isAmountExceeding())
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, size: 16, color: Colors.red),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _getAmountErrorMessage() ?? '',
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // ✅ NOUVEAU : Afficher le montant restant
                            if (_getRemainingAmount() > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  'Montant restant: ${_getRemainingAmount().toStringAsFixed(2)} F',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Date
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: borderColor, width: 0.5),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'DATE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.5,
                                      color: textColorSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _paidAt == null 
                                        ? 'Aujourd\'hui'
                                        : DateFormat('dd/MM/yyyy').format(_paidAt!),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(Icons.calendar_today, size: 20, color: textColorSecondary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Notes
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor, width: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NOTES',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                                color: textColorSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _notesCtl,
                              maxLines: 3,
                              style: TextStyle(color: textColor),
                              // ✅ LABEL ADAPTÉ
                              decoration: InputDecoration(
                                hintText: _getNotesLabel(),
                                hintStyle: TextStyle(color: textColorSecondary),
                                border: InputBorder.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bouton de validation
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: borderColor, width: 0.5)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    // ✅ NOUVEAU : Désactiver si montant dépasse ou pas de montant saisi
                    onPressed: (_saving || _isAmountExceeding() || _getEnteredAmount() <= 0) ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (_saving || _isAmountExceeding() || _getEnteredAmount() <= 0)
                          ? Colors.grey[400]
                          : Theme.of(context).colorScheme.primary,
                      foregroundColor: (_saving || _isAmountExceeding() || _getEnteredAmount() <= 0)
                          ? Colors.grey[700]
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Text(
                            // ✅ TEXTE DU BOUTON ADAPTÉ
                            _getButtonText(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
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