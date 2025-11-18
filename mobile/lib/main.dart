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
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? ownerPhone;
  String? ownerShopName;
  int? ownerId;
  late AppSettings _appSettings;

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

// Login / Register pages moved to `login_page.dart` to keep main.dart small.

class HomePage extends StatefulWidget {
  final String ownerPhone;
  final String? ownerShopName;
  final VoidCallback onLogout;

  HomePage({required this.ownerPhone, this.ownerShopName, required this.onLogout});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tabIndex = 0; // 0: Debts, 1: Clients

  List debts = [];
  List clients = [];
  String _searchQuery = '';
  bool _isSearching = false;
  bool _showTotalCard = true; // Toggle for total card visibility
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounceTimer;
  // track which client groups are expanded
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
        // debounce network calls
        if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
        _debounceTimer = Timer(Duration(milliseconds: 400), () {
          if (_tabIndex == 0) {
            fetchDebts(query: _searchQuery);
          } else {
            setState(() {});
          }
        });
      }
    });
    // Initialize settings for current owner so formatting uses correct locale/currency
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
        return DraggableScrollableSheet(
          initialChildSize: 0.36,
          minChildSize: 0.2,
          maxChildSize: 0.9,
          builder: (context2, sc) {
            return Container(
              decoration: BoxDecoration(color: Theme.of(context2).cardColor, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
              child: SingleChildScrollView(
                controller: sc,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // handle
                    Center(child: Container(width: 40, height: 4, margin: EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Theme.of(context2).textTheme.bodyMedium?.color?.withOpacity(0.2), borderRadius: BorderRadius.circular(4)))),
                    // header with avatar + name + number
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(color: Theme.of(context2).brightness == Brightness.light ? Colors.grey[300] : Colors.grey[900], borderRadius: BorderRadius.circular(8)),
                            child: avatar != null && avatar != ''
                                ? ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: avatar, fit: BoxFit.cover))
                                : Icon(Icons.person, color: Theme.of(context2).textTheme.bodyMedium?.color, size: 36),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(name.toString(), style: TextStyle(color: Theme.of(context2).textTheme.titleLarge?.color, fontSize: 16, fontWeight: FontWeight.w800)),
                              if (number != null && number.toString().isNotEmpty) SizedBox(height: 6),
                              if (number != null && number.toString().isNotEmpty) Text(number.toString(), style: TextStyle(color: Theme.of(context2).textTheme.bodyMedium?.color)),
                            ]),
                          )
                        ],
                      ),
                    ),
                    Divider(color: Theme.of(context2).dividerColor),
                    ListTile(
                      leading: Icon(Icons.add_circle, color: Theme.of(context2).colorScheme.primary),
                      title: Text('Ajouter une dette', style: TextStyle(color: Theme.of(context2).textTheme.bodyLarge?.color)),
                      subtitle: Text('Ajouter une dette pour ce client', style: TextStyle(color: Theme.of(context2).textTheme.bodyMedium?.color)),
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
                      leading: Icon(Icons.copy, color: Theme.of(context2).textTheme.bodyMedium?.color),
                      title: Text('Copier numéro', style: TextStyle(color: Theme.of(context2).textTheme.bodyLarge?.color)),
                      subtitle: Text('Copier le numéro du client', style: TextStyle(color: Theme.of(context2).textTheme.bodyMedium?.color)),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        final num = client != null ? client['client_number'] ?? '' : '';
                        if (num != null && num.toString().isNotEmpty) {
                          await Clipboard.setData(ClipboardData(text: num.toString()));
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Numéro copié: $num')));
                        } else {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Aucun numéro à copier')));
                        }
                      },
                    ),
                    SizedBox(height: 12),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (dlg) => AlertDialog(
        title: Text('Ajouter dette pour ${c['name'] ?? 'client'}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: amountCtl, decoration: InputDecoration(labelText: 'Montant'), keyboardType: TextInputType.number),
              SizedBox(height: 8),
              Row(children: [
                Expanded(child: Text(due == null ? 'Échéance: -' : 'Échéance: ${DateFormat('dd/MM/yyyy').format(due!)}')),
                TextButton(onPressed: () async { final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100)); if (d!=null) { due = d; } setState((){}); }, child: Text('Choisir'))
              ]),
              TextField(controller: notesCtl, decoration: InputDecoration(labelText: 'Notes')),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(dlg).pop(false), child: Text('Annuler')), ElevatedButton(onPressed: () => Navigator.of(dlg).pop(true), child: Text('Ajouter'))],
      ),
    );

    if (ok == true && amountCtl.text.trim().isNotEmpty) {
      try {
        final body = {'client_id': c['id'], 'amount': double.tryParse(amountCtl.text) ?? 0.0, 'due_date': due == null ? null : DateFormat('yyyy-MM-dd').format(due!), 'notes': notesCtl.text};
        final headers = {'Content-Type': 'application/json', if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone};
        final res = await http.post(Uri.parse('$apiHost/debts'), headers: headers, body: json.encode(body)).timeout(Duration(seconds: 8));
        if (res.statusCode == 201) {
          await fetchDebts();
          if (mounted) {
            setState(() { if (c != null && c['id'] != null) _expandedClients.add(c['id']); });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dette ajoutée')));
          }
        } else {
          await showDialog(context: context, builder: (ctx) => AlertDialog(title: Text('Erreur'), content: Text('Échec création dette: ${res.statusCode}\n${res.body}'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('OK'))]));
        }
      } catch (e) {
        await showDialog(context: context, builder: (ctx) => AlertDialog(title: Text('Erreur'), content: Text('Erreur création dette: $e'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('OK'))]));
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Synchronisation terminée')));
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
      final headers = {'Content-Type': 'application/json', if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone};
      final res = await http.get(Uri.parse('$apiHost/clients'), headers: headers).timeout(Duration(seconds: 8));
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
      final headers = {'Content-Type': 'application/json', if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone};
      final res = await http.get(Uri.parse('$apiHost/debts'), headers: headers).timeout(Duration(seconds: 8));
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
        if (d != null && d['remaining'] != null) rem = double.tryParse(d['remaining'].toString()) ?? rem;
        else if (d != null && d['total_paid'] != null) rem = amt - (double.tryParse(d['total_paid'].toString()) ?? 0.0);
      } catch (_) {}
      total += rem;
    }
    return total;
  }

  String fmtDate(dynamic v) {
    if (v == null) return '-';
    final s = v.toString();
    // Try ISO parse first
    try {
      final dt = DateTime.tryParse(s);
      if (dt != null) return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {}
    // Fallback for plain yyyy-MM-dd (no time)
    try {
      final datePart = s.split(' ').first;
      final parts = datePart.split('-');
      if (parts.length >= 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
    } catch (_) {}
    return s;
  }

  Future<int?> createClient() async {
    final result = await Navigator.of(context).push<dynamic>(MaterialPageRoute(builder: (_) => AddClientPage(ownerPhone: widget.ownerPhone)));
    
    if (result != null) {
      await fetchClients();
      // If result is a Map (created client object), return its ID
      if (result is Map && result['id'] != null) {
        return result['id'] as int?;
      }
      // If result is true, fetch and return last client's ID
      if (result == true && clients.isNotEmpty) {
        return clients.last['id'] as int?;
      }
    }
    return null;
  }

  Future createDebt() async {
    if (clients.isEmpty) {
      final add = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: Text('Aucun client'), content: Text('Aucun client trouvé. Voulez-vous en ajouter un maintenant ?'), actions: [TextButton(onPressed: () => Navigator.of(c).pop(false), child: Text('Annuler')), ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: Text('Ajouter client'))]));
      if (add == true) {
        final newId = await createClient();
        if (newId != null) {
          await fetchClients();
          // reopen createDebt flow now that a client exists
          await createDebt();
        }
      }
      return;
    }
    final amountCtl = TextEditingController();
    final notesCtl = TextEditingController();
    int? selectedClientId = clients.first['id'];
    DateTime? dueDate;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Ajouter dette'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: selectedClientId,
                items: clients.map<DropdownMenuItem<int>>((cl) {
                  final clientNumber = (cl['client_number'] ?? '').toString().isNotEmpty ? ' (${cl['client_number']})' : '';
                  return DropdownMenuItem(value: cl['id'], child: Text('${cl['name']}$clientNumber'));
                }).toList(),
                onChanged: (v) => selectedClientId = v,
                decoration: InputDecoration(labelText: 'Client'),
              ),
              TextField(controller: amountCtl, decoration: InputDecoration(labelText: 'Montant'), keyboardType: TextInputType.number),
              SizedBox(height: 8),
              Row(children: [
                Expanded(child: Text(dueDate == null ? 'Échéance: -' : 'Échéance: ${DateFormat('dd/MM/yyyy').format(dueDate!)}')),
                TextButton(onPressed: () async { final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100)); if (d!=null) setState((){ dueDate=d; }); }, child: Text('Choisir'))
              ]),
              TextField(controller: notesCtl, decoration: InputDecoration(labelText: 'Notes')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: Text('Ajouter')),
        ],
      ),
    );
    if (ok == true && selectedClientId != null && amountCtl.text.trim().isNotEmpty) {
      try {
        final body = {'client_id': selectedClientId, 'amount': double.tryParse(amountCtl.text) ?? 0.0, 'due_date': dueDate == null ? null : DateFormat('yyyy-MM-dd').format(dueDate!), 'notes': notesCtl.text};
        final headers = {'Content-Type': 'application/json', if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone};
        final res = await http.post(Uri.parse('$apiHost/debts'), headers: headers, body: json.encode(body)).timeout(Duration(seconds: 8));
        if (res.statusCode == 201) {
          await fetchDebts();
          if (mounted && selectedClientId != null) {
            setState(() { _expandedClients.add(selectedClientId); });
          }
        } else {
          final bodyText = res.body;
          print('Create debt failed: ${res.statusCode} $bodyText');
          await showDialog(context: context, builder: (ctx) => AlertDialog(title: Text('Erreur'), content: Text('Échec création dette: ${res.statusCode}\n$bodyText'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('OK'))]));
        }
      } on TimeoutException {
        print('Timeout creating debt');
        await showDialog(context: context, builder: (ctx) => AlertDialog(title: Text('Erreur'), content: Text('Timeout lors de la création de la dette'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('OK'))]));
      } catch (e) {
        print('Error creating debt: $e');
        await showDialog(context: context, builder: (ctx) => AlertDialog(title: Text('Erreur'), content: Text('Erreur lors de la création: $e'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('OK'))]));
      }
    }
  }

  Future showDebtDetails(Map d) async {
    final res = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DebtDetailsPage(ownerPhone: widget.ownerPhone, debt: d)));
    if (res == true) await fetchDebts();
  }

  

  Widget _buildDebtsTab() {
    // Group debts by client_id
    final Map<dynamic, List> grouped = {};
    for (final d in debts) {
      final key = d != null && d['client_id'] != null ? d['client_id'] : 'unknown';
      if (!grouped.containsKey(key)) grouped[key] = [];
      grouped[key]!.add(d);
    }

    final groups = grouped.entries.toList();

    // Sort groups so clients with unpaid amount appear first, fully-paid clients go to bottom
    groups.sort((a, b) {
      double sumRem(List list) {
        double tot = 0.0;
        for (final d in list) {
          final amt = double.tryParse(d['amount']?.toString() ?? '0') ?? 0.0;
          double rem = amt;
          try {
            if (d != null && d['remaining'] != null) rem = double.tryParse(d['remaining'].toString()) ?? rem;
            else if (d != null && d['total_paid'] != null) rem = amt - (double.tryParse(d['total_paid'].toString()) ?? 0.0);
          } catch (_) {}
          tot += rem;
        }
        return tot;
      }

      final ra = sumRem(a.value);
      final rb = sumRem(b.value);
      final sa = ra > 0 ? 0 : 1; // unpaid first
      final sb = rb > 0 ? 0 : 1;
      if (sa != sb) return sa - sb;
      return 0;
    });

    // compute global totals for header
    double totalToCollect = 0.0;
    int totalUnpaid = 0;
    for (final d in debts) {
      final amt = double.tryParse(d['amount']?.toString() ?? '0') ?? 0.0;
      double rem = amt;
      try {
        if (d != null && d['remaining'] != null) rem = double.tryParse(d['remaining'].toString()) ?? rem;
        else if (d != null && d['total_paid'] != null) rem = amt - (double.tryParse(d['total_paid'].toString()) ?? 0.0);
      } catch (_) {}
      totalToCollect += rem;
      if (rem > 0) totalUnpaid++;
    }

    return RefreshIndicator(
      onRefresh: () async => await fetchDebts(),
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        // add one for the header card
        itemCount: groups.length + 1,
        itemBuilder: (ctx, gi) {
          if (gi == 0) {
            // Header summary card - beautiful new design
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  padding: EdgeInsets.all(0),
                  child: Column(
                    children: [
                      // Top section - Total and Impayées side by side
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Total à percevoir', style: TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
                                  SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _showTotalCard
                                          ? Text(fmtFCFA(totalToCollect), style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5))
                                          : Text('••••••', style: TextStyle(color: kMuted, fontSize: 24, fontWeight: FontWeight.w800)),
                                      ),
                                      GestureDetector(
                                        onTap: () => setState(() => _showTotalCard = !_showTotalCard),
                                        child: Icon(_showTotalCard ? Icons.visibility : Icons.visibility_off, color: kMuted, size: 20),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 16),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text('Impayées', style: TextStyle(color: Colors.redAccent.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                                  SizedBox(height: 6),
                                  Text('$totalUnpaid', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 22)),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                      // Divider
                      Container(height: 1, color: Colors.white.withOpacity(0.08)),
                      // Bottom section - Action buttons
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final newId = await createClient();
                                  if (newId != null) {
                                    await fetchClients();
                                    await fetchDebts();
                                  }
                                },
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: kAccent.withOpacity(0.15)),
                                      child: Icon(Icons.person_add, color: kAccent, size: 24),
                                    ),
                                    SizedBox(height: 8),
                                    Text('Client', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 13, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(width: 24),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddDebtPage(ownerPhone: widget.ownerPhone, clients: clients, preselectedClientId: null))),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: kAccent.withOpacity(0.15)),
                                      child: Icon(Icons.add_circle, color: kAccent, size: 24),
                                    ),
                                    SizedBox(height: 8),
                                    Text('Dette', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 13, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
            );
          }

          final entry = groups[gi - 1];
          final cid = entry.key;
          final clientDebts = entry.value;
          final client = clients.firstWhere((x) => x['id'] == cid, orElse: () => null);
          final clientName = client != null ? client['name'] : (cid == 'unknown' ? 'Clients inconnus' : 'Client ${cid}');
          final avatarUrl = client != null ? client['avatar_url'] : null;

          // compute aggregated remaining for client
          double totalRemaining = 0.0;
          for (final d in clientDebts) {
            final amt = double.tryParse(d['amount']?.toString() ?? '0') ?? 0.0;
            double rem = amt;
            try {
              if (d != null && d['remaining'] != null) rem = double.tryParse(d['remaining'].toString()) ?? rem;
              else if (d != null && d['total_paid'] != null) rem = amt - (double.tryParse(d['total_paid'].toString()) ?? 0.0);
            } catch (_) {}
            totalRemaining += rem;
          }

          // count unpaid debts for this client (remaining > 0)
          int unpaidCount = 0;
          for (final d in clientDebts) {
            final amt2 = double.tryParse(d['amount']?.toString() ?? '0') ?? 0.0;
            double rem2 = amt2;
            try {
              if (d != null && d['remaining'] != null) rem2 = double.tryParse(d['remaining'].toString()) ?? rem2;
              else if (d != null && d['total_paid'] != null) rem2 = amt2 - (double.tryParse(d['total_paid'].toString()) ?? 0.0);
            } catch (_) {}
            if (rem2 > 0) unpaidCount++;
          }

          // Minimalistic client card (expandable)
          final bool isOpen = _expandedClients.contains(cid);
          return Card(
            color: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            child: Column(
              children: [
                InkWell(
                  onTap: () => setState(() { if (isOpen) _expandedClients.remove(cid); else _expandedClients.add(cid); }),
                  onLongPress: () => _showClientActions(client, cid),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.light ? Colors.grey[300] : Colors.grey[900], borderRadius: BorderRadius.circular(10)),
                          child: avatarUrl != null && avatarUrl != ''
                              ? ClipRRect(borderRadius: BorderRadius.circular(10), child: CachedNetworkImage(imageUrl: avatarUrl, fit: BoxFit.cover))
                              : Icon(Icons.person_outline, color: Theme.of(context).textTheme.bodyMedium?.color, size: 28),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(clientName.toString().toUpperCase(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Theme.of(context).textTheme.titleLarge?.color)),
                            if (client != null && (client['client_number'] ?? '').toString().isNotEmpty) SizedBox(height: 6),
                            if (client != null && (client['client_number'] ?? '').toString().isNotEmpty) Text(client['client_number'].toString(), style: TextStyle(color: kMuted, fontSize: 12)),
                          ]),
                        ),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: Theme.of(context).dividerColor.withOpacity(0.3), borderRadius: BorderRadius.circular(20)),
                            child: Column(children: [Text('${unpaidCount} dettes', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 12)), SizedBox(height: 6), Text(fmtFCFA(totalRemaining), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800))]),
                          ),
                        ]),
                        SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            if (client != null) {
                              final res = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddDebtPage(ownerPhone: widget.ownerPhone, clients: clients, preselectedClientId: client['id'])));
                              if (res == true) {
                                await fetchDebts();
                                setState(() { _expandedClients.add(client['id']); });
                              }
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(color: kAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                            child: Icon(Icons.add_circle, size: 20, color: kAccent),
                          ),
                        ),
                        SizedBox(width: 8),
                        PopupMenuButton<String>(
                          itemBuilder: (BuildContext context) => [
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Supprimer', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) async {
                            if (value == 'delete' && client != null) {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text('Supprimer le client'),
                                  content: Text('Êtes-vous sûr de vouloir supprimer ${client['name']} ? Les dettes associées seront conservées.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Non')),
                                    ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Oui, supprimer')),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                try {
                                  final headers = {'Content-Type': 'application/json', if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone};
                                  final res = await http.delete(Uri.parse('$apiHost/clients/${client['id']}'), headers: headers).timeout(Duration(seconds: 8));
                                  if (res.statusCode == 200) {
                                    await fetchClients();
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Client supprimé')));
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lors de la suppression')));
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                                }
                              }
                            }
                          },
                          child: Icon(Icons.more_vert, size: 20, color: Theme.of(context).textTheme.bodyMedium?.color),
                        ),
                        SizedBox(width: 8),
                        AnimatedRotation(
                          turns: isOpen ? 0.5 : 0.0,
                          duration: Duration(milliseconds: 200),
                          child: Icon(Icons.expand_more, color: Theme.of(context).textTheme.bodyMedium?.color),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isOpen)
                  Column(
                    children: [
                      Divider(color: Colors.white10, height: 1),
                      ...clientDebts.map<Widget>((d) {
                        final amountVal = double.tryParse(d['amount']?.toString() ?? '0') ?? 0.0;
                        double remainingVal = amountVal;
                        try {
                          if (d != null && d['remaining'] != null) remainingVal = double.tryParse(d['remaining'].toString()) ?? remainingVal;
                          else if (d != null && d['total_paid'] != null) remainingVal = amountVal - (double.tryParse(d['total_paid'].toString()) ?? 0.0);
                        } catch (_) {}
                        final bool inProgress = remainingVal < amountVal && remainingVal > 0;
                        final bool isPaid = d['paid'] == true || remainingVal <= 0;
                        final bool statusIsGreen = isPaid || inProgress;
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

                        return InkWell(
                          onTap: () => showDebtDetails(d),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(fmtFCFA(d['amount']), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.w600)),
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text('Échéance: $dueText', style: TextStyle(color: kMuted, fontSize: 12)),
                                          SizedBox(width: 8),
                                          if (dueDateTime != null)
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isOverdue ? Colors.red.withOpacity(0.12) : Colors.blue.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(isOverdue ? Icons.warning_rounded : Icons.schedule, size: 10, color: isOverdue ? Colors.red : Colors.blue),
                                                  SizedBox(width: 4),
                                                  Text(isOverdue ? 'Dépassée' : 'En cours', style: TextStyle(fontSize: 10, color: isOverdue ? Colors.red : Colors.blue, fontWeight: FontWeight.w600)),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(children: [
                                  Text('Reste', style: TextStyle(color: kMuted, fontSize: 12)),
                                  SizedBox(height: 6),
                                  Text(fmtFCFA(remainingVal), style: TextStyle(color: (remainingVal <= 0) ? Colors.green : Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.w700)),
                                ]),
                                SizedBox(width: 12),
                                Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: statusIsGreen ? Colors.green.withOpacity(0.12) : Colors.transparent, borderRadius: BorderRadius.circular(6)),
                                  child: Icon(statusIsGreen ? Icons.check_circle : Icons.circle, color: statusIsGreen ? Colors.green : kAccent.withOpacity(0.6), size: 18),
                                ),
                              ],
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
    // Apply search filtering and move fully-paid clients to bottom
    final filtered = clients.where((c) {
      if (_searchQuery.isEmpty) return true;
      final name = (c['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    filtered.sort((a, b) {
      final ra = _clientTotalRemaining(a['id']);
      final rb = _clientTotalRemaining(b['id']);
      final sa = ra > 0 ? 0 : 1; // unpaid first
      final sb = rb > 0 ? 0 : 1;
      if (sa != sb) return sa - sb;
      return a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase());
    });

    return RefreshIndicator(
      onRefresh: () async => await fetchClients(),
      child: ListView.builder(
        padding: EdgeInsets.all(12),
        itemCount: filtered.length,
        itemBuilder: (ctx, i) {
          final c = filtered[i];
          return Container(
            margin: EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.04), width: 1),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0,2))],
            ),
            child: InkWell(
              onTap: () async {
                // show debts for client
                final headers = {'Content-Type': 'application/json', if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone};
                final res = await http.get(Uri.parse('$apiHost/debts/client/${c['id']}'), headers: headers).timeout(Duration(seconds: 8));
                if (res.statusCode == 200) {
                  final clientDebts = json.decode(res.body) as List;
                  await showDialog(context: context, builder: (ctx) {
                    final w = MediaQuery.of(ctx).size.width;
                    final dialogWidth = w < 420 ? w * 0.95 : 400.0;
                    return AlertDialog(
                      title: Text('Dettes de ${c['name']}'),
                      content: Container(width: dialogWidth, child: ListView(children: clientDebts.map<Widget>((d) => ListTile(title: Text(fmtFCFA(d['amount'])), subtitle: Text('Reste: ${fmtFCFA(d['remaining'])}'), onTap: () { Navigator.of(ctx).pop(); showDebtDetails(d); })).toList())),
                      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Fermer'))],
                    );
                  });
                }
              },
              onLongPress: () async {
                final num = c['client_number'] ?? '';
                if (num != null && num.toString().isNotEmpty) {
                  await Clipboard.setData(ClipboardData(text: num.toString()));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Numéro copié: $num')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Aucun numéro à copier')));
                }
              },
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(4)),
                      child: c['avatar_url'] != null && c['avatar_url'] != ''
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: CachedNetworkImage(imageUrl: c['avatar_url'], fit: BoxFit.cover, placeholder: (context, url) => Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kMuted))), errorWidget: (context, url, error) => Icon(Icons.person_outline, color: kMuted, size: 24)))
                          : Icon(Icons.person_outline, color: kMuted, size: 24),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c['name'].toString().toUpperCase(), style: TextStyle(fontSize: 12, letterSpacing: 1.1, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.95))),
                        SizedBox(height: 8),
                        Text(c['client_number'] ?? '-', style: TextStyle(color: kMuted)),
                      ]),
                    ),
                    // quick add debt
                    IconButton(
                      icon: Icon(Icons.add_circle, color: kAccent),
                      onPressed: () async {
                        final res = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddDebtPage(ownerPhone: widget.ownerPhone, clients: clients, preselectedClientId: c['id'])));
                        if (res == true) {
                          await fetchDebts();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dette ajoutée')));
                        }
                      },
                    ),
                    // delete client
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text('Supprimer le client'),
                            content: Text('Êtes-vous sûr de vouloir supprimer ${c['name']} ? Cette action ne peut pas être annulée.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Annuler')),
                              ElevatedButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                child: Text('Supprimer', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          try {
                            final headers = {'Content-Type': 'application/json', if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone};
                            final res = await http.delete(Uri.parse('$apiHost/clients/${c['id']}'), headers: headers).timeout(Duration(seconds: 8));
                            if (res.statusCode == 200) {
                              await fetchClients();
                              await fetchDebts();
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Client supprimé')));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: ${res.statusCode}')));
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        backgroundColor: kSurface,
        iconTheme: IconThemeData(color: kMuted),
        title: _isSearching
            ? SizedBox(
                height: 44,
                child: TextField(
                  focusNode: _searchFocus,
                  controller: _searchController,
                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un client...',
                    hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                    prefixIcon: Icon(Icons.search, color: Theme.of(context).textTheme.bodyMedium?.color),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.close, color: Theme.of(context).textTheme.bodyMedium?.color),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _isSearching = false;
                          _searchQuery = '';
                        });
                        // refresh lists
                        fetchClients();
                        fetchDebts();
                      },
                    ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.light ? Colors.grey[100] : Colors.white12,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.zero,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (v) async {
                    if (_tabIndex == 0) await fetchDebts(query: v);
                    else setState(() {});
                  },
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Replace shop name with a shop icon for a cleaner header
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(8)),
                        child: Center(child: Icon(Icons.store, color: Colors.white, size: 20)),
                      ),
                      SizedBox(width: 10),
                      // keep boutique name next to icon if available
                      if (boutiqueName.isNotEmpty)
                        Expanded(child: Text(boutiqueName, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)))
                      else if ((widget.ownerShopName ?? '').isNotEmpty)
                        Expanded(child: Text(widget.ownerShopName!, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)))
                      else
                        Expanded(child: Text('Gestion de dettes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800))),
                    ],
                  ),
                  SizedBox(height: 2),
                ],
              ),
        actions: [
          // Search action (circular, with thoughtful person-badge)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 6.0, vertical: 6.0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchController.clear();
                      _searchQuery = '';
                      fetchClients();
                      fetchDebts();
                    } else {
                      Future.delayed(Duration(milliseconds: 80), () => FocusScope.of(context).requestFocus(_searchFocus));
                    }
                  });
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: Colors.white12, shape: BoxShape.circle),
                  child: Stack(alignment: Alignment.center, children: [
                    Icon(Icons.search, color: kMuted),
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: kAccent, shape: BoxShape.circle, border: Border.all(color: Colors.black12, width: 1)),
                        child: Center(child: Icon(Icons.person, size: 8, color: Colors.black)),
                      ),
                    )
                  ]),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _isSyncing ? null : () async => await _triggerSync(),
            icon: _isSyncing
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kMuted))
                : Icon(Icons.sync, color: kMuted),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'logout') widget.onLogout();
              if (v == 'team') Navigator.of(context).push(MaterialPageRoute(builder: (_) => TeamScreen(ownerPhone: widget.ownerPhone)));
              if (v == 'settings') await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsScreen()));
            },
            itemBuilder: (c) => [
              PopupMenuItem(value: 'team', child: Text('Équipe')),
              PopupMenuItem(value: 'settings', child: Text('Paramètres')),
              PopupMenuItem(value: 'logout', child: Text('Déconnexion')),
            ],
          )
        ],
      ),
      body: _tabIndex == 0 ? _buildDebtsTab() : _buildClientsTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) {
          setState(() => _tabIndex = i);
          if (i == 0 && _searchQuery.isNotEmpty) fetchDebts(query: _searchQuery);
        },
        backgroundColor: kSurface,
        selectedItemColor: kAccent,
        unselectedItemColor: kMuted,
        items: [BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Dettes'), BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Clients')],
      ),
      // Floating action removed — add button moved to AppBar to avoid covering list items
    );
  }
}