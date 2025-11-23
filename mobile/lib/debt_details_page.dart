import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';

import 'add_payment_page.dart';
import 'add_addition_page.dart';
import 'data/audio_service.dart';
import 'app_settings.dart';
import 'dart:async';

class DebtDetailsPage extends StatefulWidget {
  final String ownerPhone;
  final Map debt;

  const DebtDetailsPage({super.key, required this.ownerPhone, required this.debt});

  @override
  _DebtDetailsPageState createState() => _DebtDetailsPageState();
}

class _DebtDetailsPageState extends State<DebtDetailsPage> with TickerProviderStateMixin {
  List payments = [];
  List additions = [];
  bool _loading = false;
  bool _changed = false;
  late AudioService _audioService;
  late Map _debt; // Copie locale de la dette
  Map<String, dynamic>? _client; // ✅ Infos du client
  
  // États pour masquer/afficher les sections
  bool _showAllHistory = false;
  
  // Pour le refresh automatique
  final int _autoRefreshInterval = 2000; // 2 secondes
  Timer? _refreshTimer;
  
  // ✅ NOUVEAU : TabBar Controller
  late TabController _tabController;

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
    _audioService = AudioService();
    _debt = Map.from(widget.debt); // Copie locale
    _changed = false;
    // ✅ NOUVEAU : Initialiser TabController
    _tabController = TabController(length: 2, vsync: this);
    _loadAllData();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose(); // ✅ NOUVEAU : Disposer du TabController
    _audioService.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(Duration(milliseconds: _autoRefreshInterval), (timer) {
      if (mounted) {
        _loadAllData(silent: true);
      }
    });
  }

  // 🆕 Fonction helper pour déterminer le terme "Client" ou "Contact"
  String _getTermClient() {
    return AppSettings().boutiqueModeEnabled ? 'client' : 'contact';
  }

  String _getTermClientUp() {
    return AppSettings().boutiqueModeEnabled ? 'CLIENT' : 'CONTACT';
  }

  // ✅ Conversion sécurisée des nombres
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(' ', '')) ?? 0.0;
    }
    return 0.0;
  }

  // ✅ NOUVELLE FONCTION : Charger les infos du client
  Future<void> _loadClientInfo() async {
    if (_debt['client_id'] == null) return;
    
    try {
      final headers = {
        'Content-Type': 'application/json', 
        if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone
      };
      
      final response = await http.get(
        Uri.parse('$apiHost/clients/${_debt['client_id']}'), 
        headers: headers
      ).timeout(const Duration(seconds: 8));
      
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _client = json.decode(response.body) as Map<String, dynamic>;
        });
      }
    } catch (e) {
      print('Erreur chargement client: $e');
    }
  }

  // ✅ FONCTION DE TRI DÉCROISSANT
  List _sortByDateDescending(List items, String dateField) {
    items.sort((a, b) {
      final dateA = DateTime.parse(a[dateField] ?? '');
      final dateB = DateTime.parse(b[dateField] ?? '');
      return dateB.compareTo(dateA); // Ordre décroissant
    });
    return items;
  }

  // ✅ NOUVELLE FONCTION : Calculer le solde correctement
  double _calculateRemaining(Map debt, List paymentList) {
    try {
      final debtAmount = _parseDouble(debt['amount']);
      double totalPaid = 0.0;
      
      // Calculer le total des paiements
      for (final payment in paymentList) {
        totalPaid += _parseDouble(payment['amount']);
      }
      
      return debtAmount - totalPaid;
    } catch (_) {
      return 0.0;
    }
  }

  Future<void> _loadAllData({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    
    try {
      final headers = {
        'Content-Type': 'application/json', 
        if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone
      };
      
      // Recharger aussi les infos principales de la dette
      final debtFuture = http.get(
        Uri.parse('$apiHost/debts/${_debt['id']}'), 
        headers: headers
      ).timeout(const Duration(seconds: 8));
      
      // Chargement en parallèle pour plus de rapidité
      final paymentsFuture = http.get(
        Uri.parse('$apiHost/debts/${_debt['id']}/payments'), 
        headers: headers
      ).timeout(const Duration(seconds: 8));
      
      final additionsFuture = http.get(
        Uri.parse('$apiHost/debts/${_debt['id']}/additions'), 
        headers: headers
      ).timeout(const Duration(seconds: 8));
      
      final responses = await Future.wait([debtFuture, paymentsFuture, additionsFuture]);
      
      if (mounted) {
        setState(() {
          if (responses[0].statusCode == 200) {
            // Mettre à jour les infos de la dette
            final updatedDebt = json.decode(responses[0].body) as Map;
            _debt.addAll(updatedDebt); // Utiliser la copie locale
            
            // ✅ CHARGER LES INFOS DU CLIENT SI NÉCESSAIRE
            if (_client == null && _debt['client_id'] != null) {
              _loadClientInfo();
            }
          }
          if (responses[1].statusCode == 200) {
            // ✅ TRIER LES PAIEMENTS DU PLUS RÉCENT AU PLUS ANCIEN
            payments = _sortByDateDescending(json.decode(responses[1].body) as List, 'paid_at');
            
            // ✅ METTRE À JOUR LE SOLDE APRÈS AVOIR REÇU LES PAIEMENTS
            _debt['remaining'] = _calculateRemaining(_debt, payments);
          }
          if (responses[2].statusCode == 200) {
            // ✅ TRIER LES ADDITIONS DU PLUS RÉCENT AU PLUS ANCIEN
            additions = _sortByDateDescending(json.decode(responses[2].body) as List, 'added_at');
          }
        });
      }
    } catch (e) {
      // Ignorer les erreurs silencieuses
    } finally {
      if (mounted && !silent) {
        setState(() => _loading = false);
      }
    }
  }

  // ✅ MODIFIÉ : Rechargement après paiement
  Future<void> _addPayment() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddPaymentPage(
          ownerPhone: widget.ownerPhone, 
          debt: _debt,
        )
      )
    );
    
    // ✅ FORCER LE RECHARGEMENT APRÈS PAIEMENT
    if (result == true) {
      _changed = true;
      // Rechargement immédiat et complet
      await _loadAllData();
      // Recharger aussi les infos client au cas où
      if (_debt['client_id'] != null) {
        await _loadClientInfo();
      }
    }
  }

  // ✅ MODIFIÉ : Rechargement après addition
  Future<void> _addAddition() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddAdditionPage(
          ownerPhone: widget.ownerPhone, 
          debt: _debt
        )
      ),
    );
    
    // ✅ FORCER LE RECHARGEMENT APRÈS ADDITION
    if (result == true) {
      _changed = true;
      await _loadAllData();
    }
  }

  // ✅ LOGIQUE UNIVERSELLE : from_user doit payer to_user
  // balance = montant que from_user doit à to_user
  // Si balance > 0 : from_user doit payer
  // Si balance < 0 : to_user doit payer (inverse)

  bool _isLoan() {
    // On affiche juste si c'est un emprunt initial
    // Mais ça n'affecte PLUS la logique des boutons !
    return _debt['type'] == 'loan';
  }

  String _getAddButtonLabel() {
    // ✅ SPÉCIALISÉ : Dépend du type de relation
    final debtType = _debt['type'] ?? 'debt';
    if (debtType == 'debt') {
      return 'Prêter Plus'; // Je prête → prêter plus
    } else {
      return 'Emprunter Plus'; // Je dois → emprunter plus
    }
  }

  String _getPaymentButtonLabel() {
    // ✅ SPÉCIALISÉ : Dépend du type de relation
    final debtType = _debt['type'] ?? 'debt';
    if (debtType == 'debt') {
      return 'Encaisser'; // Je prête → encaisser le paiement
    } else {
      return 'Rembourser'; // Je dois → rembourser ma dette
    }
  }

  // ✅ NOUVEAU: Retourne le statut initial du type
  String _getInitialType() {
    return _debt['type'] ?? 'debt';
  }

  // ✅ NOUVEAU: Message contextuel si le balance a changé de signe
  String? _getStatusChangeMessage() {
    final balance = _parseDouble(_debt['balance'] ?? 0.0);
    final initialType = _getInitialType();
    
    // Prêt (X prête à Y) mais balance < 0 (Y prête à X maintenant)
    if (initialType == 'debt' && balance < 0) {
      final fromUser = _debt['from_user'];
      final toUser = _debt['to_user'];
      final amount = balance.abs();
      return '⚠️ RELATION INVERSÉE : $toUser prête maintenant $amount F à $fromUser';
    }
    
    // Emprunt (X emprunte de Y) mais balance > 0 (Y prête à X maintenant)
    if (initialType == 'loan' && balance > 0) {
      final fromUser = _debt['from_user'];
      final toUser = _debt['to_user'];
      final amount = balance;
      return '⚠️ RELATION INVERSÉE : $toUser prête maintenant $amount F à $fromUser';
    }
    
    return null;
  }
  Widget _buildClientAvatar() {
    final hasAvatar = _client?['avatar_url'] != null && 
                     _client!['avatar_url'].toString().isNotEmpty;
    final clientName = _client?['name'] ?? _debt['client_name'] ?? (AppSettings().boutiqueModeEnabled ? 'Client' : 'Contact');
    final initials = _getInitials(clientName);
    
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: hasAvatar
          ? ClipOval(
              child: Image.network(
                _client!['avatar_url'],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildInitialsAvatar(initials);
                },
              ),
            )
          : _buildInitialsAvatar(initials),
    );
  }

  Widget _buildInitialsAvatar(String initials) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (name.isNotEmpty) {
      return name.substring(0, 1).toUpperCase();
    }
    return 'C';
  }

  Future<void> _deleteDebt() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Theme.of(context).cardColor,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SUPPRIMER LA DETTE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Êtes-vous sûr de vouloir supprimer cette dette ?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(
                      'ANNULER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                    ),
                    child: const Text(
                      'SUPPRIMER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: Colors.white,
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
    
    if (confirm != true) return;
    try {
      final headers = {'Content-Type': 'application/json', if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone};
      final res = await http.delete(Uri.parse('$apiHost/debts/${_debt['id']}'), headers: headers).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        _changed = true;
        Navigator.of(context).pop(true);
      } else {
        await _showMinimalDialog('Erreur', 'Échec suppression: ${res.statusCode}\n${res.body}');
      }
    } catch (e) {
      await _showMinimalDialog('Erreur réseau', '$e');
    }
  }

  Future<void> _showMinimalDialog(String title, String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    
    return showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Theme.of(context).cardColor,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : Colors.black,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                  ),
                  child: Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                      color: isDark ? Colors.black : Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ NOUVELLE FONCTION : Modifier la note
  Future<void> _editNotes() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final notesCtl = TextEditingController(text: _debt['notes'] ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Theme.of(context).cardColor,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MODIFIER LA NOTE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesCtl,
                maxLines: 5,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Entrez la note...',
                  hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
                  ),
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
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(
                      'ANNULER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                    ),
                    child: Text(
                      'ENREGISTRER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: isDark ? Colors.black : Colors.white,
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

    if (confirmed == true) {
      try {
        final headers = {
          'Content-Type': 'application/json',
          if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone
        };

        final res = await http.put(
          Uri.parse('$apiHost/debts/${_debt['id']}'),
          headers: headers,
          body: json.encode({
            'notes': notesCtl.text.trim(),
          }),
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          setState(() {
            _debt['notes'] = notesCtl.text.trim();
            _changed = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Note mise à jour')),
          );
        } else {
          await _showMinimalDialog('Erreur', 'Impossible de mettre à jour la note');
        }
      } catch (e) {
        await _showMinimalDialog('Erreur réseau', '$e');
      }
    }
  }

  // ✅ NOUVELLE FONCTION : Modifier la date d'échéance
  Future<void> _editDueDate() async {
    DateTime? selectedDate = _parseDate(_debt['due_date']);

    final newDate = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              surface: Theme.of(context).cardColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (newDate != null) {
      try {
        final headers = {
          'Content-Type': 'application/json',
          if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone
        };

        final res = await http.put(
          Uri.parse('$apiHost/debts/${_debt['id']}'),
          headers: headers,
          body: json.encode({
            'due_date': DateFormat('yyyy-MM-dd').format(newDate),
          }),
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          setState(() {
            _debt['due_date'] = newDate.toIso8601String();
            _changed = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Date mise à jour')),
          );
        } else {
          await _showMinimalDialog('Erreur', 'Impossible de mettre à jour la date');
        }
      } catch (e) {
        await _showMinimalDialog('Erreur réseau', '$e');
      }
    }
  }

  // ✅ NOUVELLE FONCTION : Fusionner et trier paiements + additions
  List<Map<String, dynamic>> _getMergedHistory() {
    final merged = <Map<String, dynamic>>[];
    
    // Ajouter la création initiale de la dette/emprunt dans l'historique
    try {
      final creationDate = _parseDate(_debt['created_at'] ?? _debt['added_at'] ?? _debt['date'] ?? _debt['createdAt']);
      merged.add({
        'type': 'creation',
        'data': _debt,
        'date': creationDate ?? DateTime.now(),
        'amount': _debt['amount'],
      });
    } catch (_) {}

    // Ajouter les paiements
    for (final p in payments) {
      merged.add({
        'type': 'payment',
        'data': p,
        'date': DateTime.parse(p['paid_at'] ?? DateTime.now().toIso8601String()),
        'amount': p['amount'],
      });
    }
    
    // Ajouter les additions
    for (final a in additions) {
      merged.add({
        'type': 'addition',
        'data': a,
        'date': DateTime.parse(a['added_at'] ?? DateTime.now().toIso8601String()),
        'amount': a['amount'],
      });
    }
    
    // Trier par date décroissante (plus récent en premier)
    merged.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    return merged;
  }

  // ✅ NOUVELLE FONCTION : Générer la liste d'historique unifié
  List<Widget> _buildUnifiedHistory(Color textColor, Color textColorSecondary) {
    final mergedHistory = _getMergedHistory();
    
    // Si pas d'historique
    if (mergedHistory.isEmpty) {
      return [
        _buildEmptyState(
          icon: Icons.history,
          title: 'AUCUN HISTORIQUE',
          subtitle: 'Aucun paiement ou addition enregistré',
        ),
      ];
    }
    
    // Limiter à 5 items si pas "VOIR PLUS"
    final displayedItems = _showAllHistory 
        ? mergedHistory 
        : mergedHistory.take(5).toList();
    
    return displayedItems.map((item) => _buildHistoryItem(item, textColor, textColorSecondary)).toList();
  }

  // ✅ NOUVELLE FONCTION : Widget pour un item d'historique
  Widget _buildHistoryItem(Map<String, dynamic> item, Color textColor, Color textColorSecondary) {
    final type = item['type'] as String? ?? '';
    final data = item['data'] as Map? ?? <String, dynamic>{};
    final amount = _parseDouble(item['amount']);

    final isPayment = type == 'payment';
    final isAddition = type == 'addition';
    final isCreation = type == 'creation';

    IconData leadingIcon;
    Color leadingColor;
    String titleText;

    if (isCreation) {
      leadingIcon = Icons.event_note;
      leadingColor = Colors.blue;
      titleText = _isLoan() ? 'Emprunt initial' : 'Prêt initial';
    } else if (isPayment) {
      leadingIcon = Icons.arrow_downward;
      leadingColor = Theme.of(context).colorScheme.primary;
      titleText = _isLoan() ? 'Remboursement effectué' : 'Paiement reçu';
    } else {
      // addition
      leadingIcon = Icons.arrow_upward;
      leadingColor = Colors.orange;
      titleText = _isLoan() ? 'Montant emprunté' : 'Montant prêté';
    }

    final subtitleDate = isPayment
        ? _formatPaymentDate(data['paid_at'])
        : _fmtDate(data['created_at'] ?? data['added_at'] ?? data['date'] ?? data['createdAt']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: leadingColor.withOpacity(0.1),
          ),
          child: Icon(
            leadingIcon,
            color: leadingColor,
            size: 20,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  titleText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textColorSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _fmtAmount(amount),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: (isPayment) ? Theme.of(context).colorScheme.primary : Colors.orange,
              ),
            ),
            if (data['notes'] != null && data['notes'].toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                data['notes'].toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: textColorSecondary,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            subtitleDate,
            style: TextStyle(
              fontSize: 12,
              color: textColorSecondary,
            ),
          ),
        ),
      ),
    );
  }

  // Fonction pour formater la date d'échéance de manière intelligente
  Widget _buildDueDateWidget(DateTime dueDate) {
    final now = DateTime.now();
    final difference = dueDate.difference(now);
    final days = difference.inDays;
    
    Color color;
    String text;
    IconData icon;
    
    if (days < 0) {
      // En retard
      color = Colors.red;
      text = 'EN RETARD (${days.abs()}j)';
      icon = Icons.warning;
    } else if (days == 0) {
      // Aujourd'hui
      color = Colors.orange;
      text = 'AUJOURD\'HUI';
      icon = Icons.today;
    } else if (days <= 7) {
      // Cette semaine
      color = Colors.orange;
      text = 'DANS $days JOUR${days > 1 ? 'S' : ''}';
      icon = Icons.schedule;
    } else {
      // Plus d'une semaine
      color = Theme.of(context).colorScheme.primary;
      text = DateFormat('dd/MM/yyyy').format(dueDate);
      icon = Icons.calendar_today;
    }
    
    // ✅ RENDU CLIQUABLE avec indicateur visuel
    return GestureDetector(
      onTap: _editDueDate,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.edit, size: 12, color: color.withOpacity(0.6)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final textColorSecondary = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? Colors.white24 : Colors.black26;

    // ✅ CALCULS CORRECTS DU SOLDE
    final remaining = _debt['remaining'] ?? _calculateRemaining(_debt, payments);
    final amount = _parseDouble(_debt['amount']);
    final totalPaid = amount - remaining; // Calcul inverse
    final progress = amount == 0 ? 0.0 : (totalPaid / amount).clamp(0.0, 1.0);
    
    // Parse due date for intelligent display
    final dueDate = _parseDate(_debt['due_date']);

    // NOM DU CLIENT
    final clientName = _client?['name'] ?? _debt['client_name'] ?? (AppSettings().boutiqueModeEnabled ? 'Client' : 'Contact');
    
    // ✅ NOUVEAU : Déterminer le type
    final debtType = _debt['type'] ?? 'debt';
    final isPret = debtType == 'debt';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor, size: 24),
          onPressed: () => Navigator.of(context).pop(_changed),
        ),
        title: Text(
          isPret ? 'MES PRÊTS' : 'MES EMPRUNTS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            color: textColor,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: isPret ? 'PRÊT' : 'EMPRUNT'),
            Tab(text: 'DÉTAILS'),
          ],
          labelColor: isPret ? Colors.orange : Colors.purple,
          unselectedLabelColor: textColorSecondary,
          indicatorColor: isPret ? Colors.orange : Colors.purple,
          indicatorWeight: 2,
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // ✅ TAB 1 : PRÊT / EMPRUNT (Actions rapides + Solde)
            _buildMainTab(context, remaining, amount, totalPaid, progress, dueDate, clientName, isPret, textColor, textColorSecondary, borderColor),
            
            // ✅ TAB 2 : DÉTAILS (Notes + Historique)
            _buildDetailsTab(context, textColor, textColorSecondary, borderColor),
          ],
        ),
      ),
    );
  }

  Widget _buildMainTab(
    BuildContext context,
    double remaining,
    double amount,
    double totalPaid,
    double progress,
    DateTime? dueDate,
    String clientName,
    bool isPret,
    Color textColor,
    Color textColorSecondary,
    Color borderColor,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header avec avatar et infos client
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ligne avec avatar et nom du client
                Row(
                  children: [
                    // Avatar du client
                    _buildClientAvatar(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            clientName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getTermClient(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: textColorSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (dueDate != null) _buildDueDateWidget(dueDate),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Montant principal
                Center(
                  child: Text(
                    _fmtAmount(amount),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w300,
                      color: textColor,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // ✅ SECTION CORRIGÉE : Progression avec "JE DOIS"
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPret ? 'ENCAISSÉ' : 'REMBOURSÉ',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                              color: textColorSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _fmtAmount(totalPaid),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            remaining < 0 ? 'JE DOIS' : (isPret ? 'RESTE' : 'RESTE'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                              color: textColorSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            remaining < 0 
                                ? '${_fmtAmount(remaining.abs())} au client'
                                : _fmtAmount(remaining),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: remaining < 0 ? Colors.purple : (remaining <= 0 ? Colors.green : Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Theme.of(context).dividerColor.withOpacity(0.3),
                  color: remaining <= 0 ? Colors.green : Theme.of(context).colorScheme.primary,
                  minHeight: 6,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),

          // ✅ Actions rapides - SPÉCIALISÉES
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: remaining <= 0 ? null : _addPayment,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: remaining <= 0 ? Colors.grey : (isPret ? Colors.orange : Colors.purple),
                    side: BorderSide(
                      color: (remaining <= 0 ? Colors.grey : (isPret ? Colors.orange : Colors.purple)).withOpacity(0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: Icon(
                    isPret ? Icons.account_balance_wallet : Icons.payment,
                    size: 18,
                    color: remaining <= 0 ? Colors.grey : (isPret ? Colors.orange : Colors.purple),
                  ),
                  label: Text(
                    _getPaymentButtonLabel().toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: remaining <= 0 ? Colors.grey : (isPret ? Colors.orange : Colors.purple),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addAddition,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: BorderSide(
                      color: Colors.green.withOpacity(0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(
                    Icons.add_circle_outline,
                    size: 18,
                    color: Colors.green,
                  ),
                  label: Text(
                    _getAddButtonLabel().toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // ✅ NOUVEAU : Message si remboursement complet
          if (remaining <= 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Remboursement complet ✓',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailsTab(BuildContext context, Color textColor, Color textColorSecondary, Color borderColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ MESSAGE D'ALERTE si la relation s'est inversée
          if (_getStatusChangeMessage() != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.12),
                border: Border.all(color: Colors.blue.withOpacity(0.6), width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getStatusChangeMessage()!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Notes (si existantes)
          if (_debt['notes'] != null && _debt['notes'] != '') ...[
            _buildSectionHeader('NOTES'),
            const SizedBox(height: 12),
            // ✅ RENDU CLIQUABLE pour modifier
            GestureDetector(
              onTap: _editNotes,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor, width: 0.5),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _debt['notes'],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: textColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.edit, size: 16, color: textColorSecondary.withOpacity(0.6)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ✅ NOUVELLE SECTION : Ajouter une note si elle n'existe pas
          if (_debt['notes'] == null || _debt['notes'] == '') ...[
            GestureDetector(
              onTap: _editNotes,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor, width: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.note_add_outlined, size: 18, color: textColorSecondary),
                      const SizedBox(width: 12),
                      Text(
                        'Ajouter une note',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: textColorSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Audio (si existant)
          if (_debt['audio_path'] != null && _debt['audio_path'] != '') ...[
            _buildSectionHeader('ENREGISTREMENT'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: borderColor, width: 0.5),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.audio_file, color: textColorSecondary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Enregistrement audio',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: textColor,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _audioService.playAudio(_debt['audio_path']),
                    icon: Icon(Icons.play_arrow, color: Theme.of(context).colorScheme.primary),
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Historique unifié (paiements + montants ajoutés)
          _buildSectionHeader(
            'HISTORIQUE',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_getMergedHistory().length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textColorSecondary,
                  ),
                ),
                if (_getMergedHistory().length > 5) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showAllHistory = !_showAllHistory;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: borderColor),
                      ),
                      child: Text(
                        _showAllHistory ? 'VOIR MOINS' : 'VOIR PLUS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            ..._buildUnifiedHistory(textColor, textColorSecondary),

          const SizedBox(height: 20),
          
          // Bouton suppression
          Center(
            child: TextButton(
              onPressed: _deleteDebt,
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text(
                'SUPPRIMER LA DETTE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {Widget? trailing}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColorSecondary = isDark ? Colors.white70 : Colors.black54;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: textColorSecondary,
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColorSecondary = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? Colors.white24 : Colors.black26;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: textColorSecondary),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColorSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: textColorSecondary,
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _parseDate(dynamic date) {
    if (date == null) return null;
    try {
      return DateTime.parse(date.toString());
    } catch (_) {
      return null;
    }
  }

  String _fmtAmount(dynamic v) {
    try {
      final n = double.tryParse(v?.toString() ?? '0') ?? 0.0;
      return '${NumberFormat('#,###', 'fr_FR').format(n)} F';
    } catch (_) { return v?.toString() ?? '-'; }
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '-';
    final s = v.toString();
    try { final dt = DateTime.tryParse(s); if (dt != null) return DateFormat('dd/MM/yyyy').format(dt); } catch (_) {}
    try { final parts = s.split(' ').first.split('-'); if (parts.length>=3) return '${parts[2]}/${parts[1]}/${parts[0]}'; } catch (_) {}
    return s;
  }

  String _formatPaymentDate(dynamic dateStr) {
    if (dateStr == null) return '-';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return dateStr.toString();
    }
  }
}