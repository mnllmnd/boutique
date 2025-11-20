import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';

import 'add_payment_page.dart';
import 'add_addition_page.dart';
import 'data/audio_service.dart';

class DebtDetailsPage extends StatefulWidget {
  final String ownerPhone;
  final Map debt;

  const DebtDetailsPage({super.key, required this.ownerPhone, required this.debt});

  @override
  _DebtDetailsPageState createState() => _DebtDetailsPageState();
}

class _DebtDetailsPageState extends State<DebtDetailsPage> {
  List payments = [];
  List additions = [];
  bool _loading = false;
  bool _changed = false;
  late AudioService _audioService;

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
    _loadPayments();
    _loadAdditions();
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _loadPayments() async {
    setState(() => _loading = true);
    try {
      final headers = {'Content-Type': 'application/json', if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone};
      final res = await http.get(Uri.parse('$apiHost/debts/${widget.debt['id']}/payments'), headers: headers).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) payments = json.decode(res.body) as List;
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadAdditions() async {
    try {
      final headers = {'Content-Type': 'application/json', if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone};
      final res = await http.get(Uri.parse('$apiHost/debts/${widget.debt['id']}/additions'), headers: headers).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        if (mounted) setState(() => additions = json.decode(res.body) as List);
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _addPayment() async {
    final res = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddPaymentPage(ownerPhone: widget.ownerPhone, debt: widget.debt)));
    if (res == true) {
      _changed = true;
      await _loadPayments();
      setState(() {});
    }
  }

  Future<void> _addAddition() async {
    final res = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddAdditionPage(ownerPhone: widget.ownerPhone, debt: widget.debt)),
    );
    if (res == true) {
      _changed = true;
      await _loadAdditions();
      setState(() {});
    }
  }

  Future<void> _deleteDebt() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    
    final confirm = await showDialog<bool>(
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
                'SUPPRIMER LA DETTE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Êtes-vous sûr de vouloir supprimer cette dette ?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(
                      'ANNULER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                    ),
                    child: Text(
                      'SUPPRIMER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: Colors.white,
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
    
    if (confirm != true) return;
    try {
      final headers = {'Content-Type': 'application/json', if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone};
      final res = await http.delete(Uri.parse('$apiHost/debts/${widget.debt['id']}'), headers: headers).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        _changed = true;
        Navigator.of(context).pop(true);
      } else {
        await _showMinimalDialog('Erreur', 'Échec suppression: ${res.statusCode}\n${res.body}');
      }
    } catch (e) {
      await _showMinimalDialog('Erreur réseau', '$e');
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
              Text(
                title.toUpperCase(),
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
                  child: Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                      color: isDark ? Colors.black : Colors.white,
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final textColorSecondary = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? Colors.white24 : Colors.black26;

    double totalPaid = 0.0;
    try {
      totalPaid = payments.fold<double>(0.0, (s, p) => s + (double.tryParse(p['amount'].toString()) ?? 0.0));
    } catch (_) {}
    final amount = double.tryParse(widget.debt['amount'].toString()) ?? 0.0;
    final remaining = (amount - totalPaid);
    final progress = amount == 0 ? 0.0 : (totalPaid / amount).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor, size: 24),
          onPressed: () => Navigator.of(context).pop(_changed),
        ),
        title: Text(
          'DÉTAILS DE LA DETTE',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            color: textColor,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _addAddition,
            icon: Icon(Icons.add_circle, color: Colors.orange, size: 20),
            tooltip: 'Ajouter un montant',
          ),
          IconButton(
            onPressed: _addPayment,
            icon: Icon(Icons.payment, color: textColor, size: 20),
            tooltip: 'Ajouter un paiement',
          ),
          IconButton(
            onPressed: _deleteDebt,
            icon: Icon(Icons.delete_outline, color: Colors.red, size: 20),
            tooltip: 'Supprimer',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Client Info Card
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
                        'CLIENT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: textColorSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        (widget.debt['client_name'] ?? '').toUpperCase(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ÉCHÉANCE: ${_fmtDate(widget.debt['due_date'])}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: textColorSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Amount Card
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
                        'MONTANT TOTAL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: textColorSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _fmtAmount(amount),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w300,
                          color: textColor,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PAYÉ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.5,
                                    color: textColorSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _fmtAmount(totalPaid),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'RESTE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.5,
                                    color: textColorSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _fmtAmount(remaining),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: remaining <= 0 ? Colors.green : textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Theme.of(context).dividerColor.withOpacity(0.3),
                        color: Theme.of(context).colorScheme.primary,
                        minHeight: 4,
                      ),
                    ],
                  ),
                ),
              ),

              // Notes Section
              if (widget.debt['notes'] != null && widget.debt['notes'] != '') ...[
                const SizedBox(height: 24),
                Text(
                  'NOTES',
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
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    widget.debt['notes'],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: textColor,
                    ),
                  ),
                ),
              ],

              // Audio Section
              if (widget.debt['audio_path'] != null && widget.debt['audio_path'] != '') ...[
                const SizedBox(height: 24),
                Text(
                  'ENREGISTREMENT AUDIO',
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
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.audio_file, color: textColorSecondary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Enregistrement disponible',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: textColor,
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor, width: 0.5),
                        ),
                        child: TextButton(
                          onPressed: () => _audioService.playAudio(widget.debt['audio_path']),
                          style: TextButton.styleFrom(
                            foregroundColor: textColor,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                          ),
                          child: Text(
                            'ÉCOUTER',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Additions Section
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'MONTANTS AJOUTÉS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: textColorSecondary,
                    ),
                  ),
                  Text(
                    '${additions.length} MONTANT${additions.length > 1 ? 'S' : ''}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: textColorSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (additions.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor, width: 0.5),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.add_circle_outline, size: 48, color: textColorSecondary),
                      const SizedBox(height: 16),
                      Text(
                        'AUCUN MONTANT AJOUTÉ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColorSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Aucun montant ajouté à cette dette',
                        style: TextStyle(
                          fontSize: 12,
                          color: textColorSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...additions.map((a) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: borderColor, width: 0.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${NumberFormat('#,###', 'fr_FR').format(double.tryParse(a['amount'].toString()) ?? 0)} FCFA',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange,
                                  ),
                                ),
                                Text(
                                  _fmtDate(a['added_at']),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textColorSecondary,
                                  ),
                                ),
                              ],
                            ),
                            if (a['notes'] != null && (a['notes'] as String).isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                a['notes'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textColor,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )).toList(),

              // Payments Section
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PAIEMENTS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: textColorSecondary,
                    ),
                  ),
                  Text(
                    '${payments.length} PAIEMENT${payments.length > 1 ? 'S' : ''}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: textColorSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_loading)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor, width: 0.5),
                  ),
                  child: const Center(child: CircularProgressIndicator()),
                )
              else if (payments.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor, width: 0.5),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.payments_outlined, size: 48, color: textColorSecondary),
                      const SizedBox(height: 16),
                      Text(
                        'AUCUN PAIEMENT',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColorSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Aucun paiement enregistré pour cette dette',
                        style: TextStyle(
                          fontSize: 12,
                          color: textColorSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...payments.map((p) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: borderColor, width: 0.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.light ? Colors.grey[100] : Colors.grey[900],
                              ),
                              child: Icon(
                                Icons.monetization_on_outlined,
                                color: textColorSecondary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _fmtAmount(p['amount']),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatPaymentDate(p['paid_at']),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1,
                                      color: textColorSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),

              const SizedBox(height: 32),

              // Add Payment Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _addPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : Colors.black,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                  ),
                  child: Text(
                    'AJOUTER UN PAIEMENT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: isDark ? Colors.black : Colors.white,
                    ),
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

  String _fmtAmount(dynamic v) {
    try {
      final n = double.tryParse(v?.toString() ?? '0') ?? 0.0;
      return '${NumberFormat('#,###', 'fr_FR').format(n)} FCFA';
    } catch (_) { return v?.toString() ?? '-'; }
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '-';
    final s = v.toString();
    try { final dt = DateTime.tryParse(s); if (dt != null) return DateFormat('dd/MM/yyyy').format(dt); } catch (_) {}
    try { final parts = s.split(' ').first.split('-'); if (parts.length>=3) return '${parts[2]}/${parts[1]}/${parts[0]}'; } catch (_) {}
    return s;
  }

  String _formatPaymentDate(dynamic dateStr) {
    if (dateStr == null) return '-';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return dateStr.toString();
    }
  }
}