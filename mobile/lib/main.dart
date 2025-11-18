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

// Theme colors
const Color kBackground = Color(0xFF0F1113);
const Color kSurface = Color(0xFF121416);
const Color kCard = Color(0xFF151718);
const Color kAccent = Color(0xFF2DB89A);
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

  @override
  void initState() {
    super.initState();
    _loadOwner();
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

  Future setOwner({required String phone, String? shopName, int? id}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('owner_phone', phone);
    if (shopName != null) await prefs.setString('owner_shop_name', shopName);
    if (id != null) await prefs.setInt('owner_id', id);
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
    final baseTheme = ThemeData.dark();
    return MaterialApp(
      title: 'Boutique - Gestion de dettes',
      theme: baseTheme.copyWith(
        textTheme: baseTheme.textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
        colorScheme: baseTheme.colorScheme.copyWith(primary: kAccent, secondary: kMuted),
        appBarTheme: AppBarTheme(backgroundColor: kSurface, foregroundColor: Colors.white, elevation: 0),
        scaffoldBackgroundColor: kBackground,
        cardColor: kCard,
        elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: kAccent, foregroundColor: Colors.black)),
        floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: kAccent, foregroundColor: Colors.black), dialogTheme: DialogThemeData(backgroundColor: kCard),
      ),
      home: ownerPhone == null
          ? LoginPage(onLogin: (phone, shop, id) => setOwner(phone: phone, shopName: shop, id: id))
          : HomePage(ownerPhone: ownerPhone!, ownerShopName: ownerShopName, onLogout: clearOwner),
    );
  }
}

// Simple Login Page
class LoginPage extends StatefulWidget {
  final void Function(String phone, String? shop, int? id) onLogin;
  LoginPage({required this.onLogin});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final phoneCtl = TextEditingController();
  final passCtl = TextEditingController();
  bool loading = false;

  String get apiHost {
    if (kIsWeb) return 'http://localhost:3000/api';
    try { if (Platform.isAndroid) return 'http://10.0.2.2:3000/api'; } catch(_) {}
    return 'http://localhost:3000/api';
  }

  Future doLogin() async {
    setState((){loading=true;});
    try {
      final body = {'phone': phoneCtl.text.trim(), 'password': passCtl.text};
      final res = await http.post(Uri.parse('$apiHost/auth/login'), headers: {'Content-Type': 'application/json'}, body: json.encode(body)).timeout(Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final id = data['id'] is int ? data['id'] as int : (data['id'] is String ? int.tryParse(data['id']) : null);
        widget.onLogin(data['phone'], data['shop_name'], id);
      } else {
        final msg = res.body;
        await showDialog(context: context, builder: (c)=>AlertDialog(title: Text('Erreur'), content: Text('Login échoué: ${res.statusCode}\n$msg'), actions: [TextButton(onPressed: ()=>Navigator.of(c).pop(), child: Text('OK'))]));
      }
    } catch (e) {
      await showDialog(context: context, builder: (c)=>AlertDialog(title: Text('Erreur'), content: Text('Erreur login: $e'), actions: [TextButton(onPressed: ()=>Navigator.of(c).pop(), child: Text('OK'))]));
    } finally { setState(()=>loading=false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: phoneCtl, decoration: InputDecoration(labelText: 'Numéro de téléphone')),
          TextField(controller: passCtl, decoration: InputDecoration(labelText: 'Mot de passe'), obscureText: true),
          SizedBox(height: 12),
          ElevatedButton(onPressed: loading?null:doLogin, child: Text('Se connecter')),
          TextButton(onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => RegisterPage(onRegister: widget.onLogin)));
          }, child: Text('Créer un compte'))
        ]),
      ),
    );
  }
}

// Simple Register Page
class RegisterPage extends StatefulWidget {
  final void Function(String phone, String? shop, int? id) onRegister;
  RegisterPage({required this.onRegister});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final phoneCtl = TextEditingController();
  final passCtl = TextEditingController();
  final shopCtl = TextEditingController();
  bool loading = false;

  String get apiHost {
    if (kIsWeb) return 'http://localhost:3000/api';
    try { if (Platform.isAndroid) return 'http://10.0.2.2:3000/api'; } catch(_) {}
    return 'http://localhost:3000/api';
  }

