import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:boutique_mobile/hive/models/index.dart';
import 'package:boutique_mobile/hive/services/conflict_resolver.dart';
import 'package:boutique_mobile/hive/services/sync_queue.dart';

/// Service de stockage local avec synchronisation bidirectionnelle
/// Utilise des listes en mémoire pour stocker les données
class HiveService {
  // Données locales en mémoire
  final List<HiveClient> _clients = [];
  final List<HiveDebt> _debts = [];
  final List<HivePayment> _payments = [];
  final List<HiveDebtAddition> _additions = [];
  final List<HiveSyncStatus> _syncStatus = [];

  late SyncQueue _syncQueue;

  // API Configuration
  final String apiBaseUrl;
  final String _clientsEndpoint = '/clients';
  final String _debtsEndpoint = '/debts';
  final String _paymentsEndpoint = '/payments';
  final String _additionsEndpoint = '/debt-additions';

  // Connectivity
  late Connectivity _connectivity;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription; // ✅ CORRIGÉ
  bool _isOnline = true;

  // Sync status
  bool _isSyncing = false;
  Timer? _autoSyncTimer;
  final Duration _autoSyncInterval = const Duration(minutes: 5);

  HiveService({required this.apiBaseUrl});

  /// Initialise le service Hive
  Future<void> init({
    required String ownerPhone,
    String? encryptionKey,
  }) async {
    try {
      // Initialiser la queue de synchronisation
      _syncQueue = await SyncQueue.init();

      // Initialiser la connectivité
      _connectivity = Connectivity();
      _connectivitySubscription =
          _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);

      // Vérifier la connectivité initiale
      final List<ConnectivityResult> results = await _connectivity.checkConnectivity(); // ✅ CORRIGÉ
      _isOnline = results.isNotEmpty && results[0] != ConnectivityResult.none; // ✅ CORRIGÉ

      // Initialiser ou récupérer le statut de sync
      _initSyncStatus(ownerPhone);

      // Démarrer la synchronisation automatique
      _startAutoSync(ownerPhone);

      print('HiveService initialized for $ownerPhone');
    } catch (e) {
      print('Error initializing HiveService: $e');
      rethrow;
    }
  }

  void _initSyncStatus(String ownerPhone) {
    try {
      _syncStatus.firstWhere((s) => s.ownerPhone == ownerPhone);
      // Status déjà existant
    } catch (e) {
      // Créer un nouveau statut de sync
      final syncStatus = HiveSyncStatus(
        ownerPhone: ownerPhone,
        lastSyncAt: DateTime.now().subtract(const Duration(days: 1)),
        nextSyncAt: DateTime.now(),
        isOnline: _isOnline,
      );
      _syncStatus.add(syncStatus);
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) { // ✅ CORRIGÉ
    _isOnline = results.isNotEmpty && results[0] != ConnectivityResult.none; // ✅ CORRIGÉ
    print('Connectivity changed: ${_isOnline ? 'Online' : 'Offline'}');

    // Déclencher la synchronisation si on est en ligne
    if (_isOnline && !_isSyncing) {
      _triggerSync();
    }
  }

  void _startAutoSync(String ownerPhone) {
    _autoSyncTimer = Timer.periodic(_autoSyncInterval, (_) {
      if (_isOnline && !_isSyncing) {
        syncWithServer(ownerPhone);
      }
    });
  }

  /// Sauvegarde un client localement
  Future<void> saveClient(HiveClient client) async {
    try {
      // Chercher si le client existe
      try {
        final index = _clients.indexWhere((c) => c.id == client.id);
        _clients[index] = client.copyWith(needsSync: true, updatedAt: DateTime.now());
      } catch (e) {
        // Ajouter
        _clients.add(client.copyWith(needsSync: true, updatedAt: DateTime.now()));
      }

      // Ajouter à la queue de sync
      await _syncQueue.enqueue(
        operationType: 'create',
        entityType: 'client',
        entityId: client.id,
        ownerPhone: client.ownerPhone,
        payload: client.toJson(),
        priority: 1,
      );
    } catch (e) {
      print('Error saving client: $e');
      rethrow;
    }
  }

  /// Récupère tous les clients d'un propriétaire
  List<HiveClient> getClients(String ownerPhone) {
    return _clients.where((c) => c.ownerPhone == ownerPhone).toList();
  }

  /// Récupère un client par ID
  HiveClient? getClient(int id) {
    try {
      return _clients.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Sauvegarde une dette localement
  Future<void> saveDebt(HiveDebt debt) async {
    try {
      try {
        final index = _debts.indexWhere((d) => d.id == debt.id);
        _debts[index] = debt.copyWith(needsSync: true, updatedAt: DateTime.now());
      } catch (e) {
        _debts.add(debt.copyWith(needsSync: true, updatedAt: DateTime.now()));
      }

      await _syncQueue.enqueue(
        operationType: 'create',
        entityType: 'debt',
        entityId: debt.id,
        ownerPhone: debt.ownerPhone,
        payload: debt.toJson(),
        priority: 1,
      );
    } catch (e) {
      print('Error saving debt: $e');
      rethrow;
    }
  }

  /// Récupère toutes les dettes d'un propriétaire
  List<HiveDebt> getDebts(String ownerPhone) {
    return _debts.where((d) => d.ownerPhone == ownerPhone).toList();
  }

  /// Récupère une dette par ID
  HiveDebt? getDebt(int id) {
    try {
      return _debts.firstWhere((d) => d.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Sauvegarde un paiement localement
  Future<void> savePayment(HivePayment payment) async {
    try {
      try {
        final index = _payments.indexWhere((p) => p.id == payment.id);
        _payments[index] = payment.copyWith(needsSync: true, updatedAt: DateTime.now());
      } catch (e) {
        _payments.add(payment.copyWith(needsSync: true, updatedAt: DateTime.now()));
      }

      await _syncQueue.enqueue(
        operationType: 'create',
        entityType: 'payment',
        entityId: payment.id,
        ownerPhone: payment.ownerPhone,
        payload: payment.toJson(),
        priority: 0,
      );
    } catch (e) {
      print('Error saving payment: $e');
      rethrow;
    }
  }

  /// Récupère tous les paiements d'un propriétaire
  List<HivePayment> getPayments(String ownerPhone) {
    return _payments.where((p) => p.ownerPhone == ownerPhone).toList();
  }

  /// Récupère les paiements d'une dette
  List<HivePayment> getDebtPayments(int debtId) {
    return _payments.where((p) => p.debtId == debtId).toList();
  }

  /// Sauvegarde une addition localement
  Future<void> saveDebtAddition(HiveDebtAddition addition) async {
    try {
      try {
        final index = _additions.indexWhere((a) => a.id == addition.id);
        _additions[index] = addition.copyWith(needsSync: true, updatedAt: DateTime.now());
      } catch (e) {
        _additions.add(addition.copyWith(needsSync: true, updatedAt: DateTime.now()));
      }

      await _syncQueue.enqueue(
        operationType: 'create',
        entityType: 'addition',
        entityId: addition.id,
        ownerPhone: addition.ownerPhone,
        payload: addition.toJson(),
        priority: 0,
      );
    } catch (e) {
      print('Error saving debt addition: $e');
      rethrow;
    }
  }

  /// Récupère toutes les additions d'un propriétaire
  List<HiveDebtAddition> getDebtAdditions(String ownerPhone) {
    return _additions.where((a) => a.ownerPhone == ownerPhone).toList();
  }

  /// Récupère les additions d'une dette
  List<HiveDebtAddition> getDebtAdditionsByDebtId(int debtId) {
    return _additions.where((a) => a.debtId == debtId).toList();
  }

  /// Synchronise avec le serveur
  Future<bool> syncWithServer(String ownerPhone, {String? token}) async {
    if (_isSyncing) return false;
    if (!_isOnline) {
      print('Device is offline. Queuing operations...');
      return false;
    }

    _isSyncing = true;
    print('Starting sync for $ownerPhone...');

    try {
      // Traiter la file d'attente
      await _processSyncQueue(ownerPhone, token);

      // Récupérer les données du serveur
      await _pullFromServer(ownerPhone, token);

      // Mettre à jour le statut de sync
      _updateSyncStatus(ownerPhone, success: true);

      return true;
    } catch (e) {
      print('Sync error: $e');
      _updateSyncStatus(ownerPhone, success: false, error: e.toString());
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _processSyncQueue(String ownerPhone, String? token) async {
    final operations = _syncQueue.getPendingOperations(ownerPhone);

    for (final operation in operations) {
      try {
        await _syncQueue.markAsProcessing(operation.id, true);

        final success =
            await _executeSyncOperation(operation, ownerPhone, token);

        if (success) {
          await _syncQueue.removeOperation(operation.id);
        } else {
          if (operation.retryCount < 3) {
            await _syncQueue.retryOperation(operation.id);
          } else {
            await _syncQueue.updateOperation(
              operation.id,
              success: false,
              error: 'Max retries exceeded',
              retryCount: operation.retryCount,
            );
          }
        }
      } catch (e) {
        print('Error processing operation ${operation.id}: $e');
        await _syncQueue.updateOperation(
          operation.id,
          success: false,
          error: e.toString(),
          retryCount: operation.retryCount + 1,
        );
      }
    }
  }

  Future<bool> _executeSyncOperation(
    HivePendingOperation operation,
    String ownerPhone,
    String? token,
  ) async {
    try {
      final headers = _buildHeaders(token);

      switch (operation.operationType) {
        case 'create':
          // ✅ Cas spécial pour les paiements et additions
          if (operation.entityType == 'payment') {
            return await _createPaymentRemote(operation.payload, headers);
          } else if (operation.entityType == 'addition') {
            return await _createAdditionRemote(operation.payload, headers);
          }
          return await _createRemote(
            operation.entityType,
            operation.payload,
            headers,
          );
        case 'update':
          return await _updateRemote(
            operation.entityType,
            operation.entityId,
            operation.payload,
            headers,
          );
        case 'delete':
          return await _deleteRemote(
            operation.entityType,
            operation.entityId,
            headers,
          );
        default:
          return false;
      }
    } catch (e) {
      print('Error executing sync operation: $e');
      return false;
    }
  }

  /// Crée un paiement via l'endpoint /debts/:id/pay
  Future<bool> _createPaymentRemote(
    Map<dynamic, dynamic> payload,
    Map<String, String> headers,
  ) async {
    try {
      final debtId = payload['debt_id'];
      if (debtId == null) {
        print('Error: payment missing debt_id');
        return false;
      }

      // Utiliser le bon endpoint: /debts/{debtId}/pay
      final response = await http.post(
        Uri.parse('$apiBaseUrl/debts/$debtId/pay'),
        headers: headers,
        body: jsonEncode({
          'amount': payload['amount'],
          'paid_at': payload['paid_at'],
          'notes': payload['notes'],
        }),
      ).timeout(const Duration(seconds: 30));

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('Error creating payment remote: $e');
      return false;
    }
  }

  /// Crée une addition via l'endpoint /debts/:id/add
  Future<bool> _createAdditionRemote(
    Map<dynamic, dynamic> payload,
    Map<String, String> headers,
  ) async {
    try {
      final debtId = payload['debt_id'];
      if (debtId == null) {
        print('Error: addition missing debt_id');
        return false;
      }

      // Utiliser le bon endpoint: /debts/{debtId}/add
      final response = await http.post(
        Uri.parse('$apiBaseUrl/debts/$debtId/add'),
        headers: headers,
        body: jsonEncode({
          'amount': payload['amount'],
          'added_at': payload['added_at'],
          'notes': payload['notes'],
        }),
      ).timeout(const Duration(seconds: 30));

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('Error creating addition remote: $e');
      return false;
    }
  }

  Future<void> _pullFromServer(String ownerPhone, String? token) async {
    try {
      final headers = _buildHeaders(token);

      // Récupérer les clients
      await _fetchAndSyncClients(ownerPhone, headers);

      // Récupérer les dettes
      await _fetchAndSyncDebts(ownerPhone, headers);

      // Récupérer les paiements
      await _fetchAndSyncPayments(ownerPhone, headers);

      // Récupérer les additions
      await _fetchAndSyncAdditions(ownerPhone, headers);
    } catch (e) {
      print('Error pulling from server: $e');
      rethrow;
    }
  }

  Future<void> _fetchAndSyncClients(
    String ownerPhone,
    Map<String, String> headers,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl$_clientsEndpoint?owner_phone=$ownerPhone'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final decodedData = jsonDecode(response.body);
        
        // Handle both direct list and wrapped list in 'data' field
        List<dynamic> clientsList;
        if (decodedData is List) {
          clientsList = decodedData;
        } else if (decodedData is Map && decodedData.containsKey('data')) {
          final dataField = decodedData['data'];
          if (dataField is List) {
            clientsList = dataField;
          } else {
            print('Unexpected data format for clients: $dataField');
            return;
          }
        } else {
          print('Unexpected response format for clients: $decodedData');
          return;
        }
        
        final clients = clientsList
            .map((c) {
              try {
                return HiveClient.fromJson(c as Map<String, dynamic>);
              } catch (e) {
                print('Error parsing client: $c, Error: $e');
                return null;
              }
            })
            .whereType<HiveClient>()
            .toList();

        for (final serverClient in clients) {
          final localClient = getClient(serverClient.id);
          if (localClient != null) {
            final result = ConflictResolver.resolveClientConflict(
              localClient: localClient,
              serverClient: serverClient,
            );

            if (result.isResolved) {
              await _updateLocalClient(result.resolvedData!);
            }
          } else {
            _clients.add(serverClient);
          }
        }
      }
    } catch (e) {
      print('Error fetching clients: $e');
    }
  }

  Future<void> _fetchAndSyncDebts(
    String ownerPhone,
    Map<String, String> headers,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl$_debtsEndpoint?owner_phone=$ownerPhone'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final decodedData = jsonDecode(response.body);
        
        // Handle both direct list and wrapped list in 'data' field
        List<dynamic> debtsList;
        if (decodedData is List) {
          debtsList = decodedData;
        } else if (decodedData is Map && decodedData.containsKey('data')) {
          final dataField = decodedData['data'];
          if (dataField is List) {
            debtsList = dataField;
          } else {
            print('Unexpected data format for debts: $dataField');
            return;
          }
        } else {
          print('Unexpected response format for debts: $decodedData');
          return;
        }
        
        final debts = debtsList
            .map((d) {
              try {
                return HiveDebt.fromJson(d as Map<String, dynamic>);
              } catch (e) {
                print('Error parsing debt: $d, Error: $e');
                return null;
              }
            })
            .whereType<HiveDebt>()
            .toList();

        for (final serverDebt in debts) {
          final localDebt = getDebt(serverDebt.id);
          if (localDebt != null) {
            final result = ConflictResolver.resolveDebtConflict(
              localDebt: localDebt,
              serverDebt: serverDebt,
            );

            if (result.isResolved) {
              await _updateLocalDebt(result.resolvedData!);
            }
          } else {
            _debts.add(serverDebt);
          }
        }
      }
    } catch (e) {
      print('Error fetching debts: $e');
    }
  }

  Future<void> _fetchAndSyncPayments(
    String ownerPhone,
    Map<String, String> headers,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl$_paymentsEndpoint?owner_phone=$ownerPhone'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final decodedData = jsonDecode(response.body);
        
        // Handle both direct list and wrapped list in 'data' field
        List<dynamic> paymentsList;
        if (decodedData is List) {
          paymentsList = decodedData;
        } else if (decodedData is Map && decodedData.containsKey('data')) {
          final dataField = decodedData['data'];
          if (dataField is List) {
            paymentsList = dataField;
          } else {
            print('Unexpected data format for payments: $dataField');
            return;
          }
        } else {
          print('Unexpected response format for payments: $decodedData');
          return;
        }

        final payments = paymentsList
            .map((p) {
              try {
                return HivePayment.fromJson(p as Map<String, dynamic>);
              } catch (e) {
                print('Error parsing payment: $p, Error: $e');
                return null;
              }
            })
            .whereType<HivePayment>()
            .toList();

        for (final serverPayment in payments) {
          HivePayment? localPayment;
          for (final p in _payments) {
            if (p.id == serverPayment.id) {
              localPayment = p;
              break;
            }
          }

          if (localPayment != null) {
            final result = ConflictResolver.resolvePaymentConflict(
              localPayment: localPayment,
              serverPayment: serverPayment,
            );

            if (result.isResolved) {
              await _updateLocalPayment(result.resolvedData!);
            }
          } else {
            _payments.add(serverPayment);
          }
        }
      }
    } catch (e) {
      print('Error fetching payments: $e');
    }
  }

  Future<void> _fetchAndSyncAdditions(
    String ownerPhone,
    Map<String, String> headers,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl$_additionsEndpoint?owner_phone=$ownerPhone'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final decodedData = jsonDecode(response.body);
        
        // Handle both direct list and wrapped list in 'data' field
        List<dynamic> additionsList;
        if (decodedData is List) {
          additionsList = decodedData;
        } else if (decodedData is Map && decodedData.containsKey('data')) {
          final dataField = decodedData['data'];
          if (dataField is List) {
            additionsList = dataField;
          } else {
            print('Unexpected data format for additions: $dataField');
            return;
          }
        } else {
          print('Unexpected response format for additions: $decodedData');
          return;
        }
        
        final additions = additionsList
            .map((a) {
              try {
                return HiveDebtAddition.fromJson(a as Map<String, dynamic>);
              } catch (e) {
                print('Error parsing addition: $a, Error: $e');
                return null;
              }
            })
            .whereType<HiveDebtAddition>()
            .toList();

        for (final serverAddition in additions) {
          HiveDebtAddition? localAddition;
          for (final a in _additions) {
            if (a.id == serverAddition.id) {
              localAddition = a;
              break;
            }
          }

          if (localAddition != null) {
            final result = ConflictResolver.resolveDebtAdditionConflict(
              localAddition: localAddition,
              serverAddition: serverAddition,
            );

            if (result.isResolved) {
              await _updateLocalAddition(result.resolvedData!);
            }
          } else {
            _additions.add(serverAddition);
          }
        }
      }
    } catch (e) {
      print('Error fetching additions: $e');
    }
  }

  Future<bool> _createRemote(
    String entityType,
    Map<dynamic, dynamic> payload,
    Map<String, String> headers,
  ) async {
    try {
      final endpoint = _getEndpoint(entityType);
      final response = await http.post(
        Uri.parse('$apiBaseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('Error creating remote $entityType: $e');
      return false;
    }
  }

  Future<bool> _updateRemote(
    String entityType,
    int entityId,
    Map<dynamic, dynamic> payload,
    Map<String, String> headers,
  ) async {
    try {
      final endpoint = _getEndpoint(entityType);
      final response = await http.put(
        Uri.parse('$apiBaseUrl$endpoint/$entityId'),
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating remote $entityType: $e');
      return false;
    }
  }

  Future<bool> _deleteRemote(
    String entityType,
    int entityId,
    Map<String, String> headers,
  ) async {
    try {
      final endpoint = _getEndpoint(entityType);
      final response = await http.delete(
        Uri.parse('$apiBaseUrl$endpoint/$entityId'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Error deleting remote $entityType: $e');
      return false;
    }
  }

  Future<void> _updateLocalClient(HiveClient client) async {
    try {
      final index = _clients.indexWhere((c) => c.id == client.id);
      _clients[index] = client;
    } catch (e) {
      // Not found
    }
  }

  Future<void> _updateLocalDebt(HiveDebt debt) async {
    try {
      final index = _debts.indexWhere((d) => d.id == debt.id);
      _debts[index] = debt;
    } catch (e) {
      // Not found
    }
  }

  Future<void> _updateLocalPayment(HivePayment payment) async {
    try {
      final index = _payments.indexWhere((p) => p.id == payment.id);
      _payments[index] = payment;
    } catch (e) {
      // Not found
    }
  }

  Future<void> _updateLocalAddition(HiveDebtAddition addition) async {
    try {
      final index = _additions.indexWhere((a) => a.id == addition.id);
      _additions[index] = addition;
    } catch (e) {
      // Not found
    }
  }

  void _updateSyncStatus(
    String ownerPhone, {
    required bool success,
    String? error,
  }) {
    try {
      final statusIndex =
          _syncStatus.indexWhere((s) => s.ownerPhone == ownerPhone);

      if (statusIndex != -1) {
        final status = _syncStatus[statusIndex];
        final updated = status.copyWith(
          lastSyncAt: DateTime.now(),
          nextSyncAt: DateTime.now().add(const Duration(minutes: 5)),
          isSyncing: false,
          lastError: error,
          failureCount: success ? 0 : (status.failureCount + 1),
          pendingOperationsCount:
              _syncQueue.getPendingCount(ownerPhone),
        );
        _syncStatus[statusIndex] = updated;
      }
    } catch (e) {
      print('Error updating sync status: $e');
    }
  }

  void _triggerSync() {
    print('Triggering sync...');
  }

  Map<String, String> _buildHeaders(String? token) {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  String _getEndpoint(String entityType) {
    switch (entityType) {
      case 'client':
        return _clientsEndpoint;
      case 'debt':
        return _debtsEndpoint;
      case 'payment':
        return _paymentsEndpoint;
      case 'addition':
        return _additionsEndpoint;
      default:
        return '';
    }
  }

  /// Récupère le statut de synchronisation
  HiveSyncStatus? getSyncStatus(String ownerPhone) {
    try {
      return _syncStatus.firstWhere((s) => s.ownerPhone == ownerPhone);
    } catch (e) {
      return null;
    }
  }

  /// Vérifie si l'application est en ligne
  bool get isOnline => _isOnline;

  /// Vérifie si une synchronisation est en cours
  bool get isSyncing => _isSyncing;

  /// Nettoie les données locales
  Future<void> clearLocalData(String ownerPhone) async {
    try {
      _clients.removeWhere((c) => c.ownerPhone == ownerPhone);
      _debts.removeWhere((d) => d.ownerPhone == ownerPhone);
      _payments.removeWhere((p) => p.ownerPhone == ownerPhone);
      _additions.removeWhere((a) => a.ownerPhone == ownerPhone);
      _syncStatus.removeWhere((s) => s.ownerPhone == ownerPhone);

      // Effacer la queue de sync
      await _syncQueue.clearQueue(ownerPhone);

      print('Local data cleared for $ownerPhone');
    } catch (e) {
      print('Error clearing local data: $e');
      rethrow;
    }
  }

  /// Ferme le service
  Future<void> close() async {
    _autoSyncTimer?.cancel();
    _connectivitySubscription.cancel();
    await _syncQueue.close();
    _clients.clear();
    _debts.clear();
    _payments.clear();
    _additions.clear();
    _syncStatus.clear();
  }
}