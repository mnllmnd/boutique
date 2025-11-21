import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart'; // ✅ AJOUTER CET IMPORT

class AddPaymentPage extends StatefulWidget {
  final String ownerPhone;
  final Map debt;

  const AddPaymentPage({super.key, required this.ownerPhone, required this.debt});

  @override
  _AddPaymentPageState createState() => _AddPaymentPageState();
}

class _AddPaymentPageState extends State<AddPaymentPage> {
  final TextEditingController _amountCtl = TextEditingController();
  final DateTime _paidAt = DateTime.now();
  bool _loading = false;

  // ✅ Conversion sécurisée des nombres
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(' ', '')) ?? 0.0;
    }
    return 0.0;
  }

  // ✅ Calcul du montant maximum (maintenant informatif seulement)
  double get _maxAllowedAmount {
    final debtAmount = _parseDouble(widget.debt['amount']);
    final totalPaid = _parseDouble(widget.debt['total_paid'] ?? 0);
    return debtAmount - totalPaid;
  }

  // ✅ FORMATAGE DES MONTANTS
  String _fmtAmount(dynamic v) {
    try {
      final n = double.tryParse(v?.toString() ?? '0') ?? 0.0;
      return '${NumberFormat('#,###', 'fr_FR').format(n)} F';
    } catch (_) { return v?.toString() ?? '-'; }
  }

  Future<void> _submit() async {
    final text = _amountCtl.text.trim();
    if (text.isEmpty) return;
    final val = double.tryParse(text) ?? 0.0;
    
    // ✅ SUPPRIMÉ : Plus de validation de surpaiement
    if (val <= 0) return;

    setState(() => _loading = true);
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone
      };
      final body = {'amount': val, 'paid_at': _paidAt.toIso8601String()};

      final res = await http.post(
        Uri.parse('$apiHost/debts/${widget.debt['id']}/pay'),
        headers: headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (!mounted) return;
        
        // ✅ MESSAGE ADAPTÉ : Dette soldée ou créance inversée
        final remaining = _maxAllowedAmount - val;
        String message;
        if (remaining <= 0) {
          message = 'Paiement enregistré avec succès!';
          if (remaining < 0) {
            message += '\n\nVous devez maintenant ${_fmtAmount(remaining.abs())} au client.';
          }
        } else {
          message = 'Paiement enregistré avec succès!';
        }
        
        await _showMinimalDialog('Succès', message);
        if (mounted) Navigator.of(context).pop(true);
      } else {
        if (!mounted) return;
        final msg = res.body;
        await _showMinimalDialog('Erreur', 'Échec ajout paiement: ${res.statusCode}\n$msg');
      }
    } catch (e) {
      if (!mounted) return;
      await _showMinimalDialog('Erreur réseau', '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showMinimalDialog(String title, String message) {
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
              Text(title.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
              const SizedBox(height: 16),
              Text(message, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w300, color: textColor)),
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
                  child: Text('OK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.black : Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get apiHost {
    if (kIsWeb) return 'http://localhost:3000/api';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:3000/api';
    } catch (_) {}
    return 'http://localhost:3000/api';
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
        title: Text('NOUVEAU PAIEMENT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 2, color: textColor)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 32),
              
              Text('MONTANT DU PAIEMENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColorSecondary)),
              const SizedBox(height: 16),
              
              // Champ de saisie
              TextField(
                controller: _amountCtl,
                keyboardType: TextInputType.number,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w300, color: textColor),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(fontSize: 32, fontWeight: FontWeight.w300, color: textColorSecondary),
                  border: OutlineInputBorder(borderSide: BorderSide(color: borderColor, width: 0.5)),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor, width: 0.5)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: textColor, width: 1)),
                  contentPadding: const EdgeInsets.all(20),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Bouton d'enregistrement
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : Colors.black,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    disabledBackgroundColor: isDark ? Colors.white24 : Colors.black26,
                    disabledForegroundColor: isDark ? Colors.black38 : Colors.white54,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                  ),
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('ENREGISTRER LE PAIEMENT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.black : Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}