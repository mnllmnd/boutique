import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text('Inviter un membre'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: phoneCtl, decoration: InputDecoration(labelText: 'Numéro')), TextField(controller: nameCtl, decoration: InputDecoration(labelText: 'Nom')), DropdownButtonFormField<String>(value: role, items: ['clerk','admin'].map((r)=>DropdownMenuItem(value: r, child: Text(r))).toList(), onChanged: (v) => role = v ?? role)]), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Annuler')), ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Inviter'))]));
    if (ok == true && phoneCtl.text.trim().isNotEmpty) {
      try {
        final headers = {'Content-Type': 'application/json', 'x-owner': widget.ownerPhone};
        final res = await http.post(Uri.parse('$apiHost/team/invite'), headers: headers, body: json.encode({'phone': phoneCtl.text.trim(), 'name': nameCtl.text.trim(), 'role': role}));
        if (res.statusCode == 201) {
          await _load();
        } else {
          showDialog(context: context, builder: (c)=>AlertDialog(title: Text('Erreur'), content: Text('Invite failed: ${res.statusCode}\n${res.body}'), actions: [TextButton(onPressed: ()=>Navigator.of(c).pop(), child: Text('OK'))]));
        }
      } catch (e) {
        // ignore
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Équipe')),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.all(12),
                children: [
                  ListTile(title: Text('Membres'), trailing: ElevatedButton(onPressed: _invite, child: Text('Inviter'))),
                  ...members.map((m) => Card(child: ListTile(title: Text(m['name'] ?? m['phone']), subtitle: Text(m['phone']), trailing: Text(m['role'] ?? 'clerk')))),
                  SizedBox(height: 12),
                  ListTile(title: Text('Activité')),
                  ...activity.map((a) => ListTile(title: Text(a['action']), subtitle: Text(a['details']?.toString() ?? ''), trailing: Text(a['created_at'] ?? ''))),
                ],
              ),
            ),
    );
  }
}
