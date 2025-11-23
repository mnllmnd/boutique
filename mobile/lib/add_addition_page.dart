import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';

class AddAdditionPage extends StatefulWidget {
  final String ownerPhone;
  final Map debt;

  const AddAdditionPage({super.key, required this.ownerPhone, required this.debt});

  @override
  _AddAdditionPageState createState() => _AddAdditionPageState();
}

class _AddAdditionPageState extends State<AddAdditionPage> {
  final TextEditingController _amountCtl = TextEditingController();
  final TextEditingController _notesCtl = TextEditingController();
  DateTime _addedAt = DateTime.now();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // ✅ NOUVEAU : Écouter les changements du montant
    _amountCtl.addListener(() {
      setState(() {});
    });
  }

  String get apiHost {
    if (kIsWeb) return 'http://localhost:3000/api';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:3000/api';
    } catch (_) {}
    return 'http://localhost:3000/api';
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _addedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _addedAt = picked);
  }

  // ✅ NOUVEAU : Récupérer le montant saisi
  double _getEnteredAmount() {
    return double.tryParse(_amountCtl.text.replaceAll(',', '')) ?? 0.0;
  }

  Future<void> _submit() async {
    final text = _amountCtl.text.trim();
    if (text.isEmpty) return;
    final val = double.tryParse(text) ?? 0.0;
    if (val <= 0) return;

    setState(() => _loading = true);
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone
      };
      final body = {
        'amount': val,
        'added_at': _addedAt.toIso8601String(),
        'notes': _notesCtl.text.trim(),
      };

      final res = await http.post(
        Uri.parse('$apiHost/debts/${widget.debt['id']}/add'),
        headers: headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } else {
        if (!mounted) return;
        final msg = json.decode(res.body)['message'] ?? res.body;
        _showSnack(msg);
      }
    } catch (e) {
      _showSnack('Erreur réseau: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _ZaraColors(isDark);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colors.background,
        leading: IconButton(
          icon: Icon(Icons.close, color: colors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text('Ajouter un montant', 
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.2
          )),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              
              // Montant principal
              Text('MONTANT', 
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5
                )),
              const SizedBox(height: 8),
              TextField(
                controller: _amountCtl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w300,
                  color: colors.textPrimary,
                  height: 1.2
                ),
                decoration: InputDecoration(
  hintText: '',
  hintStyle: TextStyle(color: colors.textHint),
  filled: true,
  fillColor: colors.surface,
  enabledBorder: OutlineInputBorder(
    borderSide: BorderSide(color: colors.border, width: 1),
  ),
  focusedBorder: OutlineInputBorder(
    borderSide: BorderSide(color: colors.textPrimary, width: 1.2),
  ),
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  prefixStyle: TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w300,
    color: colors.textPrimary,
  ),
),
              ),
              const SizedBox(height: 24),

              // Section informations
              Text('INFORMATIONS',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5
                )),
              const SizedBox(height: 16),

              // Date
              _ZaraFormField(
                onTap: _selectDate,
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, 
                      color: colors.textSecondary, size: 18),
                    const SizedBox(width: 12),
                    Text(DateFormat('dd/MM/yyyy').format(_addedAt), 
                      style: TextStyle(color: colors.textPrimary)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Notes
              _ZaraFormField(
                child: TextField(
                  controller: _notesCtl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Notes (optionnel)',
                    hintStyle: TextStyle(color: colors.textHint, fontSize: 14),
                    border: InputBorder.none,
                  ),
                  style: TextStyle(color: colors.textPrimary, fontSize: 14),
                ),
              ),
              const Spacer(),

              // Bouton
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  // ✅ NOUVEAU : Désactiver si pas de montant valide
                  onPressed: _loading || _getEnteredAmount() <= 0 ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _loading || _getEnteredAmount() <= 0
                        ? Colors.grey[400]
                        : colors.buttonBackground,
                    foregroundColor: _loading || _getEnteredAmount() <= 0
                        ? Colors.grey[700]
                        : colors.buttonForeground,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(0),
                    ),
                  ),
                  child: _loading 
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.buttonForeground,
                        ),
                      )
                    : const Text(
                        'AJOUTER LE MONTANT',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5
                        ),
                      ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }
}

class _ZaraFormField extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _ZaraFormField({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _ZaraColors(isDark);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Material(
        color: colors.surface,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ZaraColors {
  final bool isDark;

  _ZaraColors(this.isDark);

  Color get background => isDark ? const Color.fromARGB(255, 0, 0, 0) : const Color(0xFFFFFFFF);
  Color get surface => isDark ? const Color.fromARGB(255, 0, 0, 0) : const Color(0xFFFFFFFF);
  Color get textPrimary => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
  Color get textSecondary => isDark ? const Color(0xFFB0B0B0) : const Color(0xFF666666);
  Color get textHint => isDark ? const Color(0xFF888888) : const Color(0xFF999999);
  Color get border => isDark ? const Color(0xFF333333) : const Color(0xFFDDDDDD);
  Color get buttonBackground => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
  Color get buttonForeground => isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
}