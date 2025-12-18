import 'package:boutique_mobile/add_payment_page.dart';
import 'package:boutique_mobile/add_loan_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ← ADD THIS
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:ui'; // ⬇️ NOUVEAU : Pour PlatformDispatcher
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:boutique_mobile/config/api_config.dart';
// google_fonts removed - using default text theme
// avatar image now uses Image.network; removed cached_network_image usage
import 'package:connectivity_plus/connectivity_plus.dart';
import 'hive/hive_service_manager.dart';
import 'team_screen.dart';
import 'app_settings.dart';
import 'settings_screen.dart';
import 'screens/splash_screen.dart';
import 'quick_login_page.dart';
import 'returning_user_page.dart';
import 'services/pin_auth_offline_service.dart';
import 'add_debt_page.dart';
import 'add_client_page.dart';
import 'add_addition_page.dart';
import 'debt_details_page.dart';
import 'theme.dart';
import 'utils/methods_extraction.dart';

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

// ✅ Helper pour formater les dates d'échéance avec emoji et couleur
Map<String, dynamic> _formatDueDate(dynamic dateStr) {
  if (dateStr == null) {
    return {'text': '-', 'color': Colors.grey, 'icon': Icons.calendar_today};
  }
  
  try {
    final dt = DateTime.parse(dateStr.toString());
    final now = DateTime.now();
    final difference = dt.difference(now);
    final days = difference.inDays;
    
    if (days < 0) {
      return {
        'text': 'EN RETARD (${days.abs()}j)',
        'color': Colors.red,
        'icon': Icons.warning_rounded,
        'emoji': '⚠️'
      };
    } else if (days == 0) {
      return {
        'text': 'AUJOURD\'HUI',
        'color': Colors.orange,
        'icon': Icons.today,
        'emoji': '📅'
      };
    } else if (days <= 7) {
      return {
        'text': 'DANS $days JOUR${days > 1 ? 'S' : ''}',
        'color': Colors.orange,
        'icon': Icons.schedule,
        'emoji': '⏰'
      };
    } else {
      return {
        'text': DateFormat('dd/MM/yyyy').format(dt),
        'color': Colors.blue,
        'icon': Icons.calendar_today,
        'emoji': '📆'
      };
    }
  } catch (_) {
    return {'text': '-', 'color': Colors.grey, 'icon': Icons.calendar_today};
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ✅ Only load .env on mobile/desktop, NOT on web
  if (!kIsWeb) {
    try {
      await dotenv.load();
    } catch (e) {
      print('⚠️  dotenv.load() failed: $e');
    }
  }
  
  // ⬇️ NOUVEAU: Capturer les futures non gérées
  PlatformDispatcher.instance.onError = (error, stack) {
    print('❌ Unhandled error: $error\n$stack');
    return true;
  };
  
  // ✅ Error handling global pour Flutter Web
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    print('❌ Flutter Error: ${details.exception}');
  };

  runApp(const MyApp());
}

