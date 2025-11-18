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
      final m = await http.get(Uri.parse('$apiHost/team/members'), headers: headers).timeout(Duration(seconds: 8));
      final a = await http.get(Uri.parse('$apiHost/team/activity'), headers: headers).timeout(Duration(seconds: 8));
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Inviter un membre'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneCtl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Numéro de téléphone',
                hintText: 'Ex: +221771234567',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: nameCtl,
              decoration: InputDecoration(
                labelText: 'Nom complet',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: role,
              items: [
                DropdownMenuItem(value: 'clerk', child: Text('Vendeur')),
                DropdownMenuItem(value: 'admin', child: Text('Administrateur')),
              ],
              onChanged: (v) => role = v ?? role,
              decoration: InputDecoration(
                labelText: 'Rôle',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Inviter')),
        ],
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
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invitation envoyée')));
        } else {
          showDialog(
            context: context,
            builder: (c) => AlertDialog(
              title: Text('Erreur'),
              content: Text('Impossible d\'envoyer l\'invitation'),
              actions: [TextButton(onPressed: () => Navigator.of(c).pop(), child: Text('OK'))],
            ),
          );
        }
      } catch (e) {
        // ignore
      }
    }
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

    // Convertir les actions techniques en phrases lisibles
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Équipe'),
        centerTitle: true,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.all(16),
                children: [
                  // Membres section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Membres (${members.length})',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      ElevatedButton.icon(
                        onPressed: _invite,
                        icon: Icon(Icons.person_add, size: 16),
                        label: Text('Inviter'),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  if (members.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Aucun membre pour le moment',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ...members.map((m) => Card(
                          margin: EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  child: Icon(Icons.person, size: 20),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m['name'] ?? 'Pas de nom',
                                        style: TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        m['phone'] ?? 'Pas de téléphone',
                                        style: TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (m['role'] == 'admin' ? Colors.blue : Colors.green).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    m['role'] == 'admin' ? 'Admin' : 'Vendeur',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: m['role'] == 'admin' ? Colors.blue : Colors.green,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),
                  SizedBox(height: 24),
                  // Activité section
                  Text(
                    'Activité récente',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 12),
                  if (activity.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Aucune activité pour le moment',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ...activity.map((a) => Card(
                          margin: EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatActivityMessage(a),
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  _formatDate(a['created_at']),
                                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                        )),
                ],
              ),
            ),
    );
  }
}
