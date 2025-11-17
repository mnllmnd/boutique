import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDb {
  static final LocalDb _instance = LocalDb._internal();
  factory LocalDb() => _instance;
  LocalDb._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final docs = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docs.path, 'boutique_local.db');
    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE clients(
            id INTEGER PRIMARY KEY,
            name TEXT,
            client_number TEXT,
            avatar_url TEXT,
            owner_phone TEXT,
            updated_at TEXT
          );
        ''');

        await db.execute('''
          CREATE TABLE debts(
            id INTEGER PRIMARY KEY,
            client_id INTEGER,
            amount REAL,
            due_date TEXT,
            notes TEXT,
            paid INTEGER DEFAULT 0,
            owner_phone TEXT,
            updated_at TEXT
          );
        ''');

        await db.execute('''
          CREATE TABLE payments(
            id INTEGER PRIMARY KEY,
            debt_id INTEGER,
            amount REAL,
            paid_at TEXT,
            owner_phone TEXT
          );
        ''');
      },
    );
  }

  Future<void> insertOrReplaceClients(List<Map<String, dynamic>> rows) async {
    final db = await database;
    final batch = db.batch();
    for (final r in rows) {
      batch.insert('clients', {
        'id': r['id'],
        'name': r['name'],
        'client_number': r['client_number'],
        'avatar_url': r['avatar_url'],
        'owner_phone': r['owner_phone'] ?? r['owner_phone'],
        'updated_at': r['updated_at'] ?? DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getClients() async {
    final db = await database;
    return await db.query('clients', orderBy: 'name COLLATE NOCASE');
  }

  Future<void> insertOrReplaceDebts(List<Map<String, dynamic>> rows) async {
    final db = await database;
    final batch = db.batch();
    for (final r in rows) {
      batch.insert('debts', {
        'id': r['id'],
        'client_id': r['client_id'],
        'amount': (r['amount'] is num) ? r['amount'] : double.tryParse(r['amount']?.toString() ?? '0') ?? 0.0,
        'due_date': r['due_date'],
        'notes': r['notes'],
        'paid': (r['paid'] == true) ? 1 : 0,
        'owner_phone': r['owner_phone'],
        'updated_at': r['updated_at'] ?? DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getDebts() async {
    final db = await database;
    return await db.query('debts', orderBy: 'id DESC');
  }

  Future<void> insertOrReplacePayments(List<Map<String, dynamic>> rows) async {
    final db = await database;
    final batch = db.batch();
    for (final r in rows) {
      batch.insert('payments', {
        'id': r['id'],
        'debt_id': r['debt_id'],
        'amount': (r['amount'] is num) ? r['amount'] : double.tryParse(r['amount']?.toString() ?? '0') ?? 0.0,
        'paid_at': r['paid_at'],
        'owner_phone': r['owner_phone'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getPaymentsForDebt(int debtId) async {
    final db = await database;
    return await db.query('payments', where: 'debt_id = ?', whereArgs: [debtId], orderBy: 'paid_at DESC');
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('payments');
    await db.delete('debts');
    await db.delete('clients');
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
