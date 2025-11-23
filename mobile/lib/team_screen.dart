import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class TeamScreen extends StatefulWidget {
  final String ownerPhone;

  const TeamScreen({super.key, required this.ownerPhone});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  bool _loading = true;
  List members = [];
  List activity = [];

  String get apiHost {
    return 'http://localhost:3000/api';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final headers = {'Content-Type': 'application/json', 'x-owner': widget.ownerPhone};
      final m = await http.get(Uri.parse('$apiHost/team/members'), headers: headers).timeout(const Duration(seconds: 8));
      final a = await http.get(Uri.parse('$apiHost/team/activity'), headers: headers).timeout(const Duration(seconds: 8));
      if (m.statusCode == 200) members = json.decode(m.body) as List;
      if (a.statusCode == 200) activity = json.decode(a.body) as List;
    } catch (e) {
      // ignore for now
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _invite() async {
    final phoneCtl = TextEditingController();
    final nameCtl = TextEditingController();
    String role = 'clerk';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final textColorSecondary = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? Colors.white24 : Colors.black26;

    final ok = await showDialog<bool>(
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
                'INVITER UN MEMBRE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: phoneCtl,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: textColor, fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'Numéro de téléphone',
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: textColorSecondary,
                  ),
                  hintText: 'Ex: +221771234567',
                  border: const OutlineInputBorder(borderSide: BorderSide(width: 0.5)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: borderColor, width: 0.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: textColor, width: 1),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtl,
                style: TextStyle(color: textColor, fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'Nom complet',
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: textColorSecondary,
                  ),
                  border: const OutlineInputBorder(borderSide: BorderSide(width: 0.5)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: borderColor, width: 0.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: textColor, width: 1),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: role,
                style: TextStyle(color: textColor, fontSize: 15),
                dropdownColor: Theme.of(context).cardColor,
                items: const [
                  DropdownMenuItem(
                    value: 'clerk',
                    child: Text('VENDEUR'),
                  ),
                  DropdownMenuItem(
                    value: 'admin',
                    child: Text('ADMINISTRATEUR'),
                  ),
                ],
                onChanged: (v) => role = v ?? role,
                decoration: InputDecoration(
                  labelText: 'Rôle',
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: textColorSecondary,
                  ),
                  border: const OutlineInputBorder(borderSide: BorderSide(width: 0.5)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: borderColor, width: 0.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: textColor, width: 1),
                  ),
                  contentPadding: const EdgeInsets.all(16),
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
                        color: textColorSecondary,
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
                    child: Text(
                      'INVITER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: isDark ? Colors.black : Colors.white,
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

    if (ok == true && phoneCtl.text.trim().isNotEmpty) {
      try {
        final headers = {'Content-Type': 'application/json', 'x-owner': widget.ownerPhone};
        final res = await http.post(
          Uri.parse('$apiHost/team/invite'),
          headers: headers,
          body: json.encode({'phone': phoneCtl.text.trim(), 'name': nameCtl.text.trim(), 'role': role}),
        );
        if (res.statusCode == 201) {
          await _load();
          if (mounted) _showMinimalSnackbar('Invitation envoyée');
        } else {
          _showMinimalSnackbar('Impossible d\'envoyer l\'invitation');
        }
      } catch (e) {
        _showMinimalSnackbar('Erreur lors de l\'invitation');
      }
    }
  }

  void _showMinimalSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatActivityMessage(Map activity) {
    final action = activity['action'] ?? '';
    final details = activity['details'];

    switch (action) {
      case 'create_client':
        return _extractClientName(details);
      case 'create_debt':
        return _extractDebtInfo(details);
      case 'add_payment':
        return _extractPaymentInfo(details);
      default:
        return action;
    }
  }

  String _extractClientName(dynamic details) {
    try {
      if (details is String) {
        final map = jsonDecode(details) as Map;
        final name = map['name'] ?? 'Client';
        return 'Création d\'un client : $name';
      }
    } catch (_) {}
    return 'Nouveau client créé';
  }

  String _extractDebtInfo(dynamic details) {
    try {
      if (details is String) {
        final map = jsonDecode(details) as Map;
        final clientName = map['client_name'] ?? 'Client';
        final amount = map['amount'] ?? '0';
        return 'Nouvelle dette pour $clientName : $amount FCFA';
      }
    } catch (_) {}
    return 'Nouvelle dette créée';
  }

  String _extractPaymentInfo(dynamic details) {
    try {
      if (details is String) {
        final map = jsonDecode(details) as Map;
        final clientName = map['client_name'] ?? 'Client';
        final amount = map['amount'] ?? '0';
        return 'Paiement reçu de $clientName : $amount FCFA';
      }
    } catch (_) {}
    return 'Paiement enregistré';
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'ÉQUIPE',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            color: textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // MEMBRES SECTION
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'MEMBRES',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                            color: textColorSecondary,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: borderColor, width: 0.5),
                          ),
                          child: TextButton(
                            onPressed: _invite,
                            style: TextButton.styleFrom(
                              foregroundColor: textColor,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                            ),
                            child: Text(
                              'INVITER',
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
                    const SizedBox(height: 16),
                    Text(
                      '${members.length} MEMBRE${members.length > 1 ? 'S' : ''}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (members.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor, width: 0.5),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 48,
                              color: textColorSecondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'AUCUN MEMBRE',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textColorSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Invitez des membres pour collaborer',
                              style: TextStyle(
                                fontSize: 12,
                                color: textColorSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...members.map((m) => Container(
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
                                      Icons.person_outline,
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
                                          (m['name'] ?? 'Pas de nom').toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          m['phone'] ?? 'Pas de téléphone',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: textColorSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: (m['role'] == 'admin' ? Colors.blue : Colors.green).withOpacity(0.6),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Text(
                                      m['role'] == 'admin' ? 'ADMIN' : 'VENDEUR',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1,
                                        color: m['role'] == 'admin' ? Colors.blue : Colors.green,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )),

                    const SizedBox(height: 32),

                    // ACTIVITÉ SECTION
                    Text(
                      'ACTIVITÉ RÉCENTE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: textColorSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${activity.length} ACTION${activity.length > 1 ? 'S' : ''}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (activity.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor, width: 0.5),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.history_outlined,
                              size: 48,
                              color: textColorSecondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'AUCUNE ACTIVITÉ',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textColorSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'L\'activité de l\'équipe apparaîtra ici',
                              style: TextStyle(
                                fontSize: 12,
                                color: textColorSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...activity.map((a) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: borderColor, width: 0.5),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatActivityMessage(a),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatDate(a['created_at']),
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
                          )),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}