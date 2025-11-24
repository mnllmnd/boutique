// Modèles Hive - Données locales pour synchronisation

// Helper function to parse numbers safely (handles both String and num)
double _parseAmount(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    try {
      return double.parse(value);
    } catch (e) {
      print('Error parsing amount "$value": $e');
      return 0.0;
    }
  }
  return 0.0;
}

int _parseId(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is String) {
    try {
      return int.parse(value);
    } catch (e) {
      print('Error parsing id "$value": $e');
      return 0;
    }
  }
  return 0;
}

class HiveClient {
  final int id;
  final String name;
  final String phone;
  final String ownerPhone;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool needsSync;
  final DateTime? lastSyncAt;
  final String? syncError;

  HiveClient({
    required this.id,
    required this.name,
    required this.phone,
    required this.ownerPhone,
    required this.createdAt,
    required this.updatedAt,
    this.needsSync = false,
    this.lastSyncAt,
    this.syncError,
  });

  factory HiveClient.fromJson(Map<String, dynamic> json) => HiveClient(
        id: json['id'] as int,
        name: json['name'] as String,
        phone: json['phone'] as String,
        ownerPhone: json['owner_phone'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        needsSync: json['needsSync'] as bool? ?? false,
        lastSyncAt: json['lastSyncAt'] != null
            ? DateTime.parse(json['lastSyncAt'] as String)
            : null,
        syncError: json['syncError'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'owner_phone': ownerPhone,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'needsSync': needsSync,
        'lastSyncAt': lastSyncAt?.toIso8601String(),
        'syncError': syncError,
      };

  Map<String, dynamic> toServerJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'owner_phone': ownerPhone,
      };

  HiveClient copyWith({
    int? id,
    String? name,
    String? phone,
    String? ownerPhone,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? needsSync,
    DateTime? lastSyncAt,
    String? syncError,
  }) =>
      HiveClient(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        ownerPhone: ownerPhone ?? this.ownerPhone,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        needsSync: needsSync ?? this.needsSync,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        syncError: syncError ?? this.syncError,
      );
}

class HiveDebt {
  final int id;
  final String creditor;
  final double amount;
  final String type; // 'debt' ou 'loan'
  final int clientId;
  final String fromUser;
  final String toUser;
  final double balance;
  final bool paid;
  final DateTime? paidAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String ownerPhone;
  final bool needsSync;
  final DateTime? lastSyncAt;
  final String? syncError;
  final int localVersion;
  final int serverVersion;

  HiveDebt({
    required this.id,
    required this.creditor,
    required this.amount,
    required this.type,
    required this.clientId,
    required this.fromUser,
    required this.toUser,
    required this.balance,
    required this.paid,
    required this.createdAt,
    required this.updatedAt,
    required this.ownerPhone,
    this.paidAt,
    this.needsSync = false,
    this.lastSyncAt,
    this.syncError,
    this.localVersion = 0,
    this.serverVersion = 0,
  });

