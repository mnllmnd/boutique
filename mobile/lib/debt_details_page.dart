import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';

import 'add_payment_page.dart';
import 'data/audio_service.dart';

class DebtDetailsPage extends StatefulWidget {
  final String ownerPhone;
  final Map debt;

  DebtDetailsPage({required this.ownerPhone, required this.debt});

  @override
  _DebtDetailsPageState createState() => _DebtDetailsPageState();
}

class _DebtDetailsPageState extends State<DebtDetailsPage> {
  List payments = [];
  bool _loading = false;
  bool _changed = false; // whether something changed (payment added or debt deleted)
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
      final headers = {'Content-Type': 'application/json', if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone};
      final res = await http.get(Uri.parse('$apiHost/debts/${widget.debt['id']}/payments'), headers: headers).timeout(Duration(seconds: 8));
      if (res.statusCode == 200) payments = json.decode(res.body) as List;
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
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

  Future<void> _deleteDebt() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text('Confirmer'), content: Text('Supprimer cette dette ?'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Annuler')), ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Supprimer'))]));
    if (confirm != true) return;
    try {
      final headers = {'Content-Type': 'application/json', if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone};
      final res = await http.delete(Uri.parse('$apiHost/debts/${widget.debt['id']}'), headers: headers).timeout(Duration(seconds: 8));
      if (res.statusCode == 200) {
        _changed = true;
        Navigator.of(context).pop(true);
      } else {
        await showDialog(context: context, builder: (ctx) => AlertDialog(title: Text('Erreur'), content: Text('Échec suppression: ${res.statusCode}\n${res.body}'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('OK'))]));
      }
    } catch (e) {
      await showDialog(context: context, builder: (ctx) => AlertDialog(title: Text('Erreur réseau'), content: Text('$e'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('OK'))]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context).size;
    final screenWidth = mq.width;
    final isSmall = screenWidth < 360;
    double totalPaid = 0.0;
    try {
      totalPaid = payments.fold<double>(0.0, (s, p) => s + (double.tryParse(p['amount'].toString()) ?? 0.0));
    } catch (_) {}
    final amount = double.tryParse(widget.debt['amount'].toString()) ?? 0.0;
    final remaining = (amount - totalPaid);

    return Scaffold(
      appBar: AppBar(
        title: Text('Détails dette'),
        actions: [
          IconButton(onPressed: _addPayment, icon: Icon(Icons.add)),
          IconButton(onPressed: _deleteDebt, icon: Icon(Icons.delete_forever, color: Colors.redAccent)),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 520),
            child: Card(
              color: Theme.of(context).cardColor,
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.debt['client_name'] ?? '', style: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color, fontSize: 16, fontWeight: FontWeight.w800)),
                    SizedBox(height: 8),
                    Text(fmtAmount(amount), style: TextStyle(color: Theme.of(context).textTheme.displayMedium?.color, fontSize: 22, fontWeight: FontWeight.w900)),
                    SizedBox(height: 8),
                    Text('Échéance: ${fmtDate(widget.debt['due_date'])}', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                    SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: amount == 0 ? 0.0 : (totalPaid / amount).clamp(0.0, 1.0),
                      backgroundColor: Theme.of(context).dividerColor.withOpacity(0.3),
                      color: Theme.of(context).colorScheme.primary,
                      minHeight: isSmall ? 8 : 10,
                    ),
                    SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Payé', style: TextStyle(color: Theme.of(context).colorScheme.secondary)), SizedBox(height:4), Text(fmtAmount(totalPaid), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700))])),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Reste', style: TextStyle(color: Theme.of(context).colorScheme.secondary)), SizedBox(height:4), Text(fmtAmount(remaining), style: TextStyle(color: remaining <= 0 ? Colors.green : Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.w700))])),
                    ]),
                    SizedBox(height: 12),
                    if (widget.debt['notes'] != null && widget.debt['notes'] != '') ...[
                      Text('Notes', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                      SizedBox(height: 8),
                      Text(widget.debt['notes'], style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                      SizedBox(height: 12),
                    ],
                    if (widget.debt['audio_path'] != null && widget.debt['audio_path'] != '') ...[
                      Text('Enregistrement audio', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                      SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _audioService.playAudio(widget.debt['audio_path']),
                        icon: Icon(Icons.play_arrow, size: 18),
                        label: Text('Écouter l\'enregistrement', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      SizedBox(height: 12),
                    ],
                    Text('Paiements récents', style: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color, fontWeight: FontWeight.w700)),
                    SizedBox(height: 8),
                    Container(
                      height: 220,
                      child: _loading
                        ? Center(child: CircularProgressIndicator())
                        : payments.isEmpty
                          ? Center(child: Text('Aucun paiement', style: TextStyle(color: Theme.of(context).colorScheme.secondary)))
                          : ListView.separated(
                              itemCount: payments.length,
                              separatorBuilder: (_, __) => Divider(color: Theme.of(context).dividerColor, height: 1),
                              itemBuilder: (ctx, i) {
                                final p = payments[i];
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(backgroundColor: Colors.grey[900], child: Icon(Icons.monetization_on, color: Theme.of(context).colorScheme.primary)),
                                  title: Text(fmtAmount(p['amount']), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                                  subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(p['paid_at'])), style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                                );
                              },
                            ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.of(context).pop(_changed), child: Text('Fermer')),
                        SizedBox(width: 8),
                        ElevatedButton.icon(onPressed: _addPayment, icon: Icon(Icons.add, color: Theme.of(context).elevatedButtonTheme.style?.foregroundColor?.resolve({}) ?? Colors.white), label: Text('Ajouter paiement', style: TextStyle(color: Theme.of(context).elevatedButtonTheme.style?.foregroundColor?.resolve({}) ?? Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary)),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String fmtAmount(dynamic v) {
    try {
      final n = double.tryParse(v?.toString() ?? '0') ?? 0.0;
      return NumberFormat('#,###', 'fr_FR').format(n) + ' FCFA';
    } catch (_) { return v?.toString() ?? '-'; }
  }

  String fmtDate(dynamic v) {
    if (v == null) return '-';
    final s = v.toString();
    try { final dt = DateTime.tryParse(s); if (dt != null) return DateFormat('dd/MM/yyyy').format(dt); } catch (_) {}
    try { final parts = s.split(' ').first.split('-'); if (parts.length>=3) return '${parts[2]}/${parts[1]}/${parts[0]}'; } catch (_) {}
    return s;
  }
}
