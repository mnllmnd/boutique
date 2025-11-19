import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';

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

  double get _remaining {
    try {
      final amt = double.tryParse(widget.debt['amount']?.toString() ?? '0') ?? 0.0;
      if (widget.debt['remaining'] != null) return double.tryParse(widget.debt['remaining'].toString()) ?? amt;
      if (widget.debt['total_paid'] != null) return (amt - (double.tryParse(widget.debt['total_paid'].toString()) ?? 0.0)).clamp(0.0, amt);
      return amt;
    } catch (_) {
      return 0.0;
    }
  }

  @override
  void initState() {
    super.initState();
    final r = _remaining;
    if (r > 0) _amountCtl.text = r.toStringAsFixed(0);
  }

  Future<void> _submit() async {
    final text = _amountCtl.text.trim();
    if (text.isEmpty) return;
    final val = double.tryParse(text) ?? 0.0;
    if (val <= 0) return;
    setState(() => _loading = true);
    try {
      final headers = {'Content-Type': 'application/json', if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone};
      final body = {'amount': val, 'paid_at': _paidAt.toIso8601String()};
      final res = await http.post(Uri.parse('$apiHost/debts/${widget.debt['id']}/pay'), headers: headers, body: json.encode(body)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 || res.statusCode == 201) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        final msg = res.body;
        await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Erreur'), content: Text('Échec ajout paiement: ${res.statusCode}\n$msg'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))]));
      }
    } catch (e) {
      await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Erreur réseau'), content: Text('$e'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))]));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
    final remaining = _remaining;
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Ajouter paiement'),
        elevation: 0,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                color: Theme.of(context).cardColor,
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.debt['client_name'] ?? '', 
                        style: TextStyle(
                          color: Theme.of(context).textTheme.titleLarge?.color, 
                          fontWeight: FontWeight.w800,
                          fontSize: 18
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Reste: ${NumberFormat('#,###', 'fr_FR').format(remaining)} FCFA', 
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontSize: 16
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _amountCtl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          fontSize: 32, 
                          fontWeight: FontWeight.w700, 
                          color: Theme.of(context).textTheme.displayLarge?.color
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3), 
                            fontSize: 32
                          ),
                          filled: true,
                          fillColor: Theme.of(context).inputDecorationTheme.fillColor ?? Theme.of(context).scaffoldBackgroundColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12), 
                            borderSide: BorderSide.none
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent, 
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)
                          ),
                        ),
                        child: _loading 
                            ? SizedBox(
                                height: 20, 
                                width: 20, 
                                child: CircularProgressIndicator(
                                  strokeWidth: 2, 
                                  color: Theme.of(context).colorScheme.onPrimary
                                )
                              ) 
                            : Text(
                                'Enregistrer le paiement', 
                                style: TextStyle(
                                  color: Theme.of(context).elevatedButtonTheme.style?.foregroundColor?.resolve({}) ?? Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600
                                )
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
    );
  }
}