  Future doRegister() async {
    setState(()=>loading=true);
    try {
      final body = {'phone': phoneCtl.text.trim(), 'password': passCtl.text, 'shop_name': shopCtl.text.trim()};
      final res = await http.post(Uri.parse('$apiHost/auth/register'), headers: {'Content-Type': 'application/json'}, body: json.encode(body)).timeout(Duration(seconds: 8));
      if (res.statusCode == 201) {
        final data = json.decode(res.body);
        final id = data['id'] is int ? data['id'] as int : (data['id'] is String ? int.tryParse(data['id']) : null);
        widget.onRegister(data['phone'], data['shop_name'], id);
        // close register page after successful registration so parent shows Home
        Navigator.of(context).pop();
      } else {
        await showDialog(context: context, builder: (c)=>AlertDialog(title: Text('Erreur'), content: Text('Inscription échouée: ${res.statusCode}\n${res.body}'), actions: [TextButton(onPressed: ()=>Navigator.of(c).pop(), child: Text('OK'))]));
      }
    } catch (e) {
      await showDialog(context: context, builder: (c)=>AlertDialog(title: Text('Erreur'), content: Text('Erreur inscription: $e'), actions: [TextButton(onPressed: ()=>Navigator.of(c).pop(), child: Text('OK'))]));
    } finally { setState(()=>loading=false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Créer un compte')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: phoneCtl, decoration: InputDecoration(labelText: 'Numéro de téléphone')),
          TextField(controller: passCtl, decoration: InputDecoration(labelText: 'Mot de passe'), obscureText: true),
          TextField(controller: shopCtl, decoration: InputDecoration(labelText: 'Nom de la boutique')),
          SizedBox(height: 12),
          ElevatedButton(onPressed: loading?null:doRegister, child: Text('Créer')),
        ]),
      ),
    );
  }
}

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
    if (name == null || name.isEmpty) {
      await Future.delayed(Duration(milliseconds: 200));
      _askBoutiqueName();
    } else {
      setState(() => boutiqueName = name);
    }
  }

  Future _askBoutiqueName() async {
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text('Créer votre boutique'),
        content: TextField(controller: ctl, decoration: InputDecoration(labelText: 'Nom de la boutique')),
        actions: [
          ElevatedButton(onPressed: () => Navigator.of(c).pop(false), child: Text('Ignorer')),
          TextButton(onPressed: () => Navigator.of(c).pop(true), child: Text('OK')),
        ],
      ),
    );
    if (ok == true && ctl.text.trim().isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('boutique_name_${widget.ownerPhone}', ctl.text.trim());
      setState(() => boutiqueName = ctl.text.trim());
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

  Future<int?> createClient() async {
    final numberCtl = TextEditingController();
    final nameCtl = TextEditingController();
    final avatarCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Ajouter un client'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: numberCtl, decoration: InputDecoration(labelText: 'Numéro (optionnel)')),
            TextField(controller: nameCtl, decoration: InputDecoration(labelText: 'Nom')),
            TextField(controller: avatarCtl, decoration: InputDecoration(labelText: 'URL Avatar (optionnel)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: Text('Ajouter')),
        ],
      ),
    );
    if (ok == true && nameCtl.text.trim().isNotEmpty) {
      try {
        final body = {'client_number': numberCtl.text.trim(), 'name': nameCtl.text.trim(), 'avatar_url': avatarCtl.text.trim()};
        final headers = {'Content-Type': 'application/json', if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone};
        final res = await http.post(Uri.parse('$apiHost/clients'), headers: headers, body: json.encode(body)).timeout(Duration(seconds: 8));
        if (res.statusCode == 201) {
          // try to parse created object (expecting backend returns created client)
          try {
            final created = json.decode(res.body);
            await fetchClients();
            if (created is Map && created['id'] != null) return created['id'] as int?;
          } catch (_) {
            await fetchClients();
            return clients.isNotEmpty ? clients.last['id'] as int? : null;
          }
        }
      } on TimeoutException {
        print('Timeout creating client');
      } catch (e) {
        print('Error creating client: $e');
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
                items: clients.map<DropdownMenuItem<int>>((cl) => DropdownMenuItem(value: cl['id'], child: Text(cl['name']))).toList(),
                onChanged: (v) => selectedClientId = v,
                decoration: InputDecoration(labelText: 'Client'),
              ),
              TextField(controller: amountCtl, decoration: InputDecoration(labelText: 'Montant'), keyboardType: TextInputType.number),
              SizedBox(height: 8),
              Row(children: [
                Expanded(child: Text(dueDate == null ? 'Échéance: -' : 'Échéance: ${DateFormat.yMd().format(dueDate!)}')),
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
    // fetch payments
    List payments = [];
    try {
      final headers = {'Content-Type': 'application/json', if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone};
      final pres = await http.get(Uri.parse('$apiHost/debts/${d['id']}/payments'), headers: headers).timeout(Duration(seconds: 6));
      if (pres.statusCode == 200) payments = json.decode(pres.body) as List;
      else print('Fetch payments failed: ${pres.statusCode} ${pres.body}');
    } catch (e) {
      print('Error fetching payments: $e');
    }
    final totalPaid = payments.fold<double>(0.0, (s, p) => s + (double.tryParse(p['amount'].toString()) ?? 0.0));
    final remaining = (double.tryParse(d['amount'].toString()) ?? 0.0) - totalPaid;

    return showDialog<void>(
      context: context,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx).size;
        final screenWidth = mq.width;
        final screenHeight = mq.height;
        final dialogWidth = screenWidth < 520 ? (screenWidth * 0.95) : 520.0;
        final maxDialogHeight = screenHeight * 0.85;
        final isSmall = screenWidth < 360;
        final paymentsHeight = screenWidth < 360 ? 120.0 : (screenWidth < 420 ? 140.0 : 160.0);

        return Dialog(
          backgroundColor: kCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SizedBox(
            width: dialogWidth,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxDialogHeight),
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(isSmall ? 12.0 : 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_clientNameForDebt(d)?.toUpperCase() ?? 'CLIENT INCONNU', style: TextStyle(color: Colors.white, fontSize: isSmall ? 11 : 12, letterSpacing: 1.1)),
                                SizedBox(height: isSmall ? 6 : 8),
                                Text(fmtFCFA(d['amount']), style: TextStyle(color: Colors.white, fontSize: isSmall ? 18 : 22, fontWeight: FontWeight.bold)),
                                SizedBox(height: isSmall ? 4 : 6),
                                Text('Échéance: ${d['due_date'] ?? '-'}', style: TextStyle(color: kMuted, fontSize: isSmall ? 12 : 13)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
                                child: Text('${((totalPaid / (double.tryParse(d['amount'].toString()) ?? 1)) * 100).clamp(0,100).toStringAsFixed(0)}% payé', style: TextStyle(color: kAccent, fontWeight: FontWeight.w700)),
                              ),
                              SizedBox(height: 12),
                              Icon(Icons.receipt_long, color: kMuted),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: isSmall ? 8 : 12),
                      // Progress
                      LinearProgressIndicator(
                        value: (double.tryParse(d['amount'].toString()) == 0) ? 0.0 : (totalPaid / (double.tryParse(d['amount'].toString()) ?? 1)).clamp(0.0,1.0),
                        backgroundColor: Colors.white12,
                        color: kAccent,
                        minHeight: isSmall ? 8 : 10,
                      ),
                      SizedBox(height: isSmall ? 8 : 12),

                      // Summary row
                      Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Payé', style: TextStyle(color: kMuted)), SizedBox(height:4), Text(fmtFCFA(totalPaid), style: TextStyle(color: kAccent, fontWeight: FontWeight.w700))])),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Reste', style: TextStyle(color: kMuted)), SizedBox(height:4), Text(fmtFCFA(remaining), style: TextStyle(color: remaining <= 0 ? Colors.green : Colors.white, fontWeight: FontWeight.w700))])),
                      ]),
                      SizedBox(height: isSmall ? 8 : 12),

                      // Notes
                      if (d['notes'] != null && d['notes'] != '') ...[
                        Text('Notes', style: TextStyle(color: kMuted, fontSize: isSmall ? 12 : 13)),
                        SizedBox(height: isSmall ? 6 : 8),
                        Text(d['notes'], style: TextStyle(color: Colors.white, fontSize: isSmall ? 13 : 14)),
                        SizedBox(height: isSmall ? 8 : 12),
                      ],

                      // Recent payments
                      Text('Paiements récents', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: isSmall ? 13 : 14)),
                      SizedBox(height: isSmall ? 8 : 10),
                      Container(
                        height: paymentsHeight,
                        child: payments.isEmpty
                            ? Center(child: Text('Aucun paiement', style: TextStyle(color: kMuted)))
                            : ListView.separated(
                                itemCount: payments.length,
                                separatorBuilder: (_, __) => Divider(color: Colors.white10, height: 1),
                                itemBuilder: (ctx, i) {
                                  final p = payments[i];
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(backgroundColor: Colors.grey[900], child: Icon(Icons.monetization_on, color: kAccent)),
                                    title: Text(fmtFCFA(p['amount']), style: TextStyle(color: kAccent, fontWeight: FontWeight.w600, fontSize: isSmall ? 13 : 14)),
                                    subtitle: Text(DateFormat.yMd().add_jm().format(DateTime.parse(p['paid_at'])), style: TextStyle(color: kMuted, fontSize: isSmall ? 11 : 12)),
                                  );
                                },
                              ),
                      ),

                      SizedBox(height: isSmall ? 8 : 12),
                      // Actions (responsive)
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Fermer')),
                          TextButton(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: ctx,
                                builder: (confirmCtx) => AlertDialog(
                                  title: Text('Confirmer'),
                                  content: Text('Supprimer cette dette ?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.of(confirmCtx).pop(false), child: Text('Annuler')),
                                    ElevatedButton(onPressed: () => Navigator.of(confirmCtx).pop(true), child: Text('Supprimer'))
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                Navigator.of(ctx).pop();
                                try {
                                  final headers = {'Content-Type': 'application/json', if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone};
                                  final res = await http.delete(Uri.parse('$apiHost/debts/${d['id']}'), headers: headers);
                                  if (res.statusCode == 200) {
                                    await fetchDebts();
                                  } else {
                                    print('Delete failed: ${res.statusCode} ${res.body}');
                                  }
                                } catch (e) {
                                  print('Error deleting debt: $e');
                                }
                              }
                            },
                            child: Text('Supprimer', style: TextStyle(color: Colors.red)),
                          ),
                          ElevatedButton.icon(
                            onPressed: () async {
                              Navigator.of(ctx).pop();
                              await _addPayment(d);
                            },
                            icon: Icon(Icons.add, color: Colors.black),
                            label: Text(isSmall ? 'Paiement' : 'Ajouter paiement'),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: Size(0, 36),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future _addPayment(Map d) async {
    final amountCtl = TextEditingController();
    DateTime paidAt = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Ajouter paiement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: amountCtl, decoration: InputDecoration(labelText: 'Montant payé'), keyboardType: TextInputType.number),
            SizedBox(height: 8),
            Row(children: [Expanded(child: Text('Date: ${DateFormat.yMd().format(paidAt)}')), TextButton(onPressed: () async { final d = await showDatePicker(context: context, initialDate: paidAt, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (d!=null) paidAt = d; setState((){}); }, child: Text('Choisir'))])
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.of(c).pop(false), child: Text('Annuler')), ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: Text('Ajouter'))],
      ),
    );
    if (ok == true && amountCtl.text.trim().isNotEmpty) {
      try {
        final body = {'amount': double.tryParse(amountCtl.text) ?? 0.0, 'paid_at': paidAt.toIso8601String()};
        final headers = {'Content-Type': 'application/json', if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone};
        final res = await http.post(Uri.parse('$apiHost/debts/${d['id']}/pay'), headers: headers, body: json.encode(body)).timeout(Duration(seconds: 8));
        if (res.statusCode == 201 || res.statusCode == 200) {
          await fetchDebts();
        } else {
          print('Add payment failed: ${res.statusCode} ${res.body}');
          await showDialog(context: context, builder: (ctx) => AlertDialog(title: Text('Erreur'), content: Text('Échec ajout paiement: ${res.statusCode}\n${res.body}'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('OK'))]));
        }
      } catch (e) {
        print('Error adding payment: $e');
      }
    }
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

    return RefreshIndicator(
      onRefresh: () async => await fetchDebts(),
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: groups.length,
        itemBuilder: (ctx, gi) {
          final entry = groups[gi];
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

          return Container(
            margin: EdgeInsets.only(bottom: 12, left: 8, right: 8),
            decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white.withOpacity(0.04))),
            child: ExpansionTile(
              tilePadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              collapsedIconColor: kAccent,
              iconColor: kAccent,
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(4)),
                child: avatarUrl != null && avatarUrl != ''
                    ? ClipRRect(borderRadius: BorderRadius.circular(4), child: CachedNetworkImage(imageUrl: avatarUrl, fit: BoxFit.cover))
                    : Icon(Icons.person_outline, color: kMuted),
              ),
              title: Text(clientName.toString().toUpperCase(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              subtitle: Text('${clientDebts.length} dette(s) • Reste: ${fmtFCFA(totalRemaining)}', style: TextStyle(color: kMuted)),
              children: clientDebts.map<Widget>((d) {
                final amountVal = double.tryParse(d['amount']?.toString() ?? '0') ?? 0.0;
                double remainingVal = amountVal;
                try {
                  if (d != null && d['remaining'] != null) remainingVal = double.tryParse(d['remaining'].toString()) ?? remainingVal;
                  else if (d != null && d['total_paid'] != null) remainingVal = amountVal - (double.tryParse(d['total_paid'].toString()) ?? 0.0);
                } catch (_) {}
                final bool inProgress = remainingVal < amountVal && remainingVal > 0;
                final bool isPaid = d['paid'] == true || remainingVal <= 0;
                final bool statusIsGreen = isPaid || inProgress;

                return InkWell(
                  onTap: () => showDebtDetails(d),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fmtFCFA(d['amount']), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              if (d['notes'] != null && d['notes'] != '') SizedBox(height: 6),
                              if (d['notes'] != null && d['notes'] != '') Text(d['notes'], style: TextStyle(color: kMuted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        Column(children: [
                          Text('Reste', style: TextStyle(color: kMuted, fontSize: 12)),
                          SizedBox(height: 6),
                          Text(fmtFCFA(remainingVal), style: TextStyle(color: (remainingVal <= 0) ? Colors.green : Colors.white, fontWeight: FontWeight.w700)),
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildClientsTab() {
    return RefreshIndicator(
      onRefresh: () async => await fetchClients(),
      child: ListView.builder(
        padding: EdgeInsets.all(12),
        itemCount: clients.length,
        itemBuilder: (ctx, i) {
          final c = clients[i];
          return Container(
            margin: EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withOpacity(0.04), width: 1),
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
                        // prefill createDebt for this client
                        final amountCtl = TextEditingController();
                        final notesCtl = TextEditingController();
                        DateTime? due;
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (dlg) => AlertDialog(
                            title: Text('Ajouter dette pour ${c['name']}'),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(controller: amountCtl, decoration: InputDecoration(labelText: 'Montant'), keyboardType: TextInputType.number),
                                  SizedBox(height: 8),
                                  Row(children: [
                                    Expanded(child: Text(due == null ? 'Échéance: -' : 'Échéance: ${DateFormat.yMd().format(due!)}')),
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
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dette ajoutée')));
                            } else {
                              await showDialog(context: context, builder: (ctx) => AlertDialog(title: Text('Erreur'), content: Text('Échec création dette: ${res.statusCode}\n${res.body}'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('OK'))]));
                            }
                          } catch (e) {
                            await showDialog(context: context, builder: (ctx) => AlertDialog(title: Text('Erreur'), content: Text('Erreur création dette: $e'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('OK'))]));
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
        title: Text(boutiqueName.isEmpty ? (widget.ownerShopName ?? 'Gestion de dettes') : boutiqueName, style: TextStyle(color: Colors.white)),
        backgroundColor: kSurface,
        iconTheme: IconThemeData(color: kMuted),
        actions: [
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
        onTap: (i) { setState(() => _tabIndex = i); },
        backgroundColor: kSurface,
        selectedItemColor: kAccent,
        unselectedItemColor: kMuted,
        items: [BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Dettes'), BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Clients')],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async { if (_tabIndex==0) await createDebt(); else await createClient(); },
        child: Icon(_tabIndex==0?Icons.add:Icons.person_add),
      ),
    );
  }
}