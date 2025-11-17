import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'local_db.dart';

class SyncService {
  final LocalDb _local = LocalDb();
  DateTime? lastSync;

  String get apiHost {
    if (kIsWeb) return 'http://localhost:3000/api';
    try {
      // On emulator use 10.0.2.2
      return 'http://10.0.2.2:3000/api';
    } catch (_) {}
    return 'http://localhost:3000/api';
  }

  /// Returns true if sync succeeded (or there was nothing to do)
  Future<bool> sync({required String ownerPhone}) async {
    final conn = await Connectivity().checkConnectivity();
    if (conn == ConnectivityResult.none) return false;

    final headers = {'Content-Type': 'application/json', if (ownerPhone.isNotEmpty) 'x-owner': ownerPhone};

    try {
      // Fetch clients
      final clientsRes = await http.get(Uri.parse('$apiHost/clients'), headers: headers).timeout(Duration(seconds: 8));
      if (clientsRes.statusCode == 200) {
        final List<dynamic> clients = json.decode(clientsRes.body) as List<dynamic>;
        final List<Map<String, dynamic>> mapped = clients.map((c) => Map<String, dynamic>.from(c as Map)).toList();
        await _local.insertOrReplaceClients(mapped);
      }

      // Fetch debts
      final debtsRes = await http.get(Uri.parse('$apiHost/debts'), headers: headers).timeout(Duration(seconds: 8));
      if (debtsRes.statusCode == 200) {
        final List<dynamic> debts = json.decode(debtsRes.body) as List<dynamic>;
        final List<Map<String, dynamic>> mapped = debts.map((d) => Map<String, dynamic>.from(d as Map)).toList();
        await _local.insertOrReplaceDebts(mapped);
      }

      // Optionally fetch payments per debt could be added here

      lastSync = DateTime.now();
      return true;
    } catch (e) {
      // ignore errors for now; return false to indicate sync failure
      return false;
    }
  }
}
