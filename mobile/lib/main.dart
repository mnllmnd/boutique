import 'package:boutique_mobile/add_payment_page.dart';
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
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'data/sync_service.dart';
import 'team_screen.dart';
import 'app_settings.dart';
import 'settings_screen.dart';
import 'login_page.dart';
import 'add_debt_page.dart';
import 'add_client_page.dart';
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
    if (v is num) return '${v.toStringAsFixed(0)} FCFA';
    final parsed = num.tryParse(v.toString());
    if (parsed == null) return '${v.toString()} FCFA';
    return '${parsed.toStringAsFixed(0)} FCFA';
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
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

  Future setOwner({required String phone, String? shopName, int? id, String? firstName, String? lastName}) async {
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
          ? LoginPage(onLogin: (phone, shop, id, firstName, lastName) => setOwner(phone: phone, shopName: shop, id: id, firstName: firstName, lastName: lastName))
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
  final TextEditingController _searchController = TextEditingController();
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final avatar = client != null ? (client['avatar_url'] ?? '') : '';
        final name = client != null ? (client['name'] ?? 'Client') : 'Client';
        final number = client != null ? (client['client_number'] ?? '') : '';
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : Colors.black;
        final textColorSecondary = isDark ? Colors.white70 : Colors.black54;
        
        return DraggableScrollableSheet(
          initialChildSize: 0.36,
          minChildSize: 0.2,
          maxChildSize: 0.9,
          builder: (context2, sc) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context2).cardColor,
              ),
              child: SingleChildScrollView(
                controller: sc,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: textColorSecondary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Theme.of(context2).brightness == Brightness.light ? Colors.grey[300] : Colors.grey[900],
                            ),
                            child: avatar != null && avatar != ''
                                ? CachedNetworkImage(imageUrl: avatar, fit: BoxFit.cover)
                                : Icon(Icons.person, color: textColorSecondary, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name.toString(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                                if (number != null && number.toString().isNotEmpty) 
                                  const SizedBox(height: 6),
                                if (number != null && number.toString().isNotEmpty)
                                  Text(
                                    number.toString(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: textColorSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    Container(height: 0.5, color: Theme.of(context2).dividerColor),
                    // Actions
                    ListTile(
                      leading: Icon(Icons.add_circle, color: Theme.of(context2).colorScheme.primary),
                      title: Text('Ajouter une dette', style: TextStyle(color: textColor)),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        dynamic c = client;
                        if (c == null && clientId != null) {
                          c = clients.firstWhere((x) => x['id'] == clientId, orElse: () => null);
                        }
                        if (c != null) await _addDebtForClient(c);
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.copy, color: textColorSecondary),
                      title: Text('Copier numéro', style: TextStyle(color: textColor)),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        final num = client != null ? client['client_number'] ?? '' : '';
                        if (num != null && num.toString().isNotEmpty) {
                          await Clipboard.setData(ClipboardData(text: num.toString()));
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Numéro copié: $num')),
                            );
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Aucun numéro à copier')),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
                    child: Text(
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
                    child: Text(
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
                    child: Text(
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
        final body = {
          'client_id': c['id'],
          'amount': double.tryParse(amountCtl.text) ?? 0.0,
          'due_date': due == null ? null : DateFormat('yyyy-MM-dd').format(due!),
          'notes': notesCtl.text,
        };
        final headers = {
          'Content-Type': 'application/json',
          if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone
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
              if (c != null && c['id'] != null) _expandedClients.add(c['id']);
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
      } catch (e) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Erreur'),
            content: Text('Erreur création dette: $e'),
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

  Future fetchDebts({String? query}) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone
      };
      final res = await http.get(
        Uri.parse('$apiHost/debts'),
        headers: headers,
      ).timeout(const Duration(seconds: 8));
      
      if (res.statusCode == 200) {
        final list = json.decode(res.body) as List;
        if (query != null && query.isNotEmpty) {
          setState(() => debts = list.where((d) {
            final clientName = _clientNameForDebt(d)?.toLowerCase() ?? '';
            return clientName.contains(query.toLowerCase());
          }).toList());
        } else {
          setState(() => debts = list);
        }
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

  double _clientTotalRemaining(dynamic clientId) {
    double total = 0.0;
    for (final d in debts) {
      if (d == null) continue;
      if (d['client_id'] != clientId) continue;
      final amt = double.tryParse(d['amount']?.toString() ?? '0') ?? 0.0;
      double rem = amt;
      try {
        if (d != null && d['remaining'] != null) {
          rem = double.tryParse(d['remaining'].toString()) ?? rem;
        } else if (d != null && d['total_paid'] != null) {
          rem = amt - (double.tryParse(d['total_paid'].toString()) ?? 0.0);
        }
      } catch (_) {}
      total += rem;
    }
    return total;
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

  Future createDebt() async {
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
          await createDebt();
        }
      }
      return;
    }
    
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
        const SnackBar(content: Text('Dette ajoutée')),
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
    final Map<dynamic, List> grouped = {};
    for (final d in debts) {
      final key = d != null && d['client_id'] != null ? d['client_id'] : 'unknown';
      if (!grouped.containsKey(key)) grouped[key] = [];
      grouped[key]!.add(d);
    }

    final groups = grouped.entries.toList();
    groups.sort((a, b) {
      double sumRem(List list) {
        double tot = 0.0;
        for (final d in list) {
          final amt = double.tryParse(d['amount']?.toString() ?? '0') ?? 0.0;
          double rem = amt;
          try {
            if (d != null && d['remaining'] != null) {
              rem = double.tryParse(d['remaining'].toString()) ?? rem;
            } else if (d != null && d['total_paid'] != null) {
              rem = amt - (double.tryParse(d['total_paid'].toString()) ?? 0.0);
            }
          } catch (_) {}
          tot += rem;
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

    double totalToCollect = 0.0;
    int totalUnpaid = 0;
    for (final d in debts) {
      final amt = double.tryParse(d['amount']?.toString() ?? '0') ?? 0.0;
      double rem = amt;
      try {
        if (d != null && d['remaining'] != null) {
          rem = double.tryParse(d['remaining'].toString()) ?? rem;
        } else if (d != null && d['total_paid'] != null) {
          rem = amt - (double.tryParse(d['total_paid'].toString()) ?? 0.0);
        }
      } catch (_) {}
      totalToCollect += rem;
      if (rem > 0) totalUnpaid++;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final textColorSecondary = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? Colors.white24 : Colors.black26;

    return RefreshIndicator(
      onRefresh: () async => await fetchDebts(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        itemCount: groups.length + 1,
        itemBuilder: (ctx, gi) {
          if (gi == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.04) : const Color.fromARGB(189, 43, 31, 48).withOpacity(0.02),
                    border: Border.all(color: borderColor, width: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOTAL À PERCEVOIR',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                                color: textColorSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _showTotalCard
                                      ? Text(
                                          AppSettings().formatCurrency(totalToCollect),
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w300,
                                            color: textColor,
                                          ),
                                        )
                                      : Text(
                                          '••••••',
                                          style: TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w300,
                                            color: textColorSecondary,
                                          ),
                                        ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() => _showTotalCard = !_showTotalCard),
                                  child: Icon(
                                    _showTotalCard ? Icons.visibility : Icons.visibility_off,
                                    color: textColorSecondary,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(height: 0.5, color: borderColor),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Text(
                                  'DETTES IMPAYÉES',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.5,
                                    color: textColorSecondary,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: totalUnpaid > 0 ? const Color.fromARGB(255, 205, 59, 48).withOpacity(0.15) : Colors.green.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(
                                      color: totalUnpaid > 0 ? const Color.fromARGB(73, 189, 53, 43) : const Color.fromARGB(63, 76, 175, 79),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        totalUnpaid > 0 ? '' : '✓',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '$totalUnpaid',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: totalUnpaid > 0 ? const Color.fromARGB(255, 197, 54, 44) : const Color.fromARGB(255, 37, 125, 40),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(height: 0.5, color: borderColor),
                      Row(
                        children: [
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () async {
                                  final newId = await createClient();
                                  if (newId != null) {
                                    await fetchClients();
                                    await fetchDebts();
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.person_add, size: 18, color: textColor),
                                      const SizedBox(width: 8),
                                      Text(
                                        'CLIENT',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1,
                                          color: textColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Container(width: 0.5, color: borderColor),
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () async {
                                  final res = await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AddDebtPage(
                                        ownerPhone: widget.ownerPhone,
                                        clients: clients,
                                        preselectedClientId: null,
                                      ),
                                    ),
                                  );
                                  if (res == true) {
                                    await fetchDebts();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Dette ajoutée')),
                                    );
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_circle, size: 18, color: textColor),
                                      const SizedBox(width: 8),
                                      Text(
                                        'DETTE',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1,
                                          color: textColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RÉCENT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: textColorSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 40,
                        height: 2,
                        decoration: BoxDecoration(
                          color: textColor,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            );
          }

          final entry = groups[gi - 1];
          final cid = entry.key;
          final clientDebts = entry.value;
          final client = clients.firstWhere((x) => x['id'] == cid, orElse: () => null);
          final clientName = client != null ? client['name'] : (cid == 'unknown' ? 'Clients inconnus' : 'Client $cid');
          final avatarUrl = client != null ? client['avatar_url'] : null;

          double totalRemaining = 0.0;
          for (final d in clientDebts) {
            final amt = double.tryParse(d['amount']?.toString() ?? '0') ?? 0.0;
            double rem = amt;
            try {
              if (d != null && d['remaining'] != null) {
                rem = double.tryParse(d['remaining'].toString()) ?? rem;
              } else if (d != null && d['total_paid'] != null) {
                rem = amt - (double.tryParse(d['total_paid'].toString()) ?? 0.0);
              }
            } catch (_) {}
            totalRemaining += rem;
          }

          int unpaidCount = 0;
          for (final d in clientDebts) {
            final amt2 = double.tryParse(d['amount']?.toString() ?? '0') ?? 0.0;
            double rem2 = amt2;
            try {
              if (d != null && d['remaining'] != null) {
                rem2 = double.tryParse(d['remaining'].toString()) ?? rem2;
              } else if (d != null && d['total_paid'] != null) {
                rem2 = amt2 - (double.tryParse(d['total_paid'].toString()) ?? 0.0);
              }
            } catch (_) {}
            if (rem2 > 0) unpaidCount++;
          }

          final bool isOpen = _expandedClients.contains(cid);
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
              border: Border.all(color: borderColor, width: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () => setState(() {
                    if (isOpen) {
                      _expandedClients.remove(cid);
                    } else {
                      _expandedClients.add(cid);
                    }
                  }),
                  onLongPress: () => _showClientActions(client, cid),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.light ? Colors.grey[100] : Colors.grey[900],
                          ),
                          child: avatarUrl != null && avatarUrl != ''
                              ? CachedNetworkImage(
                                  imageUrl: avatarUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) => Icon(
                                    Icons.person_outline,
                                    color: textColorSecondary,
                                    size: 20,
                                  ),
                                )
                              : Icon(
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
                            Text(
                              AppSettings().formatCurrency(totalRemaining),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: totalRemaining > 0 ? const Color.fromARGB(224, 219, 132, 2) : Colors.green,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: unpaidCount > 0 ? const Color.fromARGB(211, 155, 37, 29).withOpacity(0.15) : Colors.green.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(
                                  color: unpaidCount > 0 ? const Color.fromARGB(57, 244, 67, 54) : Colors.green,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    unpaidCount > 0 ? '' : '✓',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$unpaidCount dette${unpaidCount > 1 ? 's' : ''}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: unpaidCount > 0 ? Colors.red : Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
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
                                    _expandedClients.add(client['id']);
                                  });
                                }
                              }
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem<String>(
                              value: 'payment',
                              child: Row(
                                children: [
                                  Icon(Icons.monetization_on_outlined, size: 18, color: Colors.green),
                                  const SizedBox(width: 8),
                                  Text('Ajouter paiement', style: TextStyle(color: textColor)),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'debt',
                              child: Row(
                                children: [
                                  Icon(Icons.add_circle, size: 18, color: Colors.orange),
                                  const SizedBox(width: 8),
                                  Text('Ajouter dette', style: TextStyle(color: textColor)),
                                ],
                              ),
                            ),
                          ],
                          offset: const Offset(0, 40),
                          child: Icon(Icons.more_vert, color: textColor, size: 20),
                        ),
                        AnimatedRotation(
                          turns: isOpen ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(Icons.expand_more, color: textColorSecondary),
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
                        final amountVal = double.tryParse(d['amount']?.toString() ?? '0') ?? 0.0;
                        double remainingVal = amountVal;
                        try {
                          if (d != null && d['remaining'] != null) {
                            remainingVal = double.tryParse(d['remaining'].toString()) ?? remainingVal;
                          } else if (d != null && d['total_paid'] != null) {
                            remainingVal = amountVal - (double.tryParse(d['total_paid'].toString()) ?? 0.0);
                          }
                        } catch (_) {}
                        final bool isPaid = d['paid'] == true || remainingVal <= 0;

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
                        final statusBgColor = isPaid ? Colors.green.withOpacity(0.1) : (isOverdue ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1));

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBgColor,
                            border: Border(
                              left: BorderSide(color: statusColor, width: 3),
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: InkWell(
                            onTap: () => showDebtDetails(d),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppSettings().formatCurrency(d['amount']),
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
                                      Text(
                                        'RESTE',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: textColorSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        AppSettings().formatCurrency(remainingVal),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isPaid ? Colors.green : (isOverdue ? Colors.red : textColor),
                                        ),
                                      ),
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
        padding: const EdgeInsets.all(20),
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
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.light ? Colors.grey[100] : Colors.grey[900],
                ),
                child: c['avatar_url'] != null && c['avatar_url'] != ''
                    ? CachedNetworkImage(
                        imageUrl: c['avatar_url'],
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Icon(
                          Icons.person_outline,
                          color: textColorSecondary,
                          size: 20,
                        ),
                      )
                    : Icon(
                        Icons.person_outline,
                        color: textColorSecondary,
                        size: 20,
                      ),
              ),
              title: Text(
                c['name'].toString().toUpperCase(),
                style: TextStyle(
                  fontSize: 14,
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
                      Text(
                        'À percevoir',
                        style: TextStyle(
                          fontSize: 10,
                          color: textColorSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppSettings().formatCurrency(totalRemaining),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: totalRemaining > 0 ? Colors.orange : Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  PopupMenuButton<String>(
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
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: 'payment',
                        child: Row(
                          children: [
                            Icon(Icons.monetization_on_outlined, size: 18, color: Colors.green),
                            const SizedBox(width: 8),
                            Text('Ajouter paiement', style: TextStyle(color: textColor)),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'debt',
                        child: Row(
                          children: [
                            Icon(Icons.add_circle, size: 18, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text('Ajouter dette', style: TextStyle(color: textColor)),
                          ],
                        ),
                      ),
                    ],
                    offset: const Offset(0, 40),
                    child: Icon(Icons.more_vert, color: textColor, size: 20),
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
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.store, size: 24),
          onPressed: () {},
        ),
        title: _isSearching
            ? SizedBox(
                height: 40,
                child: TextField(
                  focusNode: _searchFocus,
                  controller: _searchController,
                  style: TextStyle(color: textColor, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Rechercher...',
                    hintStyle: TextStyle(color: textColorSecondary),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  textInputAction: TextInputAction.search,
                ),
              )
            : Text(
                boutiqueName.isNotEmpty 
                  ? boutiqueName 
                  : (widget.ownerShopName ?? 'Gestion de dettes'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, size: 20),
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
          ),
          IconButton(
            onPressed: _isSyncing ? null : () async => await _triggerSync(),
            icon: _isSyncing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync, size: 20),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'logout') widget.onLogout();
              if (v == 'team') Navigator.of(context).push(MaterialPageRoute(builder: (_) => TeamScreen(ownerPhone: widget.ownerPhone)));
              if (v == 'settings') await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
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
          ),
        ],
      ),
      body: _tabIndex == 0 ? _buildDebtsTab() : _buildClientsTab(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: BottomNavigationBar(
          currentIndex: _tabIndex,
          onTap: (i) {
            setState(() => _tabIndex = i);
            if (i == 0 && _searchQuery.isNotEmpty) fetchDebts(query: _searchQuery);
          },
          backgroundColor: Theme.of(context).cardColor,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: textColorSecondary,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.list, size: 20),
              label: 'DETTES',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people, size: 20),
              label: 'CLIENTS',
            ),
          ],
        ),
      ),
    );
  }
}