  factory HiveDebt.fromJson(Map<String, dynamic> json) => HiveDebt(
        id: _parseId(json['id']),
        creditor: json['creditor'] as String,
        amount: _parseAmount(json['amount']),
        type: json['type'] as String,
        clientId: _parseId(json['client_id']),
        fromUser: json['from_user'] as String,
        toUser: json['to_user'] as String,
        balance: _parseAmount(json['balance']),
        paid: json['paid'] as bool? ?? false,
        paidAt: json['paid_at'] != null
            ? DateTime.parse(json['paid_at'] as String)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        ownerPhone: json['owner_phone'] as String,
        needsSync: json['needsSync'] as bool? ?? false,
        lastSyncAt: json['lastSyncAt'] != null
            ? DateTime.parse(json['lastSyncAt'] as String)
            : null,
        syncError: json['syncError'] as String?,
        localVersion: json['localVersion'] as int? ?? 0,
        serverVersion: json['serverVersion'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'creditor': creditor,
        'amount': amount,
        'type': type,
        'client_id': clientId,
        'from_user': fromUser,
        'to_user': toUser,
        'balance': balance,
        'paid': paid,
        'paid_at': paidAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'owner_phone': ownerPhone,
        'needsSync': needsSync,
        'lastSyncAt': lastSyncAt?.toIso8601String(),
        'syncError': syncError,
        'localVersion': localVersion,
        'serverVersion': serverVersion,
      };

  Map<String, dynamic> toServerJson() => {
        'id': id,
        'creditor': creditor,
        'amount': amount,
        'type': type,
        'client_id': clientId,
        'from_user': fromUser,
        'to_user': toUser,
        'balance': balance,
        'paid': paid,
        'paid_at': paidAt?.toIso8601String(),
      };

  double calculateBalance(double totalAdditions, double totalPayments) {
    return amount + totalAdditions - totalPayments;
  }

  HiveDebt copyWith({
    int? id,
    String? creditor,
    double? amount,
    String? type,
    int? clientId,
    String? fromUser,
    String? toUser,
    double? balance,
    bool? paid,
    DateTime? paidAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? ownerPhone,
    bool? needsSync,
    DateTime? lastSyncAt,
    String? syncError,
    int? localVersion,
    int? serverVersion,
  }) =>
      HiveDebt(
        id: id ?? this.id,
        creditor: creditor ?? this.creditor,
        amount: amount ?? this.amount,
        type: type ?? this.type,
        clientId: clientId ?? this.clientId,
        fromUser: fromUser ?? this.fromUser,
        toUser: toUser ?? this.toUser,
        balance: balance ?? this.balance,
        paid: paid ?? this.paid,
        paidAt: paidAt ?? this.paidAt,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        ownerPhone: ownerPhone ?? this.ownerPhone,
        needsSync: needsSync ?? this.needsSync,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        syncError: syncError ?? this.syncError,
        localVersion: localVersion ?? this.localVersion,
        serverVersion: serverVersion ?? this.serverVersion,
      );
}

class HivePayment {
  final int id;
  final int debtId;
  final double amount;
  final DateTime paidAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String ownerPhone;
  final bool needsSync;
  final DateTime? lastSyncAt;
  final String? syncError;
  final int localVersion;
  final int serverVersion;
  final String? operationType;  // ✅ NOUVEAU: 'payment', 'loan_payment'
  final String? debtType;        // ✅ NOUVEAU: 'debt' ou 'loan'

  HivePayment({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.paidAt,
    required this.createdAt,
    required this.updatedAt,
    required this.ownerPhone,
    this.needsSync = false,
    this.lastSyncAt,
    this.syncError,
    this.localVersion = 0,
    this.serverVersion = 0,
    this.operationType,
    this.debtType,
  });