// ✅ ErrorBoundary widget pour capturer les erreurs de build
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  const ErrorBoundary({super.key, required this.child});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool hasError = false;

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return Scaffold(
        body: Container(
          color: const Color(0xFF0F1113),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Une erreur est survenue',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() => hasError = false);
                  },
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
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
  bool? shouldShowPinEntry;
  String? cachedPhoneForReturning;
  bool? cachedHasPinForReturning;
  late AppSettings _appSettings;

  String get apiHost => ApiConfig.getBaseUrl();

  @override
  void initState() {
    super.initState();
    try {
      _appSettings = AppSettings();
      _appSettings.addListener(_onSettingsChanged);
    } catch (e) {
      print('❌ Error initializing AppSettings: $e');
      _appSettings = AppSettings(); // Fallback
    }
    
    // ⬇️ Lancer _loadOwner() avec gestion d'erreur
    _loadOwner().catchError((e) {
      print('❌ Error in _loadOwner: $e');
    });
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
    
    // Check if user has PIN configured
    final pinService = PinAuthOfflineService();
    final hasPinSet = await pinService.hasCachedCredentials();
    
    // Try to auto-login with token
    if (phone != null) {
      try {
        await _appSettings.initForOwner(phone);
      } catch (e) {
        print('⚠️  _appSettings.initForOwner failed: $e');
      }
      final token = _appSettings.authToken;
      
      if (token != null && token.isNotEmpty) {
        // Try to verify token (short timeout)
        try {
          final res = await http.post(
            Uri.parse('$apiHost/auth/verify-token'.replaceFirst('\u007f', '')),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'auth_token': token})
          ).timeout(const Duration(seconds: 2)); // ⬇️ Reduced from 5 to 2 seconds
          
          if (res.statusCode == 200) {
            final data = json.decode(res.body);
            setState(() {
              ownerPhone = data['phone'] ?? phone;
              ownerShopName = data['shop_name'] ?? shop;
              ownerId = data['id'] ?? id;
              cachedHasPinForReturning = hasPinSet;
            });
            return; // Auto-login successful
          }
        } catch (e) {
          // Token verification failed, continue to login page
          print('Token verification failed: $e');
        }
      }
    }
    
    // Fallback: use stored credentials or go to login
    setState(() {
      ownerPhone = phone;
      ownerShopName = shop;
      ownerId = id;
      cachedHasPinForReturning = hasPinSet;
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
    
    // Check if user has PIN configured
    final pinService = PinAuthOfflineService();
    final hasPinSet = await pinService.hasCachedCredentials();
    
    // ✨ Sauvegarder l'état du PIN dans SharedPreferences
    await prefs.setBool('pin_set', hasPinSet);
    
    setState(() { 
      ownerPhone = phone; 
      ownerShopName = shopName; 
      ownerId = id;
      cachedHasPinForReturning = hasPinSet;
    });
  }

  Future clearOwner() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Récupérer le téléphone sauvegardé
    final phone = prefs.getString('owner_phone');
    
    // Vérifier si un PIN a été défini (selon le flag stocké)
    final hasPinSet = prefs.getBool('pin_set') ?? false;
    
    if (phone == null) {
      // Pas de téléphone sauvegardé, aller à QuickLoginPage
      setState(() {
        ownerPhone = null;
        ownerShopName = null;
        ownerId = null;
        shouldShowPinEntry = false;
        cachedPhoneForReturning = null;
        cachedHasPinForReturning = null;
      });
      return;
    }
    
    if (!hasPinSet) {
      // ✨ Pas de PIN = afficher QuickLoginPage directement
      setState(() {
        ownerPhone = null;
        ownerShopName = null;
        ownerId = null;
        shouldShowPinEntry = false;
        cachedPhoneForReturning = null;
        cachedHasPinForReturning = null;
      });
    } else {
      // User has PIN - allow logout to PIN entry screen
      setState(() {
        shouldShowPinEntry = true;
        cachedPhoneForReturning = phone;
        cachedHasPinForReturning = true;  // We know PIN is set
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mainApp = MaterialApp(
      title: 'Boutique - Gestion de dettes',
      theme: getAppTheme(lightMode: _appSettings.lightMode),
      home: shouldShowPinEntry == true && cachedPhoneForReturning != null
          ? ReturningUserPage(
              phone: cachedPhoneForReturning!,
              hasPinSet: cachedHasPinForReturning ?? false,
              onLogin: (phone, shop, id, firstName, lastName, boutiqueModeEnabled) {
                setOwner(phone: phone, shopName: shop, id: id, firstName: firstName, lastName: lastName, boutiqueModeEnabled: boutiqueModeEnabled);
                setState(() {
                  shouldShowPinEntry = false;
                  cachedPhoneForReturning = null;
                  cachedHasPinForReturning = null;
                });
              },
              onBackToQuickSignup: () {
                setState(() {
                  shouldShowPinEntry = false;
                  cachedPhoneForReturning = null;
                  cachedHasPinForReturning = null;
                  ownerPhone = null;
                  ownerShopName = null;
                  ownerId = null;
                });
              },
            )
          : ownerPhone == null
              ? QuickLoginPage(onLogin: (phone, shop, id, firstName, lastName, boutiqueModeEnabled) => setOwner(phone: phone, shopName: shop, id: id, firstName: firstName, lastName: lastName, boutiqueModeEnabled: boutiqueModeEnabled))
              : HomePage(ownerPhone: ownerPhone!, ownerShopName: ownerShopName, onLogout: clearOwner, hasPinSet: cachedHasPinForReturning ?? false),
    );

    // ✅ Show splash screen on first load, then switch to main app
    return ownerPhone == null && shouldShowPinEntry != true 
        ? SplashScreen(nextScreen: mainApp)
        : mainApp;
  }
}

class HomePage extends StatefulWidget {
  final String ownerPhone;
  final String? ownerShopName;
  final VoidCallback onLogout;
  final bool hasPinSet;

  const HomePage({super.key, required this.ownerPhone, this.ownerShopName, required this.onLogout, this.hasPinSet = false});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  int _tabIndex = 0;
  String _debtSubTab = 'prets'; // 'prets' ou 'emprunts'
  List debts = [];
  List clients = [];
  bool _isLoading = true; // ⬇️ NOUVEAU : Flag pour l'écran de chargement
  String _searchQuery = '';
  bool _isSearching = false;
  bool _showTotalCard = true;
  bool _showAmountFilter = false;
  bool _showUnpaidDetails = false;
  double _minDebtAmount = 0.0;
  double _maxDebtAmount = 0.0;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _amountMinController = TextEditingController();
  final TextEditingController _amountMaxController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounceTimer;
  Timer? _autoRefreshTimer; // ✅ NOUVEAU : Auto-refresh les dettes
  final Set<dynamic> _expandedClients = {};
  String boutiqueName = '';
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _isSyncing = false;
  late AnimationController _pulseController;

  String get apiHost => ApiConfig.getBaseUrl();

  @override
  void initState() {
    super.initState();
    // Initialiser le contrôleur d'animation pulse
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    
    // ⬇️ Charger les données EN CACHE IMMÉDIATEMENT
    _loadDebtsLocally().catchError((e) {
      print('Error loading debts from cache: $e');
    });
    _loadClientsLocally().catchError((e) {
      print('Error loading clients from cache: $e');
    });
    
    // ⬇️ PUIS charger depuis l'API en arrière-plan avec timeout court
    _loadBoutique();
    
    // ⬇️ NOUVEAU: Lancer les requêtes avec un timeout très court (2s) pour PWA
    // et garantir que _isLoading devient false rapidement
    Future.wait([
      fetchClients().catchError((e) { print('fetchClients error: $e'); }),
      fetchDebts().catchError((e) { print('fetchDebts error: $e'); }),
    ]).then((_) {
      // ⬇️ NOUVEAU: Garantir que _isLoading devient false après 10 secondes max
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }).catchError((e) {
      print('Error in initState async load: $e');
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    });
    
    // ⬇️ NOUVEAU: Fallback timeout - forcer _isLoading = false après 10 secondes max
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isLoading) {
        print('⚠️ Force disabling loading after 10s (API too slow or offline)');
        setState(() => _isLoading = false);
      }
    });
    
    _startConnectivityListener();
    _startAutoRefresh(); // ✅ NOUVEAU : Démarrer l'auto-refresh
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
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.ownerPhone.isNotEmpty) {
        await AppSettings().initForOwner(widget.ownerPhone);
        AppSettings().addListener(() {
          if (mounted) setState(() {});
        });
        
        // ✨ Initialize HiveServiceManager en ARRIÈRE-PLAN (pas d'await au démarrage!)
        // Cela ne doit pas bloquer l'affichage initial
        // ⚠️  Skip on web - Hive doesn't work on web
        if (!kIsWeb) {
          HiveServiceManager().initializeForOwner(widget.ownerPhone).then((_) {
            print('✅ HiveServiceManager initialized');
          }).catchError((e) {
            print('⚠️  HiveServiceManager init error: $e');
          });
        }
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
    _autoRefreshTimer?.cancel(); // ✅ NOUVEAU : Annuler le timer auto-refresh
    _connSub?.cancel();
    _pulseController.dispose();
    
    // ✨ Shutdown HiveServiceManager (non-blocking)
    if (!kIsWeb) {
      HiveServiceManager().shutdown().catchError((e) {
        print('⚠️  HiveServiceManager shutdown error: $e');
      });
    }
    
    super.dispose();
  }

  Future<void> _startConnectivityListener() async {
  if (kIsWeb) {
    print('⚠️  Connectivity check skipped on web');
    return;
  }
  
  try {
    final List<ConnectivityResult> conn = await Connectivity().checkConnectivity();
    if (_hasConnection(conn)) {
      _triggerSync();
    }
  } catch (_) {}

  _connSub = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
    if (_hasConnection(results)) {
      _triggerSync();
    }
  });
}

