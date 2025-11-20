import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'data/audio_service.dart';
import 'add_payment_page.dart';

class DebtActionSheet extends StatefulWidget {
  final String ownerPhone;
  final Map debt;
  final Map? client;
  final VoidCallback onChanged;

  const DebtActionSheet({
    super.key,
    required this.ownerPhone,
    required this.debt,
    this.client,
    required this.onChanged,
  });

  @override
  State<DebtActionSheet> createState() => _DebtActionSheetState();
}

class _DebtActionSheetState extends State<DebtActionSheet> {
  List payments = [];
  bool _loading = false;
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
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _loadPayments() async {
    setState(() => _loading = true);
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone
      };
      final res = await http
          .get(
            Uri.parse('$apiHost/debts/${widget.debt['id']}/payments'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        payments = json.decode(res.body) as List;
      }
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addPayment() async {
    final res = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddPaymentPage(
          ownerPhone: widget.ownerPhone,
          debt: widget.debt,
        ),
      ),
    );
    if (res == true) {
      await _loadPayments();
      widget.onChanged();
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
                    child: Text('ANNULER',
                        style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(0)),
                    ),
                    child: const Text('SUPPRIMER'),
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
      final headers = {
        'Content-Type': 'application/json',
        if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone
      };
      final res = await http
          .delete(
            Uri.parse('$apiHost/debts/${widget.debt['id']}'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        widget.onChanged();
        if (mounted) Navigator.of(context).pop(true);
      } else {
        await _showMinimalDialog(
            'Erreur', 'Échec suppression: ${res.statusCode}\n${res.body}');
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
                    backgroundColor:
                        isDark ? Colors.white : Colors.black,
                    foregroundColor:
                        isDark ? Colors.black : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0)),
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
    final textColorTertiary = isDark ? Colors.white38 : Colors.black38;
    final borderColor = isDark ? Colors.white24 : Colors.black26;

    double totalPaid = 0.0;
    try {
      totalPaid = payments.fold<double>(
          0.0, (s, p) => s + (double.tryParse(p['amount'].toString()) ?? 0.0));
    } catch (_) {}

    final amount = double.tryParse(widget.debt['amount'].toString()) ?? 0.0;
    final remaining = (amount - totalPaid).clamp(0.0, amount);
    final progress = amount == 0 ? 0.0 : (totalPaid / amount).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: textColorTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'DÉTAILS DE LA DETTE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      color: textColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: textColor, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

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
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                                color: textColorSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.client?['name'] ?? 'Client inconnu',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            if (widget.client?['client_number'] != null)
                              ...[
                                const SizedBox(height: 8),
                                Text(
                                  '${widget.client?['client_number'] ?? ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: textColorSecondary,
                                  ),
                                ),
                              ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

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
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'MONTANT',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.2,
                                        color: textColorSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _fmtAmount(amount),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'PAYÉ',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.2,
                                        color: textColorSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _fmtAmount(totalPaid),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor: borderColor,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.green.withOpacity(0.7),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'RESTE À PAYER',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                    color: textColorSecondary,
                                  ),
                                ),
                                Text(
                                  _fmtAmount(remaining),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: remaining > 0
                                        ? Colors.red
                                        : Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Due Date
                    if (widget.debt['due_date'] != null) ...[
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
                                'ÉCHÉANCE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                  color: textColorSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _fmtDate(widget.debt['due_date']),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Notes Section
                    if (widget.debt['notes'] != null &&
                        widget.debt['notes'] != '') ...[
                      Text(
                        'NOTES',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: textColorSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor, width: 0.5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            widget.debt['notes'] ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w300,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Audio Section
                    if (widget.debt['audio_path'] != null &&
                        widget.debt['audio_path'] != '') ...[
                      Text(
                        'ENREGISTREMENT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: textColorSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor, width: 0.5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.play_arrow),
                                onPressed: () => _audioService
                                    .playAudio(widget.debt['audio_path']),
                              ),
                              Expanded(
                                child: Text(
                                  'Cliquez pour écouter',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textColorSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Payments History
                    Text(
                      'HISTORIQUE DES PAIEMENTS (${payments.length})',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: textColorSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_loading)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: SizedBox(
                            height: 30,
                            width: 30,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  textColorSecondary),
                            ),
                          ),
                        ),
                      )
                    else if (payments.isEmpty)
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.03)
                              : Colors.black.withOpacity(0.02),
                          border:
                              Border.all(color: borderColor, width: 0.5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 24, horizontal: 16),
                          child: Column(
                            children: [
                              Icon(Icons.payment,
                                  size: 32, color: textColorTertiary),
                              const SizedBox(height: 8),
                              Text(
                                'Aucun paiement enregistré',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w300,
                                  color: textColorSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...payments.map((p) {
                        final paidAt = p['paid_at'];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: borderColor, width: 0.5),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _fmtAmount(p['amount']),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight:
                                            FontWeight.w600,
                                        color: Colors.green,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatPaymentDate(
                                          paidAt),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight:
                                            FontWeight.w400,
                                        color:
                                            textColorSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),

                    const SizedBox(height: 24),

                    const SizedBox(height: 24),

                    // Action Buttons
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Add Payment Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _addPayment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isDark ? Colors.white : Colors.black,
                              foregroundColor:
                                  isDark ? Colors.black : Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(0)),
                            ),
                            child: Text(
                              'AJOUTER UN PAIEMENT',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                                color: isDark
                                    ? Colors.black
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Delete Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton(
                            onPressed: _deleteDebt,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(
                                  color: Colors.red, width: 0.5),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(0)),
                            ),
                            child: const Text(
                              'SUPPRIMER LA DETTE',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    String _fmtAmount(dynamic v) {
    try {
      final n = double.tryParse(v?.toString() ?? '0') ?? 0.0;
      return '${NumberFormat('#,###', 'fr_FR').format(n)} FCFA';
    } catch (_) {
      return v?.toString() ?? '-';
    }
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '-';
    final s = v.toString();
    try {
      final dt = DateTime.tryParse(s);
      if (dt != null) return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {}
    try {
      final parts = s.split(' ').first.split('-');
      if (parts.length >= 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
    } catch (_) {}
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
