import 'package:boutique_mobile/add_payment_page.dart';
import 'package:boutique_mobile/add_loan_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
// google_fonts removed - using default text theme
// avatar image now uses Image.network; removed cached_network_image usage
import 'package:connectivity_plus/connectivity_plus.dart';
import 'data/sync_service.dart';
import 'team_screen.dart';
import 'app_settings.dart';
import 'settings_screen.dart';
import 'login_page.dart';
import 'add_debt_page.dart';
import 'add_client_page.dart';
import 'add_addition_page.dart';
import 'debt_details_page.dart';
import 'theme.dart';

// Theme colors (deprecated - use Theme.of(context) instead)
const Color kBackground = Color(0xFF0F1113);
const Color kSurface = Color(0xFF121416);
const Color kCard = Color(0xFF151718);
const Color kAccent = Color(0xFF7C3AED);
const Color kMuted = Color(0xFF9AA0A6);

String fmtFCFA(dynamic v) {
  // Delegate to AppSettings formatter (ensure AppSettings initialized with current owner)
  try {
    return AppSettings().formatCurrency(v);
  } catch (_) {
    if (v == null) return '-';
    if (v is num) return '${v.toStringAsFixed(0)} F';
    final parsed = num.tryParse(v.toString());
    if (parsed == null) return '${v.toString()} F';
    return '${parsed.toStringAsFixed(0)} F';
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? ownerPhone;
  String? ownerShopName;
  int? ownerId;
  late AppSettings _appSettings;

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
    _appSettings = AppSettings();
    _appSettings.addListener(_onSettingsChanged);
    _loadOwner();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _appSettings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  Future _loadOwner() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('owner_phone');
    final shop = prefs.getString('owner_shop_name');
    final id = prefs.getInt('owner_id');
    
    // Try to auto-login with token
    if (phone != null) {
      await _appSettings.initForOwner(phone);
      final token = _appSettings.authToken;
      
      if (token != null && token.isNotEmpty) {
        // Try to verify token
        try {
          final res = await http.post(
            Uri.parse('$apiHost/auth/verify-token'.replaceFirst('\u007f', '')),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'auth_token': token})
          ).timeout(const Duration(seconds: 5));
          
          if (res.statusCode == 200) {
            final data = json.decode(res.body);
            setState(() {
              ownerPhone = data['phone'] ?? phone;
              ownerShopName = data['shop_name'] ?? shop;
              ownerId = data['id'] ?? id;
            });
            return; // Auto-login successful
          }
        } catch (_) {
          // Token verification failed, continue to login page
        }
      }
    }
    
    // Fallback: use stored credentials or go to login
    setState(() {
      ownerPhone = phone;
      ownerShopName = shop;
      ownerId = id;
    });
  }

  Future setOwner({required String phone, String? shopName, int? id, String? firstName, String? lastName, bool? boutiqueModeEnabled}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('owner_phone', phone);
    if (shopName != null) await prefs.setString('owner_shop_name', shopName);
    if (id != null) await prefs.setInt('owner_id', id);
    if (firstName != null) await prefs.setString('owner_first_name', firstName);
    if (lastName != null) await prefs.setString('owner_last_name', lastName);
    
    // Initialize settings with profile data
    final settings = AppSettings();
    if (firstName != null && lastName != null) {
      await settings.setProfileInfo(firstName, lastName, shopName ?? '');
    }
    
    setState(() { ownerPhone = phone; ownerShopName = shopName; ownerId = id; });
  }

  Future clearOwner() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('owner_phone');
    await prefs.remove('owner_shop_name');
    await prefs.remove('owner_id');
    setState(() { ownerPhone = null; ownerShopName = null; ownerId = null; });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Boutique - Gestion de dettes',
      theme: getAppTheme(lightMode: _appSettings.lightMode),
      home: ownerPhone == null
          ? LoginPage(onLogin: (phone, shop, id, firstName, lastName, boutiqueModeEnabled) => setOwner(phone: phone, shopName: shop, id: id, firstName: firstName, lastName: lastName, boutiqueModeEnabled: boutiqueModeEnabled))
          : HomePage(ownerPhone: ownerPhone!, ownerShopName: ownerShopName, onLogout: clearOwner),
    );
  }
}

class HomePage extends StatefulWidget {
  final String ownerPhone;
  final String? ownerShopName;
  final VoidCallback onLogout;