bool _hasConnection(List<ConnectivityResult> results) {
  return results.isNotEmpty && 
         results.any((result) => result != ConnectivityResult.none);
}

  // ✅ NOUVEAU : Auto-refresh les dettes toutes les 5 secondes si on est sur la tab debts
  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && _tabIndex == 0) {
        // On est sur l'onglet Debts - refresh silencieusement
        fetchDebts(query: _searchQuery);
      }
    });
  }

  Future<void> _showClientActions(dynamic client, dynamic clientId) async {
    // ✨ CORRIGÉ: Permettre les actions même si client est null, tant qu'on a un clientId valide
    if (client == null && clientId == null) return;
    
    // Si client est null mais on a un clientId, essayer de le charger
    if (client == null && clientId != null && clientId != 'unknown') {
      client = clients.firstWhere((x) => x['id'] == clientId, orElse: () => null);
    }
    
    // Si on ne peut toujours pas trouver le client et c'est 'unknown', on ne peut pas faire d'actions
    if (client == null && clientId == 'unknown') return;
    
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
            onPressed: () => Navigator.of(ctx).pop('edit'),
            child: Row(children: [const Icon(Icons.edit, color: Colors.blue), const SizedBox(width: 12), Text('Modifier ${HomePageMethods.getTermClient()}', style: TextStyle(color: textColor))]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('delete'),
            child: Row(children: [const Icon(Icons.delete, color: Colors.red), const SizedBox(width: 12), Text('Supprimer ${HomePageMethods.getTermClient()}', style: TextStyle(color: textColor))]),
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
    } else if (choice == 'edit') {
      // ✨ Petit délai pour que le premier dialogue se ferme avant d'ouvrir le second
      await Future.delayed(const Duration(milliseconds: 100));
      await _editClient(client);
      await fetchClients();
      await fetchDebts();
    } else if (choice == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Supprimer le ${HomePageMethods.getTermClient()}'),
          content: Text('Voulez-vous vraiment supprimer ${client['name'] ?? 'ce ${HomePageMethods.getTermClient()}'} ?'),
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
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${HomePageMethods.getTermClientUp()} supprimé')));
          } else {
            // Parse error message and provide friendly feedback
            String errorMessage = 'Erreur lors de la suppression';
            try {
              final errorBody = json.decode(res.body);
              if (errorBody['message'] != null) {
                if (errorBody['message'].toString().contains('existing debt') || 
                    errorBody['message'].toString().contains('dette') ||
                    errorBody['message'].toString().contains('emprunt')) {
                  errorMessage = 'Impossible de supprimer ce ${HomePageMethods.getTermClient()} car il possède des dettes ou des emprunts associés.\n\nConseil: Vous pouvez d\'abord clôturer toutes les dettes/emprunts liés avant de le supprimer.';
                } else {
                  errorMessage = errorBody['message'].toString();
                }
              }
            } catch (_) {
              errorMessage = 'Erreur: ${res.statusCode}';
            }
            
            if (mounted) {
              await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('⚠️ Suppression impossible'),
                  content: Text(errorMessage),
                  actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('D\'accord'))]
                )
              );
            }
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
      // ✨ Refetcher simplement depuis l'API (sans Hive blocking)
      // Hive sync est optionnel et ne doit pas bloquer
      await fetchClients();
      await fetchDebts();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Synchronisation terminée')),
        );
      }
    } catch (e) {
      print('❌ Sync error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur sync: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future _loadBoutique() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('boutique_name_${widget.ownerPhone}');
      if (name != null && name.isNotEmpty) {
        setState(() => boutiqueName = name);
      }
    } catch (e) {
      print('❌ Error loading boutique: $e');
    } finally {
      // ⬇️ Marquer le chargement comme complet
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveDebtsLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // ⬇️ NOUVEAU: Vérifier que debts n'est pas vide avant sauvegarder
      if (debts.isNotEmpty) {
        final debtsJson = json.encode(debts);
        await prefs.setString('debts_${widget.ownerPhone}', debtsJson);
        print('✅ Saved ${debts.length} debts to cache');
      }
    } catch (e) {
      print('❌ Error saving debts locally: $e');
    }
  }

  Future<void> _loadDebtsLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final debtsJson = prefs.getString('debts_${widget.ownerPhone}');
      if (debtsJson != null && debtsJson.isNotEmpty) {
        final decodedList = json.decode(debtsJson) as List;
        if (decodedList.isNotEmpty && mounted) {
          setState(() => debts = List.from(decodedList));
          print('✅ Loaded ${debts.length} debts from cache');
        }
      }
    } catch (e) {
      print('❌ Error loading debts locally: $e');
    }
  }

  Future<void> _saveClientsLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // ⬇️ NOUVEAU: Vérifier que clients n'est pas vide avant sauvegarder
      if (clients.isNotEmpty) {
        final clientsJson = json.encode(clients);
        await prefs.setString('clients_${widget.ownerPhone}', clientsJson);
        print('✅ Saved ${clients.length} clients to cache');
      }
    } catch (e) {
      print('❌ Error saving clients locally: $e');
    }
  }

  Future<void> _loadClientsLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientsJson = prefs.getString('clients_${widget.ownerPhone}');
      if (clientsJson != null && clientsJson.isNotEmpty) {
        final decodedList = json.decode(clientsJson) as List;
        if (decodedList.isNotEmpty && mounted) {
          setState(() => clients = List.from(decodedList));
          print('✅ Loaded ${clients.length} clients from cache');
        }
      }
    } catch (e) {
      print('❌ Error loading clients locally: $e');
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
      ).timeout(const Duration(seconds: 8)); // ⬇️ Augmenté à 8s (plus de temps pour PWA)
      
      if (res.statusCode == 200) {
        final newClients = json.decode(res.body) as List;
        // Vérifier si les données ont vraiment changé avant setState
        if (newClients.length != clients.length || newClients.toString() != clients.toString()) {
          if (mounted) {
            setState(() => clients = newClients);
          }
        }
        // ✅ NOUVEAU: Mettre à jour Hive pour garder le cache local synchronisé
        await _saveClientsLocally();
      }
    } on TimeoutException {
      print('⏱️ Timeout fetching clients (8s) - using cached data');
      // Charger depuis le cache local si disponible
      await _loadClientsLocally();
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Error fetching clients: $e');
      // Charger depuis le cache local si disponible
      await _loadClientsLocally();
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
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
        Uri.parse('$apiHost/debts'),
        headers: headers,
      ).timeout(const Duration(seconds: 8)); // ⬇️ Augmenté à 8s (plus de temps pour PWA)
      
      if (res.statusCode == 200) {
        // ⬇️ Vérifier que le body n'est pas vide
        if (res.body.isEmpty) {
          print('⚠️ Empty response body for debts');
          await _loadDebtsLocally();
          return;
        }
        
        final list = json.decode(res.body) as List;
        
        // GROUPER PAR CLIENT+TYPE : garder uniquement la dette la plus récente
        // Clé composite pour séparer PRÊTS et EMPRUNTS : "{clientId}|{type}"
        final Map<String, Map<String, dynamic>> debtsByKey = {};

        double tsForDebt(dynamic debt) {
          if (debt == null) return 0.0;
          // ✅ PRIORITÉ 1: Utiliser le timestamp du dernier événement (paiement/ajout)
          // pour détecter les dettes modifiées après leur création
          final lastEvent = debt['last_event_at'];
          if (lastEvent != null) {
            if (lastEvent is String) {
              final dt = DateTime.tryParse(lastEvent);
              if (dt != null) return dt.millisecondsSinceEpoch.toDouble();
            } else if (lastEvent is int) {
              return lastEvent.toDouble();
            }
          }
          
          // Fallback aux champs de timestamp usuels
          final List<String> tsFields = ['updated_at', 'added_at', 'created_at', 'createdAt', 'date'];
          for (final f in tsFields) {
            final v = debt[f];
            if (v == null) continue;
            if (v is String) {
              final dt = DateTime.tryParse(v);
              if (dt != null) return dt.millisecondsSinceEpoch.toDouble();
            } else if (v is int) {
              return v.toDouble();
            }
          }

          // Fallback : utiliser l'id si disponible (ids croissants -> id plus élevé = plus récent)
          final idv = debt['id'];
          if (idv is int) return idv.toDouble();
          if (idv is String) return double.tryParse(idv) ?? 0.0;
          return 0.0;
        }

        for (final debt in list) {
          if (debt == null) continue;

          final clientId = debt['client_id'];
          if (clientId == null) continue;

          final type = (debt['type'] ?? 'debt').toString();
          final compKey = '${clientId.toString()}|$type';
          final remaining = (debt['remaining'] as num?)?.toDouble() ?? 0.0;
          final ts = tsForDebt(debt);

          if (debtsByKey.containsKey(compKey)) {
            final existing = debtsByKey[compKey]!;
            final existingTs = (existing['_ts'] as double?) ?? 0.0;
            // Remplacer si cette dette est plus récente
            if (ts >= existingTs) {
              debtsByKey[compKey] = {
                ...debt,
                'remaining': remaining,
                '_ts': ts,
              };
            } else {
              // garder l'existante (plus récente)
            }
          } else {
            debtsByKey[compKey] = {
              ...debt,
              'remaining': remaining,
              '_ts': ts,
            };
          }
        }
        
        // Convertir en liste (chaque entrée correspond à client+type)
        List<Map<String, dynamic>> consolidatedDebts = debtsByKey.values.toList();
        
        // Filtrer par recherche si nécessaire
        if (query != null && query.isNotEmpty) {
          consolidatedDebts = consolidatedDebts.where((d) {
            final clientName = _clientNameForDebt(d)?.toLowerCase() ?? '';
            return clientName.contains(query.toLowerCase());
          }).toList();
        }

        // ✅ OPTIMISATION: Le backend retourne déjà les valeurs correctes de remaining,
        // total_additions, et total_debt via calculateDebtBalance(). 
        // On FAIT CONFIANCE au backend pour éviter de surcharger le réseau avec des appels supplémentaires.
        // Le remaining retourné par GET /debts est calculé en temps réel avec la formule:
        // remaining = (amount + total_additions) - total_payments

        // Vérifier si les données ont vraiment changé avant setState
        if (consolidatedDebts.length != debts.length || consolidatedDebts.toString() != debts.toString()) {
          if (mounted) {
            setState(() => debts = consolidatedDebts);
          }
        }
        // ✅ NOUVEAU: Mettre à jour Hive pour garder le cache local synchronisé
        await _saveDebtsLocally();
        print('✅ fetchDebts completed. Consolidated ${consolidatedDebts.length} debts');
      }
    } on TimeoutException {
      print('⏱️ Timeout fetching debts (8s) - using cached data');
      // Charger depuis le cache local si disponible
      await _loadDebtsLocally();
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Error fetching debts: $e');
      // Charger depuis le cache local si disponible
      await _loadDebtsLocally();
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _clientNameForDebt(dynamic d) {
    if (d == null) return null;
    
    // ✅ NOUVEAU: Si la dette a été créée par quelqu'un d'autre, afficher le nom du créancier
    if (d['created_by_other'] == true) {
      // Priorité 1: creditor_name_custom (nom personnalisé)
      var creditorName = d['creditor_name_custom']?.toString() ?? '';
      // Priorité 2: display_creditor_name (du backend)
      if (creditorName.isEmpty) {
        creditorName = d['display_creditor_name']?.toString() ?? '';
      }
      // Priorité 3: creditor_phone (fallback)
      if (creditorName.isEmpty) {
        creditorName = d['creditor_phone']?.toString() ?? '';
      }
      if (creditorName.isNotEmpty) {
        return creditorName;
      }
    }
    
    // Sinon, chercher le nom du client normalement
    final cid = d['client_id'];
    if (cid == null) return null;
    final c = clients.firstWhere((x) => x['id'] == cid, orElse: () => null);
    return c != null ? c['name'] : null;
  }

  Widget _buildInitialsAvatar(String initials, double size) {
    return Center(
      child: Icon(
        Icons.person_rounded,
        size: size * 0.55,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withOpacity(0.55)
            : Colors.black.withOpacity(0.45),
      ),
    );
  }

  Widget _buildClientAvatarWidget(dynamic client, double size) {
    final hasAvatar = client != null && client['avatar_url'] != null && client['avatar_url'].toString().isNotEmpty;
    final clientName = HomePageMethods.getClientName(client);
    final initials = HomePageMethods.getInitials(clientName);
    final avatarColor = HomePageMethods.getAvatarColor(client);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: avatarColor.withOpacity(0.12),  // ✅ Fond très subtil
        border: Border.all(
          color: avatarColor.withOpacity(0.25),  // ✅ Bordure subtile
          width: 1.5,
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
        builder: (c) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final bgColor = isDark ? const Color.fromARGB(255, 0, 0, 0) : Colors.white;
  final textColor = isDark ? Colors.white : Colors.black;
  
  return Dialog(
    backgroundColor: const Color.fromARGB(255, 0, 0, 0),
    child: Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_add_outlined,
            size: 48,
            color: textColor.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun ${HomePageMethods.getTermClient()}',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Voulez-vous en ajouter un maintenant ?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: textColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(c).pop(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: textColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: textColor.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Annuler',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor.withOpacity(0.7),
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(c).pop(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color.fromARGB(210, 37, 0, 123).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Ajouter',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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
  );
},
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

final choice = await showModalBottomSheet<String>(
  context: context,
  backgroundColor: Colors.transparent,
  builder: (ctx) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color.fromARGB(255, 255, 255, 255).withOpacity(0.08),
          width: 1.3,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Nouvelle transaction',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 20),
          
          // Boutons côte à côte
          Row(
            children: [
              // PRÊTER
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop('preter'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD86C01).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFD86C01).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.arrow_upward_rounded,
                          color: Color(0xFFD86C01),
                          size: 28,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Prêter',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD86C01),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // EMPRUNTER
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop('emprunter'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF312157).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color.fromARGB(255, 125, 29, 125).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.arrow_downward_rounded,
                          color: Color.fromARGB(255, 125, 29, 125),
                          size: 28,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Emprunter',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color.fromARGB(255, 125, 29, 125),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  },
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
    print('[DEBUG] Opening DebtDetailsPage with debt: ${d['id']}, remaining: ${d['remaining']}');
    final res = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DebtDetailsPage(ownerPhone: widget.ownerPhone, debt: d)),
    );
    print('[DEBUG] DebtDetailsPage returned: $res');
    // ✅ RECHARGER COMPLÈTEMENT APRÈS TOUTE FERMETURE DE LA PAGE
    if (res == true) {
      print('[DEBUG] Reloading data after debt details...');
      // Recharger sans cache - forcer une nouvelle requête HTTP complète
      await fetchClients();  // Recharger les clients aussi
      print('[DEBUG] Clients reloaded. Count: ${clients.length}');
      await fetchDebts();    // Recharger les dettes
      print('[DEBUG] Debts reloaded. Count: ${debts.length}. New remaining values:');
      for (final d in debts.take(3)) {
        print('  - Debt ${d['id']}: remaining=${d['remaining']}');
      }
      // ✅ FORCER UNE RECONSTRUCTION DU WIDGET pour invalider tout cache local
      if (mounted) {
        print('[DEBUG] Calling setState to rebuild...');
        setState(() {});
        print('[DEBUG] setState completed');
      }
    }
  }

  // ✨ NOUVEAU : Modifier un client
  Future<void> _editClient(dynamic client) async {
    if (client == null) return;
    
    final nameCtl = TextEditingController(text: client['name'] ?? '');
    final numberCtl = TextEditingController(text: client['client_number']?.toString() ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final textColorSecondary = isDark ? Colors.white70 : Colors.black54;
    
    final ok = await showDialog<bool>(
      context: context,
      builder: (dlg) => Dialog(
        backgroundColor: Theme.of(context).cardColor,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MODIFIER ${HomePageMethods.getTermClientUp()}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtl,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Nom',
                  labelStyle: TextStyle(color: textColorSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: textColorSecondary.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: numberCtl,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Numéro',
                  labelStyle: TextStyle(color: textColorSecondary),
                  hintText: 'Optionnel',
                  hintStyle: TextStyle(color: textColorSecondary.withOpacity(0.5)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: textColorSecondary.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(dlg).pop(false),
                    child: Text('Annuler', style: TextStyle(color: textColorSecondary)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.of(dlg).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                    child: const Text('Enregistrer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (ok == true && nameCtl.text.trim().isNotEmpty) {
      try {
        final headers = {
          'Content-Type': 'application/json',
          if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone
        };
        final body = {
          'name': nameCtl.text.trim(),
          'client_number': numberCtl.text.trim().isNotEmpty ? numberCtl.text.trim() : null,
        };

        final res = await http.put(
          Uri.parse('$apiHost/clients/${client['id']}'),
          headers: headers,
          body: json.encode(body),
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          await fetchClients();
          await fetchDebts(); // ✅ Recharger les dettes aussi pour mettre à jour les noms partout
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${HomePageMethods.getTermClientUp()} modifié avec succès')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Erreur lors de la modification')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }

  Widget _buildDebtsTab() {
    // ✅ NOUVEAU : Calculer les PRÊTS et EMPRUNTS séparément
    final totalPrets = HomePageMethods.calculateTotalPrets(debts);
    final totalEmprunts = HomePageMethods.calculateTotalEmprunts(debts);
    
    // Ancien calcul pour compatibilité
    final netBalance = HomePageMethods.calculateNetBalance(debts);
    
    // ✅ NOUVEAU : Calculer les impayés de manière dynamique selon _debtSubTab
    int totalUnpaid = 0;
    if (_debtSubTab == 'prets') {
      totalUnpaid = debts.where((d) {
        if ((d['type'] ?? 'debt') != 'debt') return false;
        final remaining = (d['remaining'] as double?) ?? 0.0;
        return remaining > 0;
      }).length;
    } else if (_debtSubTab == 'emprunts') {
      totalUnpaid = debts.where((d) {
        if ((d['type'] ?? 'debt') != 'loan') return false;
        final remaining = (d['remaining'] as double?) ?? 0.0;
        return remaining > 0;
      }).length;
    } else {
      // Affichage total (tous les types)
      totalUnpaid = debts.where((d) {
        final remaining = (d['remaining'] as double?) ?? 0.0;
        return remaining > 0;
      }).length;
    }

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

    // Filtrer par sous-onglet actif (PRÊTS ou EMPRUNTS)
    if (_debtSubTab == 'prets') {
      filteredDebts = filteredDebts.where((d) => (d['type'] ?? 'debt') == 'debt').toList();
    } else if (_debtSubTab == 'emprunts') {
      filteredDebts = filteredDebts.where((d) => (d['type'] ?? 'debt') == 'loan').toList();
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

    List<MapEntry<String, List>> groups = grouped.entries.toList();
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

    // Séparer les groupes récents en PRÊTS puis EMPRUNTS strictement
    final prets = groups.where((e) => e.key.toString().endsWith('|debt')).toList();
    final emprunts = groups.where((e) => e.key.toString().endsWith('|loan')).toList();
    final others = groups.where((e) => !e.key.toString().endsWith('|debt') && !e.key.toString().endsWith('|loan')).toList();

    // Nous n'afficherons PAS les emprunts dans la section prêts et vice-versa.
    // Reste possible de montrer 'others' (types inconnus) après.
    groups = [...prets, ...others, ...emprunts];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final textColorSecondary = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? const Color.fromARGB(164, 65, 55, 71) : const Color.fromARGB(66, 9, 7, 11);

    // Préparer la liste rendue des récents selon le sous-onglet actif
    final List<dynamic> recentItems = [];
    if (_debtSubTab == 'prets') {
      recentItems.addAll(prets);
      if (others.isNotEmpty) {
        recentItems.add('OTHERS_HEADER');
        recentItems.addAll(others);
      }
    } else if (_debtSubTab == 'emprunts') {
      recentItems.addAll(emprunts);
      if (others.isNotEmpty) {
        recentItems.add('OTHERS_HEADER');
        recentItems.addAll(others);
      }
    } else {
      recentItems.addAll(prets);
      if (others.isNotEmpty) {
        recentItems.add('OTHERS_HEADER');
        recentItems.addAll(others);
      }
      if (emprunts.isNotEmpty) {
        recentItems.add('EMPRUNTS_HEADER');
        recentItems.addAll(emprunts);
      }
    }

    return RefreshIndicator(
      onRefresh: () async => await fetchDebts(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        // 1 header + recentItems
        itemCount: 1 + recentItems.length,
        itemBuilder: (ctx, gi) {
          if (gi == 0) {
            // Main header (totals, filter, etc.)
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
                        // Affiche soit le solde net, soit le total sélectionné (PRÊTS/EMPRUNTS)
                        Builder(builder: (_) {
                          if (_debtSubTab == 'prets') {
                            return Text(
                              'PRÊTS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                                color: textColorSecondary,
                              ),
                            );
                          }
                          if (_debtSubTab == 'emprunts') {
                            return Text(
                              'EMPRUNTS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                                color: textColorSecondary,
                              ),
                            );
                          }
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
                                    double displayValue = 0.0;
                                    Color amtColor = textColor;

                                    if (_debtSubTab == 'prets') {
                                      displayValue = totalPrets;
                                      amtColor = Colors.orange;
                                    } else if (_debtSubTab == 'emprunts') {
                                      displayValue = totalEmprunts;
                                      amtColor = Colors.purple;
                                    } else {
                                      final bool oweMoney = netBalance < 0;
                                      displayValue = oweMoney ? netBalance.abs() : netBalance;
                                      amtColor = oweMoney ? const Color.fromARGB(231, 141, 47, 219) : textColor;
                                    }

                                    final display = AppSettings().formatCurrency(displayValue);
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
                        // ✅ NOUVEAU : Affichage des PRÊTS et EMPRUNTS séparés avec trait subtile
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _debtSubTab = _debtSubTab == 'prets' ? '' : 'prets'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: _debtSubTab == 'prets' 
                                          ? Colors.orange
                                          : Colors.orange.withOpacity(0.2),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.trending_up,
                                        size: 13,
                                        color: _debtSubTab == 'prets'
                                            ? Colors.orange
                                            : Colors.orange.withOpacity(0.5),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'PRÊTS',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _debtSubTab == 'prets'
                                              ? Colors.orange
                                              : Colors.orange.withOpacity(0.5),
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _debtSubTab = _debtSubTab == 'emprunts' ? '' : 'emprunts'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: _debtSubTab == 'emprunts' 
                                          ? Colors.purple
                                          : Colors.purple.withOpacity(0.2),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.trending_down,
                                        size: 13,
                                        color: _debtSubTab == 'emprunts'
                                            ? Colors.purple
                                            : Colors.purple.withOpacity(0.5),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'EMPRUNTS',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _debtSubTab == 'emprunts'
                                              ? Colors.purple
                                              : Colors.purple.withOpacity(0.5),
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // 💎 DETTES IMPAYÉES - Petit cercle minimaliste centré (simplifié sans animation)
                        GestureDetector(
                          onTap: () => setState(() => _showUnpaidDetails = !_showUnpaidDetails),
                          child: Center(
                            child: Container(
                              width: _showUnpaidDetails ? 60 : 48,
                              height: _showUnpaidDetails ? 60 : 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: totalUnpaid > 0
                                    ? Colors.red.withOpacity(0.08)
                                    : Colors.green.withOpacity(0.08),
                                border: Border.all(
                                  color: totalUnpaid > 0
                                      ? Colors.red.withOpacity(_showUnpaidDetails ? 0.4 : 0.15)
                                      : Colors.green.withOpacity(_showUnpaidDetails ? 0.4 : 0.15),
                                  width: _showUnpaidDetails ? 1.5 : 0.8,
                                ),
                              ),
                              child: Center(
                                child: _showUnpaidDetails
                                    ? Text(
                                        '$totalUnpaid',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: totalUnpaid > 0 ? Colors.red : Colors.green,
                                          letterSpacing: 0.5,
                                        ),
                                      )
                                    : Icon(
                                        totalUnpaid > 0 ? Icons.warning_amber_rounded : Icons.check_circle,
                                        size: 20,
                                        color: totalUnpaid > 0
                                            ? Colors.red.withOpacity(0.6)
                                            : Colors.green.withOpacity(0.6),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // 💎 Filtre par montant - Badge minimaliste
                GestureDetector(
                  onTap: () => setState(() => _showAmountFilter = !_showAmountFilter),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _showAmountFilter
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                            : Colors.transparent,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withOpacity(
                            _showAmountFilter ? 0.3 : 0.1,
                          ),
                          width: 0.8,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showAmountFilter ? Icons.unfold_less : Icons.unfold_more,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary.withOpacity(
                              _showAmountFilter ? 0.8 : 0.4,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'MONTANT',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6,
                              color: Theme.of(context).colorScheme.primary.withOpacity(
                                _showAmountFilter ? 0.8 : 0.5,
                              ),
                            ),
                          ),
                          if (_minDebtAmount > 0 || _maxDebtAmount > 0)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
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
                // 💎 Section RÉCENT - Ligne minimaliste élégante
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 0.5,
                        color: borderColor,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'RÉCENT',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.3,
                          color: textColorSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 0.5,
                        color: borderColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            );
          }

          // Rendu des entrées récentes (prets / others / emprunts) selon recentItems
          final idx = gi - 1; // index into recentItems
          final item = recentItems[idx];
          if (item is String) {
            // section header markers
            if (item == 'OTHERS_HEADER') {
              return Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 6, left: 4),
                child: Text('AUTRES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textColorSecondary)),
              );
            }
            if (item == 'EMPRUNTS_HEADER') {
              return Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 6, left: 4),
                child: Text('EMPRUNTS RÉCENTS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textColorSecondary)),
              );
            }
          }
          final entry = item as MapEntry<String, List>;
          final compositeKey = entry.key.toString();
          final clientDebts = entry.value;
          final parts = compositeKey.split('|');
          final clientIdPart = parts.isNotEmpty ? parts[0] : 'unknown';
          final txType = parts.length > 1 ? parts[1] : 'debt';
          final dynamic clientId = clientIdPart == 'unknown' ? 'unknown' : (int.tryParse(clientIdPart) ?? clientIdPart);
          final client = clients.firstWhere((x) => x['id'] == clientId, orElse: () => null);
          
          // ✅ NOUVEAU: Si la dette a été créée par quelqu'un d'autre, afficher le creditor_name
          String clientName;
          String? clientPhone; // ✅ Numéro séparé pour affichage élégant
          if (clientDebts.isNotEmpty && clientDebts.first['created_by_other'] == true) {
            // C'est une dette créée par un propriétaire pour moi, afficher son nom + numéro
            // ✅ NOUVEAU : Priorité 1: creditor_name_custom (si on a personnalisé le nom)
            var displayCreditorName = clientDebts.first['creditor_name_custom']?.toString() ?? '';
            // ✅ Priorité 2: display_creditor_name (nom venant du backend)
            if (displayCreditorName.isEmpty) {
              displayCreditorName = clientDebts.first['display_creditor_name']?.toString() ?? '';
            }
            final creditorPhone = clientDebts.first['creditor_phone']?.toString() ?? '';  // ✅ Le numéro du créancier
            clientName = displayCreditorName.isNotEmpty 
                ? displayCreditorName
                : (creditorPhone.isNotEmpty ? creditorPhone : (client != null ? client['name'] : '${AppSettings().boutiqueModeEnabled ? 'Client' : 'Contact'} $clientId'));
            clientPhone = creditorPhone.isNotEmpty ? creditorPhone : null;  // ✅ Stocker le phone séparement
          } else {
            // C'est une dette normale, afficher le nom du client
            clientName = client != null ? client['name'] : (clientId == 'unknown' ? (AppSettings().boutiqueModeEnabled ? 'Clients inconnus' : 'Contacts inconnus') : '${AppSettings().boutiqueModeEnabled ? 'Client' : 'Contact'} $clientId');
            clientPhone = client?['client_number'] ?? client?['phone']; // ✅ CORRIGÉ
          }

          // Calculer le total : ne prendre que la dette la plus récente pour le couple (client,type)
          double totalRemaining = 0.0;
          Map<String, dynamic>? latestDebt;
          if (clientDebts.isNotEmpty) {
            latestDebt = clientDebts.reduce((a, b) => HomePageMethods.tsForDebt(b) >= HomePageMethods.tsForDebt(a) ? b : a);
            totalRemaining = ((latestDebt?['remaining'] as num?)?.toDouble() ?? 0.0);
          }

          final bool isOpen = _expandedClients.contains(compositeKey);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(0),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () {
                    if (clientDebts.isNotEmpty) {
                      // ✅ Afficher la dernière dette (celle avec la due_date la plus pertinente)
                      showDebtDetails(latestDebt ?? clientDebts.first);
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // ✅ NOM ÉLÉGANT (EN HAUT) - style titre
                              Text(
                                clientName.toString(),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: textColor,
                                  letterSpacing: 0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              // ✅ LIGNE AVEC NUMÉRO ET DATE
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // ✅ NUMÉRO À GAUCHE - seulement si pas dans les contacts
                                    if (clientPhone != null && clientPhone.isNotEmpty && client == null)
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(3),
                                            border: Border.all(
                                              color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                              width: 0.5,
                                            ),
                                          ),
                                          child: Text(
                                            clientPhone,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Theme.of(context).colorScheme.primary,
                                              fontWeight: FontWeight.w500,
                                              letterSpacing: 0.2,
                                              fontFamily: 'monospace',
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    // ✅ ESPACEMENT ADAPTATIF
                                    if (clientPhone != null && clientPhone.isNotEmpty && client == null && latestDebt != null && latestDebt['due_date'] != null)
                                      const SizedBox(width: 8),
                                    // ✅ DATE À DROITE - ou centrée si pas de numéro
                                    if (latestDebt != null && latestDebt['due_date'] != null)
                                      Builder(
                                        builder: (_) {
                                          final dueInfo = _formatDueDate(latestDebt?['due_date']);
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: (dueInfo['color'] as Color).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(3),
                                              border: Border.all(
                                                color: (dueInfo['color'] as Color).withOpacity(0.2),
                                                width: 0.5,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  dueInfo['icon'] as IconData,
                                                  size: 11,
                                                  color: dueInfo['color'] as Color,
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  dueInfo['text'] as String,
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w600,
                                                    color: dueInfo['color'] as Color,
                                                    letterSpacing: 0.3,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                  ],
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
                                isLoan ? 'je dois' : (clientOwe ? 'je dois' : 'à percevoir'),
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
                            } else if (v == 'edit') {
                              // ✨ NOUVEAU : Modifier le client
                              await _editClient(client);
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
                            // ✨ NOUVEAU : Option modifier
                            PopupMenuItem<String>(
                              value: 'edit',
                              child: Row(
                                children: [
                                  const Icon(Icons.edit, size: 18, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Text('Modifier', style: TextStyle(color: textColor)),
                                ],
                              ),
                            ),
                          ],
                          offset: const Offset(0, 40),
                          child: Icon(Icons.more_vert, color: textColor, size: 16),
                        ),
                        // ✅ Rotation simple sans animation (améliore la stabilité)
                        Transform.rotate(
                          angle: isOpen ? 0.785398 : 0.0, // 45 degrees
                          child: Icon(Icons.expand_more, color: textColor, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
                // ✅ NOUVEAU : Trait fin et centré
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 4),
                  child: Container(
                    height: 0.5,
                    color: borderColor,
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
                      }),
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
    List<dynamic> filtered = [];
    for (final c in clients) {
      if (_searchQuery.isEmpty) {
        filtered.add(c);
      } else {
        final name = (c['name'] ?? '').toString().toLowerCase();
        if (name.contains(_searchQuery.toLowerCase())) {
          filtered.add(c);
        }
      }
    }

    filtered.sort((dynamic a, dynamic b) {
  if (a == null || b == null) return 0;
  final ra = HomePageMethods.clientTotalRemaining(a['id'], debts);
  final rb = HomePageMethods.clientTotalRemaining(b['id'], debts);
  final sa = ra > 0 ? 0 : 1;
  final sb = rb > 0 ? 0 : 1;
  if (sa != sb) return sa - sb;
  
  // Use explicit string comparison to avoid type issues
  final nameA = (a['name'] ?? '').toString().toLowerCase();
  final nameB = (b['name'] ?? '').toString().toLowerCase();
  return nameA.compareTo(nameB);
});

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final textColorSecondary = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? const Color.fromARGB(255, 0, 0, 0) : const Color.fromARGB(0, 0, 0, 0);

    return RefreshIndicator(
      onRefresh: () async => await fetchClients(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filtered.length,
        itemBuilder: (ctx, i) {
          final c = filtered[i];
          
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
                HomePageMethods.getClientName(c).toUpperCase(),
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
              trailing: PopupMenuButton<String>(
                constraints: const BoxConstraints(maxWidth: 200),
                onSelected: (v) async {
                  if (v == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Supprimer le ${HomePageMethods.getTermClient()}'),
                        content: Text('Voulez-vous vraiment supprimer ${c['name'] ?? 'ce ${HomePageMethods.getTermClient()}'} ?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
                          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Supprimer')),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      try {
                        final headers = {'Content-Type': 'application/json', if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone};
                        final res = await http.delete(Uri.parse('$apiHost/clients/${c['id']}'), headers: headers).timeout(const Duration(seconds: 8));
                        if (res.statusCode == 200) {
                          await fetchClients();
                          await fetchDebts();
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${HomePageMethods.getTermClientUp()} supprimé')));
                        } else {
                          // Parse error message and provide friendly feedback
                          String errorMessage = 'Erreur lors de la suppression';
                          try {
                            final errorBody = json.decode(res.body);
                            if (errorBody['message'] != null) {
                              if (errorBody['message'].toString().contains('existing debt') || 
                                  errorBody['message'].toString().contains('dette') ||
                                  errorBody['message'].toString().contains('emprunt')) {
                                errorMessage = 'Impossible de supprimer ce ${HomePageMethods.getTermClient()} car il possède des dettes ou des emprunts associés.\n\nConseil: Vous pouvez d\'abord clôturer toutes les dettes/emprunts liés avant de le supprimer.';
                              } else {
                                errorMessage = errorBody['message'].toString();
                              }
                            }
                          } catch (_) {
                            errorMessage = 'Erreur: ${res.statusCode}';
                          }
                          
                          if (mounted) {
                            await showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('⚠️ Suppression impossible'),
                                content: Text(errorMessage),
                                actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('D\'accord'))]
                              )
                            );
                          }
                        }
                      } catch (e) {
                        if (mounted) await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Erreur réseau'), content: Text('$e'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))]));
                      }
                    }
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete, size: 18, color: Colors.red),
                        const SizedBox(width: 8),
                        Text('Supprimer ${HomePageMethods.getTermClient()}', style: TextStyle(color: textColor)),
                      ],
                    ),
                  ),
                ],
                offset: const Offset(0, 40),
                child: Icon(Icons.more_vert, color: textColor, size: 16),
              ),
              onTap: () {
  // Récupérer toutes les dettes du client
  final clientDebts = debts.where((d) => d['client_id'] == c['id']).toList();
  
  if (clientDebts.isEmpty) {
    // Aucune dette - proposer de créer un prêt ou un emprunt
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDark ? const Color.fromARGB(255, 0, 0, 5) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black;
        
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Aucune transaction',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ce ${HomePageMethods.getTermClient()} n\'a aucune transaction.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 24),
                
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(ctx).pop();
                          Future.delayed(const Duration(milliseconds: 300), () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AddDebtPage(
                                  ownerPhone: widget.ownerPhone,
                                  clients: clients,
                                  preselectedClientId: c['id'],
                                ),
                              ),
                            );
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD86C01).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFD86C01).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.arrow_upward_rounded,
                                color: Color(0xFFD86C01),
                                size: 24,
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Prêter',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFD86C01),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(ctx).pop();
                          Future.delayed(const Duration(milliseconds: 300), () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AddLoanPage(
                                  ownerPhone: widget.ownerPhone,
                                  clients: clients,
                                ),
                              ),
                            );
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF312157).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF312157).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.arrow_downward_rounded,
                                color: Color(0xFF312157),
                                size: 24,
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Emprunter',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF312157),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    child: Text(
                      'Annuler',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textColor.withOpacity(0.6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  } else if (clientDebts.length == 1) {
    // Une seule dette - rediriger directement
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DebtDetailsPage(ownerPhone: widget.ownerPhone, debt: clientDebts.first),
      ),
    );
  } else {
    // Plusieurs dettes - demander à l'utilisateur de choisir
    final prets = clientDebts.where((d) => (d['type'] ?? 'debt') == 'debt').toList();
    final emprunts = clientDebts.where((d) => (d['type'] ?? 'debt') == 'loan').toList();
    
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDark ? const Color.fromARGB(255, 1, 0, 3) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black;
        
        return Dialog(
          backgroundColor: const Color.fromARGB(229, 0, 0, 0),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choisir la transaction',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ce ${HomePageMethods.getTermClient()} a ${clientDebts.length} transactions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 24),
                
                Row(
                  children: [
                    if (prets.isNotEmpty)
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(ctx).pop();
                            Future.delayed(const Duration(milliseconds: 300), () {
                              dynamic latestPret = prets[0];
                              double latestTs = HomePageMethods.tsForDebt(latestPret);
                              
                              for (int i = 1; i < prets.length; i++) {
                                final current = prets[i];
                                final currentTs = HomePageMethods.tsForDebt(current);
                                if (currentTs >= latestTs) {
                                  latestPret = current;
                                  latestTs = currentTs;
                                }
                              }
                              
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DebtDetailsPage(ownerPhone: widget.ownerPhone, debt: latestPret),
                                ),
                              );
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD86C01).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFD86C01).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.arrow_upward_rounded,
                                  color: Color(0xFFD86C01),
                                  size: 24,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  prets.length > 1 ? 'Prêts (${prets.length})' : 'Prêt',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFD86C01),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    
                    if (prets.isNotEmpty && emprunts.isNotEmpty)
                      const SizedBox(width: 12),
                    
                    if (emprunts.isNotEmpty)
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(ctx).pop();
                            Future.delayed(const Duration(milliseconds: 300), () {
                              dynamic latestEmprunt = emprunts[0];
                              double latestTs = HomePageMethods.tsForDebt(latestEmprunt);
                              
                              for (int i = 1; i < emprunts.length; i++) {
                                final current = emprunts[i];
                                final currentTs = HomePageMethods.tsForDebt(current);
                                if (currentTs >= latestTs) {
                                  latestEmprunt = current;
                                  latestTs = currentTs;
                                }
                              }
                              
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DebtDetailsPage(ownerPhone: widget.ownerPhone, debt: latestEmprunt),
                                ),
                              );
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 74, 33, 87).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color.fromARGB(255, 60, 41, 103).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.arrow_downward_rounded,
                                  color: Color.fromARGB(255, 85, 28, 104),
                                  size: 24,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  emprunts.length > 1 ? 'Emprunts (${emprunts.length})' : 'Emprunt',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color.fromARGB(255, 85, 28, 104),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    child: Text(
                      'Annuler',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textColor.withOpacity(0.6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
},
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
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final textColorSecondary = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: colors.surface,
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
                              if (widget.hasPinSet)
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
      body: _isLoading && debts.isEmpty && clients.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Chargement des données...'),
                  const SizedBox(height: 8),
                  Text(
                    '(Depuis le cache si l\'API est lente)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _isLoading = true);
                      _loadBoutique();
                      fetchClients();
                      fetchDebts();
                    },
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            )
          : _tabIndex == 0 ? _buildDebtsTab() : _buildClientsTab(),
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
                          Text(HomePageMethods.getTermClientUp(), style: TextStyle(fontSize: 11, color: _tabIndex == 1 ? textColor : textColorSecondary)),
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
