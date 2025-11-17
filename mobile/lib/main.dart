import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestion de dettes',
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List debts = [];
  final apiBase = 'http://10.0.2.2:3000/api/debts'; // emulator -> host

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchDebts();
  }

  Future fetchDebts({String? query}) async {
    try {
      final res = await http.get(Uri.parse(apiBase));
      if (res.statusCode == 200) {
        final list = json.decode(res.body) as List;
        if (query != null && query.isNotEmpty) {
          setState(() => debts = list.where((d) {
                final creditor = (d['creditor'] ?? '').toString().toLowerCase();
                final debtor = (d['debtor'] ?? '').toString().toLowerCase();
                return creditor.contains(query.toLowerCase()) || debtor.contains(query.toLowerCase());
              }).toList());
        } else {
          setState(() => debts = list);
        }
      }
    } catch (e) {
      print('Error fetching debts: $e');
    }
  }

  Future createOrUpdateDebt({Map? existing}) async {
    final creditorCtl = TextEditingController(text: existing != null ? existing['creditor'] : '');
    final debtorCtl = TextEditingController(text: existing != null ? existing['debtor'] : '');
    final amountCtl = TextEditingController(text: existing != null ? existing['amount'].toString() : '');
    final dueCtl = TextEditingController(text: existing != null && existing['due_date'] != null ? existing['due_date'] : '');
    final notesCtl = TextEditingController(text: existing != null ? existing['notes'] : '');

    final isEditing = existing != null;

    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'Modifier dette' : 'Ajouter dette'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: creditorCtl, decoration: InputDecoration(labelText: 'Créancier')),
              TextField(controller: debtorCtl, decoration: InputDecoration(labelText: 'Débiteur')),
              TextField(controller: amountCtl, decoration: InputDecoration(labelText: 'Montant'), keyboardType: TextInputType.number),
              TextField(controller: dueCtl, decoration: InputDecoration(labelText: 'Date d\'échéance (YYYY-MM-DD)')),
              TextField(controller: notesCtl, decoration: InputDecoration(labelText: 'Notes')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final body = {
                'creditor': creditorCtl.text,
                'debtor': debtorCtl.text,
                'amount': double.tryParse(amountCtl.text) ?? 0.0,
                'due_date': dueCtl.text.isEmpty ? null : dueCtl.text,
                'notes': notesCtl.text,
              };
              if (isEditing) {
                final id = existing['id'];
                final res = await http.put(Uri.parse('$apiBase/$id'), headers: {'Content-Type': 'application/json'}, body: json.encode(body));
                if (res.statusCode == 200) Navigator.of(ctx).pop();
              } else {
                final res = await http.post(Uri.parse(apiBase), headers: {'Content-Type': 'application/json'}, body: json.encode(body));
                if (res.statusCode == 201) Navigator.of(ctx).pop();
              }
              await fetchDebts();
            },
            child: Text(isEditing ? 'Enregistrer' : 'Ajouter'),
          )
        ],
      ),
    );
  }

  Future showDebtDetails(Map d) async {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Détail'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${d['id']}'),
            SizedBox(height: 6),
            Text('Créancier: ${d['creditor']}'),
            Text('Débiteur: ${d['debtor']}'),
            Text('Montant: €${d['amount']}'),
            Text('Échéance: ${d['due_date'] ?? '-'}'),
            Text('Notes: ${d['notes'] ?? '-'}'),
            Text('Payé: ${d['paid'] == true ? 'Oui' : 'Non'}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Fermer')),
          if (d['paid'] != true)
            ElevatedButton(
              onPressed: () async {
                final res = await http.post(Uri.parse('$apiBase/${d['id']}/pay'));
                if (res.statusCode == 200) {
                  Navigator.of(ctx).pop();
                  await fetchDebts();
                }
              },
              child: Text('Marquer payé'),
            ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await createOrUpdateDebt(existing: d);
            },
            child: Text('Modifier'),
          ),
          TextButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text('Supprimer'),
                  content: Text('Supprimer cette dette ?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(c).pop(false), child: Text('Annuler')),
                    TextButton(onPressed: () => Navigator.of(c).pop(true), child: Text('OK')),
                  ],
                ),
              );
              if (ok == true) {
                final res = await http.delete(Uri.parse('$apiBase/${d['id']}'));
                if (res.statusCode == 200) {
                  Navigator.of(context).pop();
                  await fetchDebts();
                }
              }
            },
            child: Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Gestion de dettes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(hintText: 'Rechercher créancier ou débiteur'),
                    onChanged: (v) => fetchDebts(query: v),
                  ),
                ),
                IconButton(onPressed: () => fetchDebts(), icon: Icon(Icons.refresh)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: debts.length,
              itemBuilder: (ctx, i) {
                final d = debts[i];
                return ListTile(
                  title: Text('${d['creditor']} → ${d['debtor']}'),
                  subtitle: Text('€${d['amount']} — due ${d['due_date'] ?? '-'}'),
                  trailing: d['paid'] == true ? Icon(Icons.check, color: Colors.green) : null,
                  onTap: () => showDebtDetails(d),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => createOrUpdateDebt(),
        child: Icon(Icons.add),
      ),
    );
  }
}
