import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:boutique_mobile/config/api_config.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'add_payment_page.dart';
import 'add_addition_page.dart';
import 'data/audio_service.dart';
import 'app_settings.dart';
import 'utils/pdf_handler.dart';
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
  List<Map<String, dynamic>> disputes = []; // ✅ NOUVEAU : Contestations
  bool _loading = false;
  bool _changed = false;
  late AudioService _audioService;
  late Map _debt; // Copie locale de la dette
  Map<String, dynamic>? _client; // ✅ Infos du client
  late AppSettings _appSettings; // ✅ NOUVEAU : Écouter les changements de devise
  
  // États pour masquer/afficher les sections
  bool _showAllHistory = false;
  
  // ✅ NOUVEAU : TabBar Controller
  late TabController _tabController;

  String get apiHost => ApiConfig.getBaseUrl();

  @override
  void initState() {
    super.initState();
    _audioService = AudioService();
    _debt = Map.from(widget.debt); // Copie locale
    _changed = false;
    // ✅ NOUVEAU : Initialiser TabController
    _tabController = TabController(length: 2, vsync: this);
    // ✅ NOUVEAU : Écouter les changements d'AppSettings (devise)
    _appSettings = AppSettings();
    _appSettings.addListener(_onAppSettingsChanged);
    _loadAllData();
    // 🔴 DÉSACTIVÉ : Auto-refresh toutes les 2 secondes était trop agressif
    // _startAutoRefresh();
  }

  @override
  void dispose() {
    _tabController.dispose(); // ✅ NOUVEAU : Disposer du TabController
    _appSettings.removeListener(_onAppSettingsChanged); // ✅ NOUVEAU : Retirer le listener
    _audioService.dispose();
    super.dispose();
  }

  // ✅ NOUVEAU : Callback quand AppSettings change (devise)
  void _onAppSettingsChanged() {
    if (mounted) {
      setState(() {}); // Reconstruire le widget avec la nouvelle devise
    }
  }
  // 🆕 Fonction helper pour déterminer le terme "Client" ou "Contact"
  String _getTermClient() {
    return AppSettings().boutiqueModeEnabled ? 'client' : 'contact';
  }

  // 🆕 Fonction helper robuste pour extraire le nom du client
  String _getClientName(dynamic client) {
    if (client == null) return AppSettings().boutiqueModeEnabled ? 'Client' : 'Contact';
    
    final name = client['name'];
    if (name != null && name is String && name.isNotEmpty && name != 'null') {
      return name;
    }
    
    // Fallback si pas de nom valide
    return AppSettings().boutiqueModeEnabled ? 'Client' : 'Contact';
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
      // ✅ CORRIGÉ : Inclure les additions dans le calcul
      final baseAmount = _parseDouble(debt['amount']);
      final totalAdditions = _parseDouble(debt['total_additions'] ?? 0.0);
      final totalDebtAmount = baseAmount + totalAdditions;
      
      double totalPaid = 0.0;
      
      // Calculer le total des paiements
      for (final payment in paymentList) {
        totalPaid += _parseDouble(payment['amount']);
      }
      
      return (totalDebtAmount - totalPaid).clamp(0.0, double.infinity);
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
      
      // ✅ NOUVEAU : Charger les contestations
      final disputesFuture = http.get(
        Uri.parse('$apiHost/debts/${_debt['id']}/disputes'), 
        headers: headers
      ).timeout(const Duration(seconds: 8));
      
      final responses = await Future.wait([debtFuture, paymentsFuture, additionsFuture, disputesFuture]);
      
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
          if (responses[3].statusCode == 200) {
            // ✅ NOUVEAU : Charger les contestations
            final disputesList = json.decode(responses[3].body) as List;
            disputes = disputesList.map((d) {
              final dispute = Map<String, dynamic>.from(d as Map);
              // ✅ Enrichir avec le nom du créancier (celui qui a créé la dette)
              final disputedByPhone = dispute['disputed_by'];
              if (disputedByPhone == _debt['creditor']) {
                // C'est le créancier qui conteste
                dispute['disputed_by_name'] = _debt['display_creditor_name'] ?? disputedByPhone;
              }
              return dispute;
            }).toList();
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

  // ✅ NOUVEAU : Créer une contestation
  Future<void> _createDispute() async {
    final reasonCtl = TextEditingController();
    final messageCtl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

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
                'Contester cette dette',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Expliquez pourquoi vous contestez cette dette. Un message clair aidera à résoudre le conflit.',
                style: TextStyle(
                  fontSize: 14,
                  color: textColor.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 20),
              
              // Raison
              TextField(
                controller: reasonCtl,
                decoration: InputDecoration(
                  labelText: 'Raison de la contestation',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  hintText: 'Ex: Montant incorrect, doublon, erreur...',
                ),
                style: TextStyle(color: textColor, fontSize: 14),
              ),
              const SizedBox(height: 16),
              
              // Message détaillé
              TextField(
                controller: messageCtl,
                decoration: InputDecoration(
                  labelText: 'Message détaillé (optionnel)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  hintText: 'Fournissez des détails supplémentaires...',
                ),
                style: TextStyle(color: textColor, fontSize: 14),
                maxLines: 4,
              ),
              const SizedBox(height: 24),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text(
                      'Contester',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || reasonCtl.text.trim().isEmpty) return;

    try {
      final headers = {
        'Content-Type': 'application/json',
        if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone
      };

      final res = await http.post(
        Uri.parse('$apiHost/debts/${_debt['id']}/disputes'),
        headers: headers,
        body: json.encode({
          'reason': reasonCtl.text.trim(),
          'message': messageCtl.text.trim(),
        }),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 201) {
        _changed = true;
        await _loadAllData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contestation créée avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await _showMinimalDialog('Erreur', 'Impossible de créer la contestation');
      }
    } catch (e) {
      await _showMinimalDialog('Erreur réseau', '$e');
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
  // ✅ NOUVEAU : Générer une couleur stable et subtile basée sur le nom du client
  Color _getAvatarColor(dynamic client) {
    final clientName = _getClientName(client);
    final hash = clientName.hashCode;
    
    // Palette de couleurs subtiles et minimalistes
    const colors = [
      Color(0xFF6B5B95),  // Violet subtil
      Color(0xFF88A86C),  // Vert sage
      Color(0xFF9B8B7E),  // Taupe
      Color(0xFF7B9DBE),  // Bleu gris
      Color(0xFFA69B84),  // Beige
      Color(0xFF8B7F9A),  // Lavande
      Color(0xFF7F9F9D),  // Teal subtil
      Color(0xFF9B8B70),  // Ocre
    ];
    
    return colors[hash.abs() % colors.length];
  }

  Widget _buildClientAvatar() {
    final hasAvatar = _client?['avatar_url'] != null && 
                     _client!['avatar_url'].toString().isNotEmpty;
    final clientName = _getClientName(_client);
    final initials = _getInitials(clientName);
    final avatarColor = _getAvatarColor(_client);
    
    return Container(
      width: 60,
      height: 60,
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
      child: Icon(
        Icons.person_rounded,
        size: 32,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withOpacity(0.55)
            : Colors.black.withOpacity(0.45),
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
                if (isCreation)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(Icons.push_pin, size: 14, color: Colors.red),
                  ),
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

  // Fonction pour télécharger/partager l'historique en PDF
  Future<void> _downloadHistoryPdf() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Génération du PDF en cours...')),
      );

      final history = _getMergedHistory();
      final displayName = _getClientName(_client);
      
      // Si crée par quelqu'un d'autre, afficher le nom du créancier
      final createdByOther = _debt['created_by_other'] == true;
      final titleName = (createdByOther && _debt['display_creditor_name'] != null)
          ? _debt['display_creditor_name']?.toString() ?? displayName  // ✅ Utiliser display_creditor_name (priorité: client.name > creditor_name)
          : displayName;
      
      final debtAmount = _parseDouble(_debt['amount']);
      final remaining = _calculateRemaining(_debt, payments);
      final debtType = _isLoan() ? 'Emprunt' : 'Prêt';
      final clientPhone = _client?['phone'] ?? widget.ownerPhone ?? '';

      // Créer le PDF
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(16),
          build: (pw.Context context) {
            return pw.Container(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // En-tête avec fond style cahier
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue800,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'HISTORIQUE',
                              style: pw.TextStyle(
                                fontSize: 28,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                            pw.Text(
                              'Détail des transactions',
                              style: pw.TextStyle(
                                fontSize: 12,
                                color: PdfColors.blue100,
                              ),
                            ),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              _fmtDate(DateTime.now()),
                              style: pw.TextStyle(
                                fontSize: 11,
                                color: PdfColors.blue100,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'BOUTIQUE',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 18),

                  // Bloc client et solde avec design cahier
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Infos client
                      pw.Expanded(
                        flex: 2,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(14),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey50,
                            border: pw.Border.all(color: PdfColors.grey300, width: 1.5),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'CLIENT',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey600,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              pw.SizedBox(height: 6),
                              pw.Text(
                                titleName.toUpperCase(),
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.blue900,
                                ),
                              ),
                              pw.SizedBox(height: 10),
                              pw.Divider(color: PdfColors.grey300, height: 1),
                              pw.SizedBox(height: 10),
                              pw.Text(
                                'TÉLÉPHONE',
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey600,
                                  letterSpacing: 1,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                clientPhone.isNotEmpty ? clientPhone : '-',
                                style: pw.TextStyle(
                                  fontSize: 11,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.blue800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      // Solde restant badge
                      pw.Expanded(
                        flex: 1,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(14),
                          decoration: pw.BoxDecoration(
                            color: remaining > 0 ? PdfColors.red50 : PdfColors.green50,
                            border: pw.Border.all(
                              color: remaining > 0 ? PdfColors.red400 : PdfColors.green400,
                              width: 2,
                            ),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Text(
                                'SOLDE',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: remaining > 0 ? PdfColors.red700 : PdfColors.green700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              pw.SizedBox(height: 6),
                              pw.Text(
                                _fmtAmount(remaining),
                                style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                  color: remaining > 0 ? PdfColors.red800 : PdfColors.green800,
                                ),
                              ),
                              pw.SizedBox(height: 8),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: pw.BoxDecoration(
                                  color: remaining > 0 ? PdfColors.red200 : PdfColors.green200,
                                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                                ),
                                child: pw.Text(
                                  remaining > 0 ? 'À PAYER' : 'SOLDÉ',
                                  style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold,
                                    color: remaining > 0 ? PdfColors.red900 : PdfColors.green900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 18),

                  // Infos type et montant
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'TYPE',
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey600,
                                letterSpacing: 1,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              debtType,
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'MONTANT INITIAL',
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey600,
                                letterSpacing: 1,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              _fmtAmount(debtAmount),
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 16),

                  // Tableau d'historique
                  pw.Text(
                    'TRANSACTIONS (${history.length})',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  pw.SizedBox(height: 10),

                  // En-tête du tableau avec fond sombre
                  pw.Container(
                    color: PdfColors.blue900,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            'DESCRIPTION',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            'MONTANT',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                              letterSpacing: 0.8,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            'DATE',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                              letterSpacing: 0.8,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Expanded(
                          flex: 3,
                          child: pw.Text(
                            'NOTE',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                              letterSpacing: 0.8,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Lignes d'historique
                  ...history.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final type = item['type'] as String? ?? '';
                    final amount = _parseDouble(item['amount']);
                    final data = item['data'] as Map? ?? <String, dynamic>{};
                    final notes = data['notes']?.toString().trim() ?? '';
                    final operationType = data['operation_type']?.toString() ?? '';

                    String description = '';
                    
                    // ✅ NOUVEAU: Utiliser operation_type pour une meilleure clarté
                    if (type == 'creation') {
                      description = debtType == 'Emprunt' ? 'Emprunt initial' : 'Prêt initial';
                    } else if (type == 'payment') {
                      // Vérifier si c'est un remboursement d'emprunt ou un paiement de prêt
                      if (operationType == 'loan_payment') {
                        description = 'Remboursement emprunt';
                      } else {
                        description = 'Paiement reçu';
                      }
                    } else {
                      // Addition: vérifie si c'est un emprunt supplémentaire ou un prêt supplémentaire
                      if (operationType == 'loan_addition') {
                        description = 'Emprunt supplémentaire';
                      } else {
                        description = 'Montant prêté supplémentaire';
                      }
                    }

                    final dateStr = type == 'payment'
                        ? _formatPaymentDate(data['paid_at'])
                        : _fmtDate(data['created_at'] ?? data['added_at'] ?? data['date'] ?? data['createdAt']);

                    // Alternating row colors: odd rows light grey, even rows white
                    final rowColor = index % 2 == 0 ? PdfColors.white : PdfColors.grey100;

                    return pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                        ),
                        color: notes.isNotEmpty ? PdfColors.yellow50 : rowColor,
                      ),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            flex: 2,
                            child: pw.Text(
                              description,
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey800,
                                fontWeight: pw.FontWeight.bold,
                              ),
                              maxLines: 2,
                            ),
                          ),
                          pw.Expanded(
                            flex: 2,
                            child: pw.Text(
                              _fmtAmount(amount),
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: type == 'payment' ? PdfColors.green700 : PdfColors.orange700,
                              ),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                          pw.Expanded(
                            flex: 2,
                            child: pw.Text(
                              dateStr,
                              style: pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.grey700,
                              ),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                          pw.Expanded(
                            flex: 3,
                            child: pw.Text(
                              notes.isNotEmpty ? notes : '-',
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontStyle: notes.isNotEmpty ? pw.FontStyle.italic : pw.FontStyle.normal,
                                color: notes.isNotEmpty ? PdfColors.orange800 : PdfColors.grey500,
                              ),
                              maxLines: 2,
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  pw.SizedBox(height: 20),
                  pw.Divider(color: PdfColors.blue400, thickness: 1.5),
                  pw.SizedBox(height: 16),

                  // Résumé final - style badge
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      border: pw.Border.all(color: PdfColors.blue400, width: 1),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Montant initial',
                              style: pw.TextStyle(
                                fontSize: 11,
                                color: PdfColors.grey700,
                              ),
                            ),
                            pw.Text(
                              _fmtAmount(debtAmount),
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey800,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 12),
                        pw.Divider(color: PdfColors.blue200, thickness: 0.5),
                        pw.SizedBox(height: 12),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'SOLDE RESTANT',
                              style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold,
                                color: remaining > 0 ? PdfColors.red700 : PdfColors.green700,
                              ),
                            ),
                            pw.Text(
                              _fmtAmount(remaining.abs()),
                              style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                                color: remaining > 0 ? PdfColors.red700 : PdfColors.green700,
                              ),
                            ),
                          ],
                        ),
                        if (remaining <= 0) ...[
                          pw.SizedBox(height: 12),
                          pw.Text(
                            '✓ DETTE COMPLÈTEMENT SOLDÉE',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green700,
                            ),
                          ),
                        ] else ...[
                          pw.SizedBox(height: 12),
                          pw.Text(
                            'SOLDE À PAYER',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.red700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      // Générer les bytes du PDF
      final pdfBytes = await pdf.save();

      // Créer un nom de fichier
      final fileName = 'Historique_${titleName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (kIsWeb) {
        // Sur le web, télécharger directement
        await downloadPdfOnWeb(pdfBytes, fileName);

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF téléchargé: $fileName'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Sur mobile, créer un fichier temporaire
        final tempDir = await Directory.systemTemp.createTemp();
        final pdfFile = File('${tempDir.path}/$fileName');
        await pdfFile.writeAsBytes(pdfBytes);

        // Partager le PDF
        await Share.shareXFiles(
          [XFile(pdfFile.path, mimeType: 'application/pdf')],
          text: 'Historique de transaction - $titleName ($debtType)',
        );

        // Nettoyer le fichier temporaire après partage
        if (pdfFile.existsSync()) {
          pdfFile.deleteSync();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  // ✅ NOUVEAU : Dialog pour ajouter dans les contacts avec nom custom
  void _showAddContactDialog(String defaultName) {
    final nameCtl = TextEditingController(text: defaultName);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final textColorSecondary = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? Colors.white24 : Colors.black26;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AJOUTER DANS MES CONTACTS',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choisissez le nom que vous voulez utiliser',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                  color: textColorSecondary,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtl,
                style: TextStyle(fontSize: 14, color: textColor),
                decoration: InputDecoration(
                  hintText: 'Ex: Papa, Papeeeee...',
                  hintStyle: TextStyle(color: borderColor),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: borderColor, width: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: borderColor, width: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue, width: 1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: textColorSecondary,
                    ),
                    child: const Text('ANNULER'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _addContactFromDebt(nameCtl.text.trim());
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                    ),
                    child: const Text('AJOUTER'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ NOUVEAU : Ajouter le créancier comme contact
  Future<void> _addContactFromDebt(String customName) async {
    if (_debt['creditor_phone'] == null || _debt['creditor_phone'].toString().isEmpty) {
      _showSnackbar('Numéro de créancier introuvable');
      return;
    }

    try {
      final body = {
        'name': customName.isNotEmpty ? customName : _debt['display_creditor_name'] ?? _debt['creditor_phone'],
        'client_number': _debt['creditor_phone'],
      };
      final headers = {
        'Content-Type': 'application/json',
        'x-owner': widget.ownerPhone,
      };

      final res = await http.post(
        Uri.parse('$apiHost/clients'),
        headers: headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 201 || res.statusCode == 200) {
        final data = json.decode(res.body);
        _showSnackbar('Contact ajouté avec succès');
        
        // ✅ Mettre à jour le nom affiché en temps réel
        setState(() {
          _debt['display_creditor_name'] = customName.isNotEmpty ? customName : _debt['display_creditor_name'];
          _client = data;
        });
        
        // Recharger les données
        await _loadAllData();
        
        // ✅ Redémarrer le refresh automatique (DÉSACTIVÉ)
        // _startAutoRefresh();
      } else {
        _showSnackbar('Erreur lors de l\'ajout du contact');
      }
    } catch (e) {
      _showSnackbar('Erreur: $e');
    }
  }

  // ✅ NOUVEAU : Afficher un snackbar
  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final textColorSecondary = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? Colors.white24 : Colors.black26;

    // ✅ CALCULS CORRECTS DU SOLDE (incluant les additions)
    // Utiliser total_debt du backend si disponible (amount + additions)
    final totalDebt = _parseDouble(_debt['total_debt'] ?? _debt['amount']);
    final remaining = _parseDouble(_debt['remaining'] ?? _calculateRemaining(_debt, payments));
    final totalPaid = totalDebt - remaining; // Montant payé = total - restant
    final progress = totalDebt == 0 ? 0.0 : (totalPaid / totalDebt).clamp(0.0, 1.0);
    
    // Parse due date for intelligent display
    final dueDate = _parseDate(_debt['due_date']);

    // ✅ NOM À AFFICHER : Client normal OU Créancier si créé par quelqu'un d'autre
    final clientName = _getClientName(_client);
    String displayName = clientName; // Défaut : nom du client
    String? displayPhone; // ✅ Numéro séparé pour affichage élégant
    
    // ✅ NOUVEAU : Vérifier si cette dette a été créée par quelqu'un d'autre
    final createdByOther = _debt['created_by_other'] == true || 
                          (_debt['created_by'] != null && _debt['created_by'] != widget.ownerPhone);
    
    // Si créée par quelqu'un d'autre, afficher le nom + numéro du créancier
    if (createdByOther) {
      final displayCreditorName = _debt['display_creditor_name']?.toString() ?? '';  // ✅ Priorité: client.name > creditor_name
      final creditorPhone = _debt['creditor_phone']?.toString() ?? _debt['creditor']?.toString() ?? '';  // ✅ Le numéro du créancier
      displayName = displayCreditorName.isNotEmpty 
          ? displayCreditorName
          : (creditorPhone.isNotEmpty ? creditorPhone : clientName);
      displayPhone = creditorPhone.isNotEmpty ? creditorPhone : null;  // ✅ TOUJOURS afficher le numéro du créancier
    } else {
      // ✅ CORRIGÉ : Chercher le numéro du client dans _client ou _debt
      displayPhone = _client?['client_number'] ?? _debt['client_number'] ?? _debt['client_phone'] ?? _debt['phone'];
    }
    
    // ✅ NOUVEAU : Déterminer le type
    final debtType = _debt['type'] ?? 'debt';
    final isPret = debtType == 'debt';

    return Scaffold(
      backgroundColor: colors.surface,
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
            const Tab(text: 'DÉTAILS'),
          ],
          labelColor: isPret ? Colors.orange : Colors.purple,
          unselectedLabelColor: textColorSecondary,
          indicatorColor: isPret ? Colors.orange : Colors.purple,
          indicatorWeight: 2,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ✅ NOUVEAU : Alerte si cette dette a été créée par quelqu'un d'autre
            if (createdByOther)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  border: Border(
                    bottom: BorderSide(color: Colors.orange.withOpacity(0.3), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cette dette a été créée par quelqu\'un d\'autre',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Vous pouvez la contester si vous n\'êtes pas d\'accord',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            
            // Contenu principal
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ✅ TAB 1 : PRÊT / EMPRUNT (Actions rapides + Solde)
                  _buildMainTab(context, remaining, totalDebt, totalPaid, progress, dueDate, displayName, displayPhone, isPret, textColor, textColorSecondary, borderColor, createdByOther),
                  
                  // ✅ TAB 2 : DÉTAILS (Notes + Historique)
                  _buildDetailsTab(context, textColor, textColorSecondary, borderColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainTab(
    BuildContext context,
    double remaining,
    double totalDebt,
    double totalPaid,
    double progress,
    DateTime? dueDate,
    String displayName,
    String? displayPhone,
    bool isPret,
    Color textColor,
    Color textColorSecondary,
    Color borderColor,
    bool createdByOther,
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // ✅ NOM ÉLÉGANT (EN HAUT) - style titre
                          Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // ✅ NUMÉRO EN BAS - beau et lisible (toujours affiché)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                displayPhone ?? _getTermClient(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.3,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          )],
                      ),
                    ),
                    if (dueDate != null) _buildDueDateWidget(dueDate),
                  ],
                ),
                const SizedBox(height: 20),
                
                // ✅ AFFICHAGE ÉLÉGANT ET MINIMALISTE DU SOLDE
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  decoration: BoxDecoration(
                    color: remaining <= 0 
                        ? Colors.green.withOpacity(0.08)
                        : Colors.red.withOpacity(0.08),
                    border: Border(
                      bottom: BorderSide(
                        color: remaining <= 0 ? Colors.green : Colors.red,
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Label du solde
                      Text(
                        remaining <= 0 
                            ? 'TRANSACTION COMPLÉTÉE ✓'
                            : (isPret 
                                ? '$displayName vous doit'
                                : 'Vous devez à $displayName'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: remaining <= 0 ? Colors.green : Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      // Montant principal - plus élégant et compact
                      Text(
                        _fmtAmount(remaining.abs()),
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w400,
                          color: remaining <= 0 ? Colors.green : Colors.red,
                          height: 1,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // ✅ SECTION CORRIGÉE : Progression avec "JE DOIS"
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                const SizedBox(height: 8),
                                Text(
                                  _fmtAmount(totalPaid),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 45,
                            color: borderColor,
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
                                const SizedBox(height: 8),
                                Text(
                                  remaining < 0 
                                      ? _fmtAmount(remaining.abs())
                                      : _fmtAmount(remaining),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: remaining < 0 ? Colors.purple : (remaining <= 0 ? Colors.green : Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Theme.of(context).dividerColor.withOpacity(0.2),
                          color: remaining <= 0 ? Colors.green : Theme.of(context).colorScheme.primary,
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),

          // ✅ Actions rapides - ÉLÉGANTES AVEC FOND SUBTIL
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: remaining <= 0 
                      ? Colors.grey.withOpacity(0.08)
                      : (isPret ? Colors.orange.withOpacity(0.08) : Colors.purple.withOpacity(0.08)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextButton.icon(
                    onPressed: remaining <= 0 ? null : _addPayment,
                    style: TextButton.styleFrom(
                      foregroundColor: remaining <= 0 
                        ? Colors.grey.withOpacity(0.5)
                        : (isPret ? Colors.orange : Colors.purple),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      visualDensity: VisualDensity.standard,
                    ),
                    icon: Icon(
                      isPret ? Icons.account_balance_wallet : Icons.payment,
                      size: 18,
                      color: remaining <= 0 
                        ? Colors.grey.withOpacity(0.5)
                        : (isPret ? Colors.orange : Colors.purple),
                    ),
                    label: Text(
                      _getPaymentButtonLabel(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                        color: remaining <= 0 
                          ? Colors.grey.withOpacity(0.5)
                          : (isPret ? Colors.orange : Colors.purple),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextButton.icon(
                    onPressed: _addAddition,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      visualDensity: VisualDensity.standard,
                    ),
                    icon: const Icon(
                      Icons.add_circle_outline,
                      size: 18,
                      color: Colors.green,
                    ),
                    label: Text(
                      _getAddButtonLabel(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // ✅ NOUVEAU : Bouton "Ajouter dans mes contacts" si créé par quelqu'un d'autre
          if (createdByOther && (_client == null || _client?.isEmpty == true))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextButton.icon(
                  onPressed: () => _showAddContactDialog(displayName),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    visualDensity: VisualDensity.standard,
                  ),
                  icon: const Icon(
                    Icons.person_add,
                    size: 18,
                    color: Colors.blue,
                  ),
                  label: const Text(
                    'AJOUTER DANS MES CONTACTS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ),
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
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Remboursement complet ✓',
                        style: TextStyle(
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
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _downloadHistoryPdf,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.picture_as_pdf, size: 12, color: Colors.red),
                        const SizedBox(width: 4),
                        Text(
                          'PDF',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
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

          // ✅ NOUVEAU : Section CONTESTATIONS
          if (disputes.isNotEmpty) ...[
            _buildSectionHeader('CONTESTATIONS', trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${disputes.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.red,
                ),
              ),
            )),
            const SizedBox(height: 12),
            ..._buildDisputesList(textColor, textColorSecondary, borderColor),
            const SizedBox(height: 20),
          ],

          // ✅ NOUVEAU : Bouton pour contester
          if (!disputes.any((d) => d['resolved_at'] == null && d['disputed_by'] == widget.ownerPhone))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _createDispute,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warning_amber, size: 18, color: Colors.orange.withOpacity(0.7)),
                        const SizedBox(width: 8),
                        Text(
                          'CONTESTER CETTE DETTE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.withOpacity(0.7),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          
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

  // ✅ NOUVEAU : Builder pour afficher les contestations avec design élégant
  List<Widget> _buildDisputesList(Color textColor, Color textColorSecondary, Color borderColor) {
    return disputes.map((dispute) {
      final isResolved = dispute['resolved_at'] != null;
      // ✅ Utiliser disputed_by_display_name du backend (contact_name ou official_name)
      final disputedBy = dispute['disputed_by_display_name'] ?? dispute['disputed_by_name'] ?? dispute['disputed_by'] ?? 'Inconnu';
      final reason = dispute['reason'] ?? 'Pas de raison spécifiée';
      final message = dispute['message'] ?? '';
      final createdAt = _parseDate(dispute['created_at']);
      
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: isResolved ? Colors.green : Colors.orange,
              width: 3,
            ),
            bottom: BorderSide(
              color: borderColor,
              width: 0.5,
            ),
          ),
          color: isResolved 
              ? Colors.green.withOpacity(0.02) 
              : Colors.orange.withOpacity(0.02),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête minimaliste
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isResolved ? Icons.check_circle : Icons.info,
                              size: 16,
                              color: isResolved ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                disputedBy,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _fmtDate(createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: textColorSecondary,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: isResolved 
                          ? Colors.green.withOpacity(0.12)
                          : Colors.orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      isResolved ? 'Résolue' : 'Attente',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isResolved ? Colors.green : Colors.orange,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Séparateur subtil
            Divider(
              height: 1,
              thickness: 0.5,
              color: borderColor,
              indent: 16,
              endIndent: 16,
            ),
            
            // Raison + Message combinés
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reason,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                      height: 1.4,
                    ),
                  ),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: textColorSecondary.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        message,
                        style: TextStyle(
                          fontSize: 11,
                          color: textColorSecondary,
                          height: 1.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Note de résolution si présente
            if (isResolved && dispute['resolution_note'] != null && (dispute['resolution_note'] as String).isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Réponse',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.green,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dispute['resolution_note'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.withOpacity(0.85),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // ✅ BOUTON REFUSER LA CONTESTATION (visible seulement si je suis le créancier et pas résolue)
            if (!isResolved && _debt['creditor'] == widget.ownerPhone) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => _refuseDispute(dispute['id'], dispute),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.08),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    child: Text(
                      'RÉPONDRE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.red,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
            ] else if (!isResolved) ...[
              const SizedBox(height: 4),
            ],
          ],
        ),
      );
    }).toList();
  }
  
  // ✅ NOUVEAU : Refuser une contestation
  Future<void> _refuseDispute(dynamic disputeId, Map dispute) async {
    final commentCtl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    final ok = await showDialog<bool>(
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
                'Refuser la contestation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Votre réponse sera envoyée au contestant.',
                style: TextStyle(
                  fontSize: 14,
                  color: textColor.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 20),
              
              // Commentaire
              TextField(
                controller: commentCtl,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Votre réponse',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  hintText: 'Expliquez pourquoi vous rejetez cette contestation...',
                ),
                style: TextStyle(color: textColor, fontSize: 14),
              ),
              const SizedBox(height: 24),
              
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('ANNULER'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('REFUSER'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (ok == true && commentCtl.text.trim().isNotEmpty) {
      try {
        final headers = {
          'Content-Type': 'application/json',
          if (widget.ownerPhone.isNotEmpty) 'x-owner': widget.ownerPhone
        };
        
        final body = {
          'resolution_note': commentCtl.text.trim(),
        };

        final res = await http.patch(
          Uri.parse('$apiHost/debts/${_debt['id']}/disputes/$disputeId/resolve'),
          headers: headers,
          body: json.encode(body),
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          if (mounted) {
            _showSnackbar('Contestation refusée avec commentaire');
            await _loadAllData(); // Recharger pour mettre à jour
          }
        } else {
          _showSnackbar('Erreur lors du refus de la contestation');
        }
      } catch (e) {
        _showSnackbar('Erreur: $e');
      }
    }
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