  const HomePage({super.key, required this.ownerPhone, this.ownerShopName, required this.onLogout});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tabIndex = 0;
  List debts = [];
  List clients = [];
  String _searchQuery = '';
  bool _isSearching = false;
  bool _showTotalCard = true;
  bool _showAmountFilter = false;
  double _minDebtAmount = 0.0;
  double _maxDebtAmount = 0.0;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _amountMinController = TextEditingController();
  final TextEditingController _amountMaxController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounceTimer;
  final Set<dynamic> _expandedClients = {};
  String boutiqueName = '';
  late final SyncService _syncService;
  StreamSubscription<ConnectivityResult>? _connSub;
  bool _isSyncing = false;

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
    _loadBoutique();
    fetchClients();
    fetchDebts();
    _startConnectivityListener();
    _searchController.addListener(() {
      final v = _searchController.text;
      if (v != _searchQuery) {
        setState(() => _searchQuery = v);
        if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 400), () {
          if (_tabIndex == 0) {
            fetchDebts(query: _searchQuery);
          } else {
            setState(() {});
          }
        });
      }
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.ownerPhone.isNotEmpty) {
        AppSettings().initForOwner(widget.ownerPhone);
        AppSettings().addListener(() {
          if (mounted) setState(() {});
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _amountMinController.dispose();
    _amountMaxController.dispose();
    _searchFocus.dispose();
    _debounceTimer?.cancel();
    _connSub?.cancel();
    super.dispose();
  }

  Future<void> _startConnectivityListener() async {
    _syncService = SyncService();
    try {
      final conn = await Connectivity().checkConnectivity();
      if (conn != ConnectivityResult.none) {
        _triggerSync();
      }
    } catch (_) {}

    _connSub = Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        _triggerSync();
      }
    });
  }

  Future<void> _showClientActions(dynamic client, dynamic clientId) async {
    if (client == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    final choice = await showDialog<String?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: Theme.of(context).cardColor,
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('payment'),
            child: Row(children: [const Icon(Icons.monetization_on_outlined, color: Colors.green), const SizedBox(width: 12), Text('Ajouter paiement', style: TextStyle(color: textColor))]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('addition'),
            child: Row(children: [const Icon(Icons.add, color: Colors.orange), const SizedBox(width: 12), Text('Ajouter un prêt', style: TextStyle(color: textColor))]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('delete'),
            child: Row(children: [const Icon(Icons.delete, color: Colors.red), const SizedBox(width: 12), Text('Supprimer client', style: TextStyle(color: textColor))]),
          ),
        ],
      ),
    );

    if (choice == null) return;

    if (choice == 'payment') {
      final debtWithClient = debts.firstWhere((d) => d['client_id'] == client['id'], orElse: () => null);
      if (debtWithClient != null) {
        final res = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddPaymentPage(ownerPhone: widget.ownerPhone, debt: debtWithClient)));
        if (res == true) await fetchDebts();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucune dette trouvée')));
      }
    } else if (choice == 'addition') {
      final debtWithClient = debts.firstWhere((d) => d['client_id'] == client['id'], orElse: () => null);
      if (debtWithClient != null) {
        final res = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddAdditionPage(ownerPhone: widget.ownerPhone, debt: debtWithClient)));
        if (res == true) await fetchDebts();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucune dette trouvée pour ajouter un montant')));
      }
    } else if (choice == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Supprimer le client'),
          content: Text('Voulez-vous vraiment supprimer ${client['name'] ?? 'ce client'} ?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Annuler')),
            ElevatedButton(onPressed: () => Navigator.of(c).pop(true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Supprimer')),
          ],
        ),
      );

      if (confirm == true) {
        try {
          final headers = {'Content-Type': 'application/json', if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone};
          final res = await http.delete(Uri.parse('$apiHost/clients/${client['id']}'), headers: headers).timeout(const Duration(seconds: 8));
          if (res.statusCode == 200) {
            await fetchClients();
            await fetchDebts();
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Client supprimé')));
          } else {
            if (mounted) await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Erreur'), content: Text('Échec suppression: ${res.statusCode}\n${res.body}'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))]));
          }
        } catch (e) {
          if (mounted) await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Erreur réseau'), content: Text('$e'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))]));
        }
      }
    }
  }

  Future<void> _addDebtForClient(dynamic c) async {
    final amountCtl = TextEditingController();
    final notesCtl = TextEditingController();
    DateTime? due;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    
    final ok = await showDialog<bool>(
      context: context,
      builder: (dlg) => Dialog(
        backgroundColor: Theme.of(context).cardColor,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NOUVELLE DETTE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Pour ${c['name'] ?? 'client'}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: amountCtl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Montant',
                  labelStyle: TextStyle(color: textColor),
                  border: const OutlineInputBorder(borderSide: BorderSide(width: 0.5)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: textColor, width: 1),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      due == null ? 'Échéance: -' : 'Échéance: ${DateFormat('dd/MM/yyyy').format(due!)}',
                      style: TextStyle(color: textColor),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) {
                        due = d;
                        setState(() {});
                      }
                    },
                    child: const Text(
                      'CHOISIR',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: notesCtl,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Notes',
                  labelStyle: TextStyle(color: textColor),
                  border: const OutlineInputBorder(borderSide: BorderSide(width: 0.5)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: textColor, width: 1),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(dlg).pop(false),
                    child: const Text(
                      'ANNULER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.of(dlg).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                    ),
                    child: const Text(
                      'AJOUTER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
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

    if (ok == true && amountCtl.text.trim().isNotEmpty) {
      try {
        final headers = {
          'Content-Type': 'application/json',
          if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone
        };
        final amount = double.tryParse(amountCtl.text) ?? 0.0;
        
        // Chercher s'il existe déjà une dette pour ce client
        Map<String, dynamic>? existingDebt;
        final debtsList = debts.where((d) => d != null && d['client_id'] == c['id']).toList();
        if (debtsList.isNotEmpty) {
          // Prendre la première dette (consolidée) de ce client
          existingDebt = debtsList.first as Map<String, dynamic>;
        }
        
        if (existingDebt != null) {
          // Ajouter comme montant ajouté à la dette existante
          final additionBody = {
            'amount': amount,
            'added_at': DateTime.now().toIso8601String(),
            'notes': notesCtl.text.isNotEmpty ? notesCtl.text : 'Montant ajouté',
          };
          
          final res = await http.post(
            Uri.parse('$apiHost/debts/${existingDebt['id']}/add'),
            headers: headers,
            body: json.encode(additionBody),
          ).timeout(const Duration(seconds: 8));
          
              if (res.statusCode == 200 || res.statusCode == 201) {
            await fetchDebts();
            if (mounted) {
              setState(() {
                if (c != null && c['id'] != null) {
                  final comp = '${c['id'].toString()}|${(existingDebt?['type'] ?? 'debt').toString()}';
                  _expandedClients.add(comp);
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Montant ajouté à la dette existante')),
              );
            }
          } else {
            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Erreur'),
                content: Text('Échec ajout montant: ${res.statusCode}\n${res.body}'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        } else {
          // Créer une nouvelle dette
          final body = {
            'client_id': c['id'],
            'amount': amount,
            'due_date': due == null ? null : DateFormat('yyyy-MM-dd').format(due!),
            'notes': notesCtl.text,
          };
          
          final res = await http.post(
            Uri.parse('$apiHost/debts'),
            headers: headers,
            body: json.encode(body),
          ).timeout(const Duration(seconds: 8));
          
          if (res.statusCode == 201) {
            await fetchDebts();
            if (mounted) {
              setState(() {
                if (c != null && c['id'] != null) {
                  final comp = '${c['id'].toString()}|debt';
                  _expandedClients.add(comp);
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Dette ajoutée')),
              );
            }
          } else {
            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Erreur'),
                content: Text('Échec création dette: ${res.statusCode}\n${res.body}'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        }
      } catch (e) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Erreur'),
            content: Text('Erreur: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _triggerSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final ok = await _syncService.sync(ownerPhone: widget.ownerPhone);
      if (ok) {
        await fetchClients();
        await fetchDebts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Synchronisation terminée')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future _loadBoutique() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('boutique_name_${widget.ownerPhone}');
    if (name != null && name.isNotEmpty) {
      setState(() => boutiqueName = name);
    }
  }

  Future<void> _saveDebtsLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final debtsJson = json.encode(debts);
      await prefs.setString('debts_${widget.ownerPhone}', debtsJson);
    } catch (e) {
      print('Error saving debts locally: $e');
    }
  }

  Future<void> _loadDebtsLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final debtsJson = prefs.getString('debts_${widget.ownerPhone}');
      if (debtsJson != null && debtsJson.isNotEmpty) {
        setState(() => debts = List.from(json.decode(debtsJson) as List));
      }
    } catch (e) {
      print('Error loading debts locally: $e');
    }
  }

  Future<void> _saveClientsLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientsJson = json.encode(clients);
      await prefs.setString('clients_${widget.ownerPhone}', clientsJson);
    } catch (e) {
      print('Error saving clients locally: $e');
    }
  }

  Future<void> _loadClientsLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientsJson = prefs.getString('clients_${widget.ownerPhone}');
      if (clientsJson != null && clientsJson.isNotEmpty) {
        setState(() => clients = List.from(json.decode(clientsJson) as List));
      }
    } catch (e) {
      print('Error loading clients locally: $e');
    }
  }

  Future fetchClients() async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone
      };
      final res = await http.get(
        Uri.parse('$apiHost/clients'),
        headers: headers,
      ).timeout(const Duration(seconds: 8));
      
      if (res.statusCode == 200) {
        setState(() => clients = json.decode(res.body) as List);
      }
    } on TimeoutException {
      print('Timeout fetching clients');
    } catch (e) {
      print('Error fetching clients: $e');
    }
  }

  // ✅ CORRIGÉ : fetchDebts avec consolidation par client
  Future fetchDebts({String? query}) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone
      };
      final res = await http.get(
        // demander les soldes consolidés côté serveur pour réduire les appels
        Uri.parse('$apiHost/debts?consolidated=1'),
        headers: headers,
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final raw = json.decode(res.body);
        final list = raw is List ? raw : (raw is Map ? [raw] : []);

        // Normaliser la réponse consolidée (backend renvoie client_id, type, remaining, total_debt, debt_ids, last_debt_id...)
        final List<Map<String, dynamic>> normalized = [];
        for (final item in list) {
          if (item == null) continue;
          // Si c'est un objet agrégé (consolidated) on s'adapte
          if (item is Map && item.containsKey('client_id') && item.containsKey('type')) {
            final clientId = item['client_id'];
            final type = (item['type'] ?? 'debt').toString();
            final remaining = (item['remaining'] as num?)?.toDouble() ?? ((item['remaining'] is String) ? double.tryParse(item['remaining'].toString()) ?? 0.0 : 0.0);
            final amount = (item['total_debt'] as num?)?.toDouble() ?? (item['total_base_amount'] as num?)?.toDouble() ?? 0.0;
            final lastId = item['last_debt_id'] ?? (item['debt_ids'] is List && item['debt_ids'].isNotEmpty ? item['debt_ids'][0] : null);

            normalized.add({
              'id': lastId,
              'client_id': clientId,
              'type': type,
              'amount': amount,
              'remaining': remaining,
              'total_additions': item['total_additions'],
              'total_paid': item['total_payments'] ?? item['total_payments'],
              'debt_ids': item['debt_ids'],
              '_ts': (lastId is int) ? lastId.toDouble() : (lastId is String ? double.tryParse(lastId) ?? 0.0 : 0.0),
            });
          } else if (item is Map) {
            // ancien format : chaque ligne est une dette
            final id = item['id'];
            normalized.add({
              ...item,
              'id': id,
              'client_id': item['client_id'],
              'type': item['type'] ?? 'debt',
              'amount': item['amount'],
              'remaining': (item['remaining'] as num?)?.toDouble() ?? 0.0,
              '_ts': _tsForDebt(item),
            });
          }
        }

        // Filtrer par recherche si nécessaire
        var consolidatedDebts = normalized;
        if (query != null && query.isNotEmpty) {
          consolidatedDebts = consolidatedDebts.where((d) {
            final clientName = _clientNameForDebt(d)?.toLowerCase() ?? '';
            return clientName.contains(query.toLowerCase());
          }).toList();
        }

        setState(() => debts = consolidatedDebts);
      }
    } on TimeoutException {
      print('Timeout fetching debts');
    } catch (e) {
      print('Error fetching debts: $e');
    }
  }

  String? _clientNameForDebt(dynamic d) {
    if (d == null) return null;
    final cid = d['client_id'];
    if (cid == null) return null;
    final c = clients.firstWhere((x) => x['id'] == cid, orElse: () => null);
    return c != null ? c['name'] : null;
  }

  // Retourne un score temporel pour une dette (ms depuis epoch) pour choisir la plus récente
  double _tsForDebt(dynamic debt) {
    if (debt == null) return 0.0;
    final List<String> tsFields = ['updated_at', 'added_at', 'created_at', 'createdAt', 'date'];
    for (final f in tsFields) {
      final v = debt[f];
      if (v == null) continue;
      if (v is String) {
        final dt = DateTime.tryParse(v);
        if (dt != null) return dt.millisecondsSinceEpoch.toDouble();
      } else if (v is int) {
        return v.toDouble();
      } else if (v is double) {
        return v;
      }
    }

    final idv = debt['id'];
    if (idv is int) return idv.toDouble();
    if (idv is String) return double.tryParse(idv) ?? 0.0;
    return 0.0;
  }

  // Parse double safely (copié/consistent with DebtDetailsPage)
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(' ', '')) ?? 0.0;
    }
    return 0.0;
  }

  // Calculer remaining exactement comme dans DebtDetailsPage: amount - sum(payments)
  double _calculateRemainingFromPayments(Map debt, List paymentList) {
    try {
      final debtAmount = _parseDouble(debt['amount']);
      double totalPaid = 0.0;
      for (final payment in paymentList) {
        totalPaid += _parseDouble(payment['amount']);
      }
      return debtAmount - totalPaid;
    } catch (_) {
      return 0.0;
    }
  }

  // ✅ CORRIGÉ : Calcul du total par client
  double _clientTotalRemaining(dynamic clientId) {
    // Ne pas additionner plusieurs enregistrements potentiellement dupliqués.
    // Prendre la dette la plus récente pour ce client.
    final clientDebts = debts.where((d) => d != null && d['client_id'] == clientId).toList();
    if (clientDebts.isEmpty) return 0.0;
    dynamic latest = clientDebts.reduce((a, b) => _tsForDebt(b) >= _tsForDebt(a) ? b : a);
    return ((latest['remaining'] as num?)?.toDouble() ?? 0.0);
  }

  // ✅ CORRIGÉ : Calcul du total général
  // ✅ NOUVEAU : Calcul du solde net basé sur balance (universel)
  double _calculateNetBalance() {
    double totalToCollect = 0.0;   
    double totalToPay = 0.0;     
    
    for (final d in debts) {
      if (d == null) continue;
      
      // Récupérer balance ou remaining, en gérant les types (String ou double)
      double balance = 0.0;
      final balanceValue = d['balance'] ?? d['remaining'];
      
      if (balanceValue is String) {
        balance = double.tryParse(balanceValue.toString().replaceAll(' ', '')) ?? 0.0;
      } else if (balanceValue is double) {
        balance = balanceValue;
      } else if (balanceValue is int) {
        balance = balanceValue.toDouble();
      }
      
      // Déterminer le type initial
      final type = d['type'] ?? 'debt';
      
      // Pour les PRÊTS (type='debt'): balance positive = à percevoir
      if (type == 'debt') {
        if (balance > 0) {
          totalToCollect += balance;
        } else if (balance < 0) {
          totalToPay += balance.abs();
        }
      } 
      // Pour les EMPRUNTS (type='loan'): balance positive = on doit payer
      else if (type == 'loan') {
        if (balance > 0) {
          totalToPay += balance;
        } else if (balance < 0) {
          totalToCollect += balance.abs();
        }
      }
    }
    
    return totalToCollect - totalToPay;  // Positif = à recevoir, Négatif = à payer
  }

  // ✅ NOUVEAU : Calculer le total des PRÊTS
  double _calculateTotalPrets() {
    double total = 0.0;
    for (final d in debts) {
      if (d == null) continue;
      if ((d['type'] ?? 'debt') != 'debt') continue; // Seulement les prêts
      
      final remaining = (d['remaining'] as double?) ?? 0.0;
      if (remaining > 0) total += remaining;
    }
    return total;
  }

  // ✅ NOUVEAU : Calculer le total des EMPRUNTS
  double _calculateTotalEmprunts() {
    double total = 0.0;
    for (final d in debts) {
      if (d == null) continue;
      if ((d['type'] ?? 'debt') != 'loan') continue; // Seulement les emprunts
      
      final remaining = (d['remaining'] as double?) ?? 0.0;
      if (remaining > 0) total += remaining;
    }
    return total;
  }

  // Build client avatar similar to DebtDetailsPage
  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (name.isNotEmpty) {
      return name.substring(0, 1).toUpperCase();
    }
    return 'C';
  }

  Widget _buildInitialsAvatar(String initials, double size) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildClientAvatarWidget(dynamic client, double size) {
    final hasAvatar = client != null && client['avatar_url'] != null && client['avatar_url'].toString().isNotEmpty;
    final clientName = client != null ? (client['name'] ?? 'Client') : 'Client';
    final initials = _getInitials(clientName.toString());

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.26),
          width: 2,
        ),
      ),
      child: hasAvatar
          ? ClipOval(
              child: Image.network(
                client['avatar_url'],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildInitialsAvatar(initials, size);
                },
              ),
            )
          : _buildInitialsAvatar(initials, size),
    );
  }

  Future<int?> createClient() async {
    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(builder: (_) => AddClientPage(ownerPhone: widget.ownerPhone)),
    );
    
    if (result != null) {
      await fetchClients();
      if (result is Map && result['id'] != null) {
        return result['id'] as int?;
      }
      if (result == true && clients.isNotEmpty) {
        return clients.last['id'] as int?;
      }
    }
    return null;
  }

  Future _showAddChoice() async {
    if (clients.isEmpty) {
      final add = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Aucun client'),
          content: const Text('Aucun client trouvé. Voulez-vous en ajouter un maintenant ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Ajouter client'),
            ),
          ],
        ),
      );
      if (add == true) {
        final newId = await createClient();
        if (newId != null) {
          await fetchClients();
          await _showAddChoice();
        }
      }
      return;
    }

    // Show bottom sheet with PRÊTER and EMPRUNTER options
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'AJOUTER UNE TRANSACTION',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: textColor,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.of(ctx).pop('preter'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.green.withOpacity(0.3),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.arrow_upward, size: 24, color: Colors.green),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PRÊTER',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Je donne l\'argent au client',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.of(ctx).pop('emprunter'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward, size: 24, color: Colors.blue),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'EMPRUNTER',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Je reçois l\'argent du client',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (choice == 'preter') {
      await createDebt();
    } else if (choice == 'emprunter') {
      await createLoan();
    }
  }

  Future createDebt() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddDebtPage(
          ownerPhone: widget.ownerPhone,
          clients: clients,
          preselectedClientId: null,
        ),
      ),
    );
    
    if (result == true) {
      await fetchDebts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prêt ajouté')),
      );
    }
  }

  Future createLoan() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddLoanPage(
          ownerPhone: widget.ownerPhone,
          clients: clients,
        ),
      ),
    );
    
    if (result == true) {
      await fetchDebts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emprunt ajouté')),
      );
    }
  }

  Future showDebtDetails(Map d) async {
    final res = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DebtDetailsPage(ownerPhone: widget.ownerPhone, debt: d)),
    );
    if (res == true) await fetchDebts();
  }

  Widget _buildDebtsTab() {
    // ✅ NOUVEAU : Calculer les PRÊTS et EMPRUNTS séparément
    final totalPrets = _calculateTotalPrets();
    final totalEmprunts = _calculateTotalEmprunts();
    
    // Ancien calcul pour compatibilité
    final netBalance = _calculateNetBalance();
    int totalUnpaid = debts.where((d) {
      final remaining = (d['remaining'] as double?) ?? 0.0;
      return remaining > 0;
    }).length;

    // Filtrer les dettes par plage de montant si applicable
    List filteredDebts = debts;
    if (_minDebtAmount > 0 || _maxDebtAmount > 0) {
      filteredDebts = debts.where((d) {
        final remaining = (d['remaining'] as double?) ?? 0.0;
        
        bool inRange = true;
        if (_minDebtAmount > 0 && remaining < _minDebtAmount) inRange = false;
        if (_maxDebtAmount > 0 && remaining > _maxDebtAmount) inRange = false;
        return inRange;
      }).toList();
    }

    // Grouper par client ET type (debt/loan) pour afficher séparément prêts et emprunts
    final Map<String, List> grouped = {};
    for (final d in filteredDebts) {
      final cidPart = d != null && d['client_id'] != null ? d['client_id'].toString() : 'unknown';
      final typePart = d != null && d['type'] != null ? d['type'].toString() : 'debt';
      final key = '$cidPart|$typePart';
      if (!grouped.containsKey(key)) grouped[key] = [];
      grouped[key]!.add(d);
    }

    final groups = grouped.entries.toList();
    groups.sort((a, b) {
      double sumRem(List list) {
        double tot = 0.0;
        for (final d in list) {
          final remaining = (d['remaining'] as double?) ?? 0.0;
          tot += remaining;
        }
        return tot;
      }

      final ra = sumRem(a.value);
      final rb = sumRem(b.value);
      final sa = ra > 0 ? 0 : 1;
      final sb = rb > 0 ? 0 : 1;
      if (sa != sb) return sa - sb;
      return 0;
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final textColorSecondary = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? Colors.white24 : Colors.black26;

    return RefreshIndicator(
      onRefresh: () async => await fetchDebts(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: groups.length + 2,
        itemBuilder: (ctx, gi) {
          if (gi == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card - TOTAL À PERCEVOIR & DETTES IMPAYÉES
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Show "À PERCEVOIR" or "À REMBOURSER" based on net balance
                        Builder(builder: (_) {
                          final bool oweMoney = netBalance < 0;
                          return Text(
                            oweMoney ? 'À REMBOURSER' : 'À PERCEVOIR',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                              color: textColorSecondary,
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => setState(() => _showTotalCard = !_showTotalCard),
                              child: Icon(
                                _showTotalCard ? Icons.visibility : Icons.visibility_off,
                                color: textColorSecondary,
                                size: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _showTotalCard
                                ? Builder(builder: (_) {
                                    final bool oweMoney = netBalance < 0;
                                    final display = oweMoney
                                        ? AppSettings().formatCurrency(netBalance.abs())
                                        : AppSettings().formatCurrency(netBalance);
                                    final Color amtColor = oweMoney
                                        ? const Color.fromARGB(231, 141, 47, 219)
                                        : textColor;

                                    return Text(
                                      display,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w200,
                                        color: amtColor,
                                      ),
                                    );
                                  })
                                : Text(
                                    '••••••',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w400,
                                      color: textColorSecondary,
                                    ),
                                  ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // ✅ NOUVEAU : Affichage des PRÊTS et EMPRUNTS séparés
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.orange.withOpacity(0.08),
                                      Colors.orange.withOpacity(0.03),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: Colors.orange.withOpacity(0.2),
                                    width: 0.5,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.trending_up, size: 14, color: Colors.orange),
                                        const SizedBox(width: 6),
                                        Text(
                                          'PRÊTS',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.orange,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    _showTotalCard
                                        ? Text(
                                            AppSettings().formatCurrency(totalPrets),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.orange,
                                            ),
                                          )
                                        : Text(
                                            '•••••',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                              color: textColorSecondary,
                                            ),
                                          ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.purple.withOpacity(0.08),
                                      Colors.purple.withOpacity(0.03),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: Colors.purple.withOpacity(0.2),
                                    width: 0.5,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.trending_down, size: 14, color: Colors.purple),
                                        const SizedBox(width: 6),
                                        Text(
                                          'EMPRUNTS',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.purple,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    _showTotalCard
                                        ? Text(
                                            AppSettings().formatCurrency(totalEmprunts),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.purple,
                                            ),
                                          )
                                        : Text(
                                            '•••••',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                              color: textColorSecondary,
                                            ),
                                          ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // 💎 DETTES IMPAYÉES - Carte compacte
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: totalUnpaid > 0
                                  ? [
                                      Colors.red.withOpacity(0.08),
                                      Colors.red.withOpacity(0.03),
                                    ]
                                  : [
                                      Colors.green.withOpacity(0.08),
                                      Colors.green.withOpacity(0.03),
                                    ],
                            ),
                            border: Border.all(
                              color: totalUnpaid > 0
                                  ? Colors.red.withOpacity(0.2)
                                  : Colors.green.withOpacity(0.2),
                              width: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    totalUnpaid > 0
                                        ? Icons.warning_amber_rounded
                                        : Icons.check_circle_outline,
                                    size: 14,
                                    color: totalUnpaid > 0 ? Colors.red : Colors.green,
                                  ),
                                  const SizedBox(width: 9),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'IMPAYÉES',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                          letterSpacing: 0.8,
                                          color: textColorSecondary,
                                        ),
                                      ),
                                      if (totalUnpaid > 0)
                                        Text(
                                          'à recouvrer',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: textColorSecondary,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        )
                                      else
                                        Text(
                                          'tout payé',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: textColorSecondary,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              Text(
                                '$totalUnpaid',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: totalUnpaid > 0 ? Colors.red : Colors.green,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Filtre par montant
                GestureDetector(
                  onTap: () => setState(() => _showAmountFilter = !_showAmountFilter),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _showAmountFilter ? Icons.filter_list : Icons.filter_list_off,
                        size: 16,
                        color: textColorSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'FILTRER PAR MONTANT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                          color: textColorSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_showAmountFilter) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _amountMinController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: textColor, fontSize: 12),
                            onChanged: (_) => setState(() {
                              _minDebtAmount = double.tryParse(_amountMinController.text) ?? 0.0;
                            }),
                            decoration: InputDecoration(
                              hintText: 'Min',
                              hintStyle: TextStyle(color: textColorSecondary, fontSize: 11),
                              border: UnderlineInputBorder(borderSide: BorderSide(color: borderColor, width: 0.3)),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: borderColor, width: 0.3)),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: textColor, width: 0.5)),
                              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('-', style: TextStyle(color: textColorSecondary, fontSize: 14, fontWeight: FontWeight.w300)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _amountMaxController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: textColor, fontSize: 12),
                            onChanged: (_) => setState(() {
                              _maxDebtAmount = double.tryParse(_amountMaxController.text) ?? 0.0;
                            }),
                            decoration: InputDecoration(
                              hintText: 'Max',
                              hintStyle: TextStyle(color: textColorSecondary, fontSize: 11),
                              border: UnderlineInputBorder(borderSide: BorderSide(color: borderColor, width: 0.3)),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: borderColor, width: 0.3)),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: textColor, width: 0.5)),
                              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                            ),
                          ),
                        ),
                        if (_minDebtAmount > 0 || _maxDebtAmount > 0)
                          IconButton(
                            icon: Icon(Icons.clear, size: 16, color: textColorSecondary),
                            onPressed: () {
                              _amountMinController.clear();
                              _amountMaxController.clear();
                              setState(() {
                                _minDebtAmount = 0.0;
                                _maxDebtAmount = 0.0;
                              });
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'RÉCENT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: textColorSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            );
          }

          // 💎 CLIENTS À RISQUE - afficher à la fin
          if (gi == groups.length + 1) {
            if (totalUnpaid <= 0) return const SizedBox.shrink();

            return Builder(
              builder: (_) {
                // Calculer les clients avec le plus de dettes impayées
                final Map<dynamic, double> clientDebtsMap = {};
                for (final d in filteredDebts) {
                  final remaining = (d['remaining'] as double?) ?? 0.0;
                  if (remaining > 0) {
                    final cid = d['client_id'] ?? 'unknown';
                    clientDebtsMap[cid] = (clientDebtsMap[cid] ?? 0.0) + remaining;
                  }
                }

                if (clientDebtsMap.isEmpty) return const SizedBox.shrink();

                final topClients = clientDebtsMap.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                final top3 = topClients.take(3).toList();

                return Column(
                  children: [
                    Container(height: 0.5, color: borderColor, margin: const EdgeInsets.symmetric(vertical: 16)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.trending_down, size: 14, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(
                            'CLIENTS À RISQUE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                              color: textColorSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...top3.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      final cid = item.key;
                      final amount = item.value;
                      final client = clients.firstWhere((x) => x['id'] == cid, orElse: () => null);
                      final clientName = client != null ? client['name']?.toString().toUpperCase() ?? 'Client' : 'Client inconnu';

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          border: Border.all(color: Colors.red.withOpacity(0.15), width: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    clientName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '#${idx + 1} client',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: textColorSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                AppSettings().formatCurrency(amount),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 20),
                  ],
                );
              },
            );
          }

          final entry = groups[gi - 1];
          final compositeKey = entry.key.toString();
          final clientDebts = entry.value;
          final parts = compositeKey.split('|');
          final clientIdPart = parts.isNotEmpty ? parts[0] : 'unknown';
          final txType = parts.length > 1 ? parts[1] : 'debt';
          final dynamic clientId = clientIdPart == 'unknown' ? 'unknown' : (int.tryParse(clientIdPart) ?? clientIdPart);
          final client = clients.firstWhere((x) => x['id'] == clientId, orElse: () => null);
          final clientName = client != null ? client['name'] : (clientId == 'unknown' ? 'Clients inconnus' : 'Client $clientId');

          // Calculer le total : ne prendre que la dette la plus récente pour le couple (client,type)
          double totalRemaining = 0.0;
          if (clientDebts.isNotEmpty) {
            final latest = clientDebts.reduce((a, b) => _tsForDebt(b) >= _tsForDebt(a) ? b : a);
            totalRemaining = ((latest['remaining'] as num?)?.toDouble() ?? 0.0);
          }

          final bool isOpen = _expandedClients.contains(compositeKey);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border(bottom: BorderSide(color: borderColor, width: 0.3)),
              borderRadius: BorderRadius.circular(0),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () {
                    if (clientDebts.isNotEmpty) {
                      showDebtDetails(clientDebts.first);
                    }
                  },
                  onLongPress: () => _showClientActions(client, clientId),
                  borderRadius: BorderRadius.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
                    child: Row(
                      children: [
                        // Avatar styled like DebtDetailsPage
                        Padding(
                          padding: const EdgeInsets.only(left: 0),
                          child: _buildClientAvatarWidget(client, 44),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                clientName.toString().toUpperCase(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              if (client != null && (client['client_number'] ?? '').toString().isNotEmpty)
                                const SizedBox(height: 4),
                              if (client != null && (client['client_number'] ?? '').toString().isNotEmpty)
                                Text(
                                  client['client_number'].toString(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textColorSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // ✅ MODIFIÉ : Distinction emprunts/dettes
                            Builder(builder: (_) {
                              final bool clientOwe = totalRemaining < 0;
                              final bool isLoan = txType == 'loan'; // Vérifier le type par composant
                              
                              return Text(
                                isLoan ? 'JE DOIS' : (clientOwe ? 'JE DOIS' : 'À PERCEVOIR'),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: textColorSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            }),
                            const SizedBox(height: 2),
                            // ✅ MODIFIÉ : Affichage montant pour emprunts
                            Builder(
                              builder: (_) {
                                final bool clientOwe = totalRemaining < 0;
                                final bool isLoan = clientDebts.isNotEmpty && clientDebts.first['type'] == 'loan'; // ✅ Vérifier le type
                                final display = isLoan || clientOwe
                                    ? AppSettings().formatCurrency(totalRemaining.abs())
                                    : AppSettings().formatCurrency(totalRemaining);
                                final Color col = isLoan || clientOwe
                                    ? const Color.fromARGB(231, 141, 47, 219) // Violet pour les emprunts
                                    : (totalRemaining > 0 ? const Color.fromARGB(224, 219, 132, 2) : Colors.green);

                                return Text(
                                  display,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: col,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                        const SizedBox(width: 12),
                        // ✅ MODIFIÉ : PopupMenuButton avec option emprunt
                        PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'payment') {
                              if (clientDebts.isNotEmpty) {
                                final res = await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AddPaymentPage(
                                      ownerPhone: widget.ownerPhone,
                                      debt: clientDebts.first,
                                    ),
                                  ),
                                );
                                if (res == true) {
                                  await fetchDebts();
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Aucune dette trouvée')),
                                );
                              }
                            } else if (v == 'debt') {
                              if (client != null) {
                                final res = await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AddDebtPage(
                                      ownerPhone: widget.ownerPhone,
                                      clients: clients,
                                      preselectedClientId: client['id'],
                                    ),
                                  ),
                                );
                                if (res == true) {
                                  await fetchDebts();
                                  setState(() {
                                    final comp = '${client['id'].toString()}|debt';
                                    _expandedClients.add(comp);
                                  });
                                }
                              }
                            } else if (v == 'loan') {
                              // ✅ NOUVEAU : Créer un emprunt
                              final result = await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => AddLoanPage(
                                    ownerPhone: widget.ownerPhone,
                                    clients: clients,
                                  ),
                                ),
                              );
                              if (result == true) {
                                await fetchDebts();
                                setState(() {
                                  final comp = '${client['id'].toString()}|loan';
                                  _expandedClients.add(comp);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Emprunt créé')),
                                );
                              }
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem<String>(
                              value: 'payment',
                              child: Row(
                                children: [
                                  const Icon(Icons.monetization_on_outlined, size: 18, color: Colors.green),
                                  const SizedBox(width: 8),
                                  Text('Ajouter paiement', style: TextStyle(color: textColor)),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'debt',
                              child: Row(
                                children: [
                                  const Icon(Icons.add, size: 18, color: Colors.orange),
                                  const SizedBox(width: 8),
                                  Text('Créer une dette', style: TextStyle(color: textColor)),
                                ],
                              ),
                            ),
                            // ✅ NOUVEAU : Option emprunt
                            PopupMenuItem<String>(
                              value: 'loan',
                              child: Row(
                                children: [
                                  const Icon(Icons.account_balance_wallet, size: 18, color: Color.fromARGB(255, 141, 47, 219)),
                                  const SizedBox(width: 8),
                                  Text('Créer un emprunt', style: TextStyle(color: textColor)),
                                ],
                              ),
                            ),
                          ],
                          offset: const Offset(0, 40),
                          child: Icon(Icons.more_vert, color: textColor, size: 16),
                        ),
                        AnimatedRotation(
                          turns: isOpen ? 0.25 : 0.0,
                          duration: const Duration(milliseconds: 200),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isOpen)
                  Column(
                    children: [
                      Container(height: 0.5, color: borderColor),
                      ...clientDebts.map<Widget>((d) {
                        // ✅ CORRIGÉ : Utiliser les calculs corrects
                        final totalDebt = (d['total_debt'] as double?) ?? 0.0;
                        final remaining = (d['remaining'] as double?) ?? 0.0;
                        final bool isPaid = d['paid'] == true || remaining <= 0;

                        String dueText = '-';
                        bool isOverdue = false;
                        DateTime? dueDateTime;
                        try {
                          if (d != null && d['due_date'] != null) {
                            dueDateTime = DateTime.parse(d['due_date']);
                            dueText = DateFormat('dd/MM/yyyy').format(dueDateTime);
                            isOverdue = dueDateTime.isBefore(DateTime.now()) && !isPaid;
                          }
                        } catch (_) {}

                        final statusColor = isPaid ? Colors.green : (isOverdue ? Colors.red : Colors.green);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 1),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            border: Border(
                              bottom: BorderSide(color: borderColor, width: 0.3),
                            ),
                            borderRadius: BorderRadius.zero,
                          ),
                          child: InkWell(
                            onTap: () => showDebtDetails(d),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppSettings().formatCurrency(totalDebt),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Échéance: $dueText',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isOverdue ? Colors.red : textColorSecondary,
                                            fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Builder(builder: (_) {
                                        final bool isOwe = remaining < 0;
                                        final bool isLoan = d['type'] == 'loan'; // ✅ Vérifier le type
                                        return Text(
                                          isLoan ? 'JE DOIS' : (isOwe ? 'JE DOIS' : 'RESTE'),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: textColorSecondary,
                                          ),
                                        );
                                      }),
                                      const SizedBox(height: 4),
                                      Builder(builder: (_) {
                                        final bool isOwe = remaining < 0;
                                        final bool isLoan = d['type'] == 'loan'; // ✅ Vérifier le type
                                        final display = isLoan || isOwe
                                            ? AppSettings().formatCurrency(remaining.abs())
                                            : AppSettings().formatCurrency(remaining);
                                        final Color col = isLoan || isOwe
                                            ? const Color.fromARGB(231, 141, 47, 219)
                                            : (remaining <= 0 ? Colors.green : (isOverdue ? Colors.red : textColor));

                                        return Text(
                                          display,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: col,
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(
                                    isPaid ? Icons.check_circle : (isOverdue ? Icons.error : Icons.circle),
                                    color: statusColor,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildClientsTab() {
    final filtered = clients.where((c) {
      if (_searchQuery.isEmpty) return true;
      final name = (c['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    filtered.sort((a, b) {
      final ra = _clientTotalRemaining(a['id']);
      final rb = _clientTotalRemaining(b['id']);
      final sa = ra > 0 ? 0 : 1;
      final sb = rb > 0 ? 0 : 1;
      if (sa != sb) return sa - sb;
      return a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase());
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final textColorSecondary = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? Colors.white24 : Colors.black26;

    return RefreshIndicator(
      onRefresh: () async => await fetchClients(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filtered.length,
        itemBuilder: (ctx, i) {
          final c = filtered[i];
          final totalRemaining = _clientTotalRemaining(c['id']);
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
              border: Border.all(color: borderColor, width: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
              leading: _buildClientAvatarWidget(c, 40),
              title: Text(
                c['name'].toString().toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              subtitle: Text(
                c['client_number'] ?? '-',
                style: TextStyle(
                  fontSize: 12,
                  color: textColorSecondary,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Builder(builder: (_) {
                        final bool clientOwe = totalRemaining < 0;
                        final clientDebts = debts.where((d) => d['client_id'] == c['id']).toList();
                        final bool isLoan = clientDebts.isNotEmpty && clientDebts.first['type'] == 'loan'; // ✅ Vérifier le type
                        
                        return Text(
                          isLoan ? 'JE DOIS' : (clientOwe ? 'JE DOIS' : 'À PERCEVOIR'),
                          style: TextStyle(
                            fontSize: 10,
                            color: textColorSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }),
                      const SizedBox(height: 2),
                      Builder(builder: (_) {
                        final bool clientOwe = totalRemaining < 0;
                        final clientDebts = debts.where((d) => d['client_id'] == c['id']).toList();
                        final bool isLoan = clientDebts.isNotEmpty && clientDebts.first['type'] == 'loan'; // ✅ Vérifier le type
                        final display = isLoan || clientOwe
                            ? AppSettings().formatCurrency(totalRemaining.abs())
                            : AppSettings().formatCurrency(totalRemaining);
                        final Color col = isLoan || clientOwe
                            ? const Color.fromARGB(231, 141, 47, 219)
                            : (totalRemaining > 0 ? Colors.orange : Colors.green);
                        return Text(
                          display,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: col,
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(width: 12),
                  PopupMenuButton<String>(
                    constraints: const BoxConstraints(maxWidth: 200),
                    onSelected: (v) async {
                      if (v == 'payment') {
                        final debtWithClient = debts.firstWhere(
                          (d) => d['client_id'] == c['id'],
                          orElse: () => null,
                        );
                        if (debtWithClient != null) {
                          final res = await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AddPaymentPage(
                                ownerPhone: widget.ownerPhone,
                                debt: debtWithClient,
                              ),
                            ),
                          );
                          if (res == true) {
                            await fetchDebts();
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Aucune dette trouvée pour ce client')),
                          );
                        }
                      } else if (v == 'debt') {
                        final res = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AddDebtPage(
                              ownerPhone: widget.ownerPhone,
                              clients: clients,
                              preselectedClientId: c['id'],
                            ),
                          ),
                        );
                        if (res == true) {
                          await fetchDebts();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Dette ajoutée')),
                          );
                        }
                      } else if (v == 'loan') {
                        // ✅ NOUVEAU : Créer un emprunt
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AddLoanPage(
                              ownerPhone: widget.ownerPhone,
                              clients: clients,
                            ),
                          ),
                        );
                        if (result == true) {
                          await fetchDebts();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Emprunt créé')),
                          );
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: 'payment',
                        child: Row(
                          children: [
                            const Icon(Icons.monetization_on_outlined, size: 18, color: Colors.green),
                            const SizedBox(width: 8),
                            Text('Ajouter paiement', style: TextStyle(color: textColor)),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'debt',
                        child: Row(
                          children: [
                            const Icon(Icons.add, size: 18, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text('Créer une dette', style: TextStyle(color: textColor)),
                          ],
                        ),
                      ),
                      // ✅ NOUVEAU : Option emprunt
                      PopupMenuItem<String>(
                        value: 'loan',
                        child: Row(
                          children: [
                            const Icon(Icons.account_balance_wallet, size: 18, color: Color.fromARGB(255, 141, 47, 219)),
                            const SizedBox(width: 8),
                            Text('Créer un emprunt', style: TextStyle(color: textColor)),
                          ],
                        ),
                      ),
                    ],
                    offset: const Offset(0, 40),
                    child: Icon(Icons.more_vert, color: textColor, size: 16),
                  ),
              ],
            ),
              onTap: () => _showClientActions(c, c['id']),
              onLongPress: () async {
                final num = c['client_number'] ?? '';
                if (num != null && num.toString().isNotEmpty) {
                  await Clipboard.setData(ClipboardData(text: num.toString()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Numéro copié: $num')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Aucun numéro à copier')),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final textColorSecondary = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(_isSearching ? 130 : 60),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.orange.withOpacity(0.08),
                Colors.orange.withOpacity(0.04),
                const Color.fromARGB(255, 167, 139, 250).withOpacity(0.05),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: Colors.orange.withOpacity(0.1),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top action row
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Mode boutique OR Avatar utilisateur
                      if (AppSettings().boutiqueModeEnabled)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.store,
                            size: 18,
                            color: Colors.orange,
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 18,
                            color: Colors.orange,
                          ),
                        ),
                      // Title avec accent
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (AppSettings().boutiqueModeEnabled)
                              Text(
                                AppSettings().boutiqueModeEnabled
                                    ? (boutiqueName.isNotEmpty 
                                        ? boutiqueName.toUpperCase()
                                        : (widget.ownerShopName ?? 'Gestion de dettes').toUpperCase())
                                    : ('${AppSettings().firstName ?? ''} ${AppSettings().lastName ?? ''}').isNotEmpty
                                        ? ('${AppSettings().firstName ?? ''} ${AppSettings().lastName ?? ''}').toUpperCase()
                                        : 'Utilisateur',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: textColor,
                                  letterSpacing: 0.3,
                                  height: 1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Actions
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              _isSearching ? Icons.close : Icons.search,
                              size: 18,
                              color: Colors.orange,
                            ),
                            onPressed: () {
                              setState(() {
                                _isSearching = !_isSearching;
                                if (!_isSearching) {
                                  _searchController.clear();
                                  _searchQuery = '';
                                  fetchClients();
                                  fetchDebts();
                                } else {
                                  Future.delayed(
                                    const Duration(milliseconds: 80),
                                    () => FocusScope.of(context).requestFocus(_searchFocus),
                                  );
                                }
                              });
                            },
                            splashRadius: 20,
                            padding: const EdgeInsets.all(6),
                          ),
                          IconButton(
                            onPressed: _isSyncing ? null : () async => await _triggerSync(),
                            icon: _isSyncing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(Colors.orange),
                                    ),
                                  )
                                : const Icon(
                                    Icons.sync,
                                    size: 18,
                                    color: Colors.orange,
                                  ),
                            splashRadius: 20,
                            padding: const EdgeInsets.all(6),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'logout') widget.onLogout();
                              if (v == 'team') Navigator.of(context).push(MaterialPageRoute(builder: (_) => TeamScreen(ownerPhone: widget.ownerPhone)));
                              if (v == 'settings') await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsScreen(debts: debts, clients: clients)));
                              if (v == 'theme') AppSettings().setLightMode(!AppSettings().lightMode);
                            },
                            itemBuilder: (c) => [
                              PopupMenuItem(
                                value: 'theme',
                                child: Row(
                                  children: [
                                    Icon(
                                      AppSettings().lightMode ? Icons.dark_mode : Icons.light_mode,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(AppSettings().lightMode ? 'Mode sombre' : 'Mode clair'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(value: 'team', child: Text('Équipe')),
                              const PopupMenuItem(value: 'settings', child: Text('Paramètres')),
                              const PopupMenuItem(value: 'logout', child: Text('Déconnexion')),
                            ],
                            icon: const Icon(
                              Icons.more_vert,
                              size: 18,
                              color: Colors.orange,
                            ),
                            offset: const Offset(0, 40),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Search bar si actif
                if (_isSearching)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.08),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.2),
                          width: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: TextField(
                        focusNode: _searchFocus,
                        controller: _searchController,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Rechercher un client...',
                          hintStyle: TextStyle(
                            color: textColorSecondary,
                            fontSize: 12,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 0,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            size: 18,
                            color: Colors.orange.withOpacity(0.6),
                          ),
                        ),
                        textInputAction: TextInputAction.search,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: _tabIndex == 0 ? _buildDebtsTab() : _buildClientsTab(),
      bottomNavigationBar: Builder(
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final textColor = isDark ? Colors.white : Colors.black;
          final textColorSecondary = isDark ? Colors.white70 : Colors.black54;
          final borderColor = isDark ? Colors.white24 : Colors.black26;
          
          return Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: borderColor, width: 0.3)),
              color: Colors.transparent,
            ),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left tab: Dettes
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() => _tabIndex = 0);
                        if (_searchQuery.isNotEmpty) fetchDebts(query: _searchQuery);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.trending_down, size: 20, color: _tabIndex == 0 ? textColor : textColorSecondary),
                          const SizedBox(height: 4),
                          Text('DETTES', style: TextStyle(fontSize: 11, color: _tabIndex == 0 ? textColor : textColorSecondary)),
                        ],
                      ),
                    ),
                  ),

                  // Center slim circular + button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () async {
                          await _showAddChoice();
                        },
                        style: ElevatedButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(0),
                          elevation: 2,
                          backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                          foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                        ),
                        child: const Icon(Icons.add, size: 28),
                      ),
                    ),
                  ),

                  // Right tab: Clients
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() => _tabIndex = 1);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people, size: 20, color: _tabIndex == 1 ? textColor : textColorSecondary),
                          const SizedBox(height: 4),
                          Text('CLIENTS', style: TextStyle(fontSize: 11, color: _tabIndex == 1 ? textColor : textColorSecondary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}