  factory HivePayment.fromJson(Map<String, dynamic> json) {
    final paidAt = DateTime.parse(json['paid_at'] as String);
    return HivePayment(
      id: _parseId(json['id']),
      debtId: _parseId(json['debt_id']),
      amount: _parseAmount(json['amount']),
      paidAt: paidAt,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : paidAt,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : paidAt,
      ownerPhone: json['owner_phone'] as String? ?? '',
      needsSync: json['needsSync'] as bool? ?? false,
      lastSyncAt: json['lastSyncAt'] != null
          ? DateTime.parse(json['lastSyncAt'] as String)
          : null,
      syncError: json['syncError'] as String?,
      localVersion: json['localVersion'] as int? ?? 0,
      serverVersion: json['serverVersion'] as int? ?? 0,
      operationType: json['operation_type'] as String?,
      debtType: json['debt_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'debt_id': debtId,
        'amount': amount,
        'paid_at': paidAt.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'owner_phone': ownerPhone,
        'needsSync': needsSync,
        'lastSyncAt': lastSyncAt?.toIso8601String(),
        'syncError': syncError,
        'localVersion': localVersion,
        'serverVersion': serverVersion,
        'operation_type': operationType,
        'debt_type': debtType,
      };

  Map<String, dynamic> toServerJson() => {
        'id': id,
        'debt_id': debtId,
        'amount': amount,
        'paid_at': paidAt.toIso8601String(),
        'operation_type': operationType,
        'debt_type': debtType,
      };

  HivePayment copyWith({
    int? id,
    int? debtId,
    double? amount,
    DateTime? paidAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? ownerPhone,
    bool? needsSync,
    DateTime? lastSyncAt,
    String? syncError,
    int? localVersion,
    int? serverVersion,
    String? operationType,
    String? debtType,
  }) =>
      HivePayment(
        id: id ?? this.id,
        debtId: debtId ?? this.debtId,
        amount: amount ?? this.amount,
        paidAt: paidAt ?? this.paidAt,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        ownerPhone: ownerPhone ?? this.ownerPhone,
        needsSync: needsSync ?? this.needsSync,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        syncError: syncError ?? this.syncError,
        localVersion: localVersion ?? this.localVersion,
        serverVersion: serverVersion ?? this.serverVersion,
        operationType: operationType ?? this.operationType,
        debtType: debtType ?? this.debtType,
      );
}

class HiveDebtAddition {
  final int id;
  final int debtId;
  final double amount;
  final DateTime addedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String ownerPhone;
  final bool needsSync;
  final DateTime? lastSyncAt;
  final String? syncError;
  final int localVersion;
  final int serverVersion;
  final String? operationType;  // ✅ NOUVEAU: 'addition', 'loan_addition'
  final String? debtType;        // ✅ NOUVEAU: 'debt' ou 'loan'

  HiveDebtAddition({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.addedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.ownerPhone,
    this.needsSync = false,
    this.lastSyncAt,
    this.syncError,
    this.localVersion = 0,
    this.serverVersion = 0,
    this.operationType,
    this.debtType,
  });

  factory HiveDebtAddition.fromJson(Map<String, dynamic> json) {
    final addedAt = DateTime.parse(json['added_at'] as String);
    return HiveDebtAddition(
      id: _parseId(json['id']),
      debtId: _parseId(json['debt_id']),
      amount: _parseAmount(json['amount']),
      addedAt: addedAt,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : addedAt,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : addedAt,
      ownerPhone: json['owner_phone'] as String? ?? '',
      needsSync: json['needsSync'] as bool? ?? false,
      lastSyncAt: json['lastSyncAt'] != null
          ? DateTime.parse(json['lastSyncAt'] as String)
          : null,
      syncError: json['syncError'] as String?,
      localVersion: json['localVersion'] as int? ?? 0,
      serverVersion: json['serverVersion'] as int? ?? 0,
      operationType: json['operation_type'] as String?,
      debtType: json['debt_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'debt_id': debtId,
        'amount': amount,
        'added_at': addedAt.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'owner_phone': ownerPhone,
        'needsSync': needsSync,
        'lastSyncAt': lastSyncAt?.toIso8601String(),
        'syncError': syncError,
        'localVersion': localVersion,
        'serverVersion': serverVersion,
        'operation_type': operationType,
        'debt_type': debtType,
      };

  Map<String, dynamic> toServerJson() => {
        'id': id,
        'debt_id': debtId,
        'amount': amount,
        'added_at': addedAt.toIso8601String(),
        'operation_type': operationType,
        'debt_type': debtType,
      };

  HiveDebtAddition copyWith({
    int? id,
    int? debtId,
    double? amount,
    DateTime? addedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? ownerPhone,
    bool? needsSync,
    DateTime? lastSyncAt,
    String? syncError,
    int? localVersion,
    int? serverVersion,
    String? operationType,
    String? debtType,
  }) =>
      HiveDebtAddition(
        id: id ?? this.id,
        debtId: debtId ?? this.debtId,
        amount: amount ?? this.amount,
        addedAt: addedAt ?? this.addedAt,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        ownerPhone: ownerPhone ?? this.ownerPhone,
        needsSync: needsSync ?? this.needsSync,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        syncError: syncError ?? this.syncError,
        localVersion: localVersion ?? this.localVersion,
        serverVersion: serverVersion ?? this.serverVersion,
        operationType: operationType ?? this.operationType,
        debtType: debtType ?? this.debtType,
      );
}

class HiveSyncStatus {
  final String ownerPhone;
  final DateTime lastSyncAt;
  final DateTime nextSyncAt;
  final bool isSyncing;
  final String? lastError;
  final int failureCount;
  final int pendingOperationsCount;
  final bool isOnline;

  HiveSyncStatus({
    required this.ownerPhone,
    required this.lastSyncAt,
    required this.nextSyncAt,
    this.isSyncing = false,
    this.lastError,
    this.failureCount = 0,
    this.pendingOperationsCount = 0,
    this.isOnline = true,
  });

  factory HiveSyncStatus.fromJson(Map<String, dynamic> json) =>
      HiveSyncStatus(
        ownerPhone: json['owner_phone'] as String,
        lastSyncAt: DateTime.parse(json['last_sync_at'] as String),
        nextSyncAt: DateTime.parse(json['next_sync_at'] as String),
        isSyncing: json['is_syncing'] as bool? ?? false,
        lastError: json['last_error'] as String?,
        failureCount: json['failure_count'] as int? ?? 0,
        pendingOperationsCount:
            json['pending_operations_count'] as int? ?? 0,
        isOnline: json['is_online'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'owner_phone': ownerPhone,
        'last_sync_at': lastSyncAt.toIso8601String(),
        'next_sync_at': nextSyncAt.toIso8601String(),
        'is_syncing': isSyncing,
        'last_error': lastError,
        'failure_count': failureCount,
        'pending_operations_count': pendingOperationsCount,
        'is_online': isOnline,
      };

  HiveSyncStatus copyWith({
    String? ownerPhone,
    DateTime? lastSyncAt,
    DateTime? nextSyncAt,
    bool? isSyncing,
    String? lastError,
    int? failureCount,
    int? pendingOperationsCount,
    bool? isOnline,
  }) =>
      HiveSyncStatus(
        ownerPhone: ownerPhone ?? this.ownerPhone,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        nextSyncAt: nextSyncAt ?? this.nextSyncAt,
        isSyncing: isSyncing ?? this.isSyncing,
        lastError: lastError ?? this.lastError,
        failureCount: failureCount ?? this.failureCount,
        pendingOperationsCount:
            pendingOperationsCount ?? this.pendingOperationsCount,
        isOnline: isOnline ?? this.isOnline,
      );
}

enum OperationType { create, update, delete }

class HivePendingOperation {
  final String id; // UUID unique pour l'opération
  final String operationType; // 'create', 'update', 'delete'
  final String entityType; // 'client', 'debt', 'payment', 'addition'
  final int entityId;
  final String ownerPhone;
  final Map<dynamic, dynamic> payload; // Les données à synchroniser
  final DateTime createdAt;
  final DateTime? executedAt;
  final int retryCount;
  final String? lastError;
  final int priority; // 0 = normal, 1 = high, -1 = low
  final bool isProcessing;
  final bool? success; // null = pending, true = success, false = failed
  final DateTime? lastRetryAt;

  HivePendingOperation({
    required this.id,
    required this.operationType,
    required this.entityType,
    required this.entityId,
    required this.ownerPhone,
    required this.payload,
    required this.createdAt,
    this.executedAt,
    this.retryCount = 0,
    this.lastError,
    this.priority = 0,
    this.isProcessing = false,
    this.success,
    this.lastRetryAt,
  });

  factory HivePendingOperation.fromJson(Map<String, dynamic> json) =>
      HivePendingOperation(
        id: json['id'] as String,
        operationType: json['operation_type'] as String,
        entityType: json['entity_type'] as String,
        entityId: json['entity_id'] as int,
        ownerPhone: json['owner_phone'] as String,
        payload: (json['payload'] as Map).cast<dynamic, dynamic>(),
        createdAt: DateTime.parse(json['created_at'] as String),
        executedAt: json['executed_at'] != null
            ? DateTime.parse(json['executed_at'] as String)
            : null,
        retryCount: json['retry_count'] as int? ?? 0,
        lastError: json['last_error'] as String?,
        priority: json['priority'] as int? ?? 0,
        isProcessing: json['is_processing'] as bool? ?? false,
        success: json['success'] as bool?,
        lastRetryAt: json['last_retry_at'] != null
            ? DateTime.parse(json['last_retry_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'operation_type': operationType,
        'entity_type': entityType,
        'entity_id': entityId,
        'owner_phone': ownerPhone,
        'payload': payload,
        'created_at': createdAt.toIso8601String(),
        'executed_at': executedAt?.toIso8601String(),
        'retry_count': retryCount,
        'last_error': lastError,
        'priority': priority,
        'is_processing': isProcessing,
        'success': success,
        'last_retry_at': lastRetryAt?.toIso8601String(),
      };

  HivePendingOperation copyWith({
    String? id,
    String? operationType,
    String? entityType,
    int? entityId,
    String? ownerPhone,
    Map<dynamic, dynamic>? payload,
    DateTime? createdAt,
    DateTime? executedAt,
    int? retryCount,
    String? lastError,
    int? priority,
    bool? isProcessing,
    bool? success,
    DateTime? lastRetryAt,
  }) =>
      HivePendingOperation(
        id: id ?? this.id,
        operationType: operationType ?? this.operationType,
        entityType: entityType ?? this.entityType,
        entityId: entityId ?? this.entityId,
        ownerPhone: ownerPhone ?? this.ownerPhone,
        payload: payload ?? this.payload,
        createdAt: createdAt ?? this.createdAt,
        executedAt: executedAt ?? this.executedAt,
        retryCount: retryCount ?? this.retryCount,
        lastError: lastError ?? this.lastError,
        priority: priority ?? this.priority,
        isProcessing: isProcessing ?? this.isProcessing,
        success: success ?? this.success,
        lastRetryAt: lastRetryAt ?? this.lastRetryAt,
      );
}
