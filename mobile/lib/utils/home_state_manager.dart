
/// 🏠 Gestionnaire d'état pour la HomePage
class HomePageStateManager {
  // État des onglets et filtres
  int tabIndex = 0;
  String debtSubTab = 'prets';
  String searchQuery = '';
  bool isSearching = false;
  bool showTotalCard = true;
  bool showAmountFilter = false;
  bool showUnpaidDetails = false;
  double minDebtAmount = 0.0;
  double maxDebtAmount = 0.0;

  // État de synchronisation
  bool isSyncing = false;

  // État des expansions
  final Set<dynamic> expandedClients = {};

  /// Basculer l'onglet principal
  void switchTab(int newTab) {
    tabIndex = newTab;
  }

  /// Basculer le sous-onglet de dettes
  void switchDebtSubTab(String newSubTab) {
    debtSubTab = newSubTab;
  }

  /// Basculer la recherche
  void toggleSearch() {
    isSearching = !isSearching;
    if (!isSearching) {
      searchQuery = '';
    }
  }

  /// Basculer l'affichage du filtre de montant
  void toggleAmountFilter() {
    showAmountFilter = !showAmountFilter;
  }

  /// Basculer l'expansion d'un client
  void toggleClientExpansion(dynamic compositeKey) {
    if (expandedClients.contains(compositeKey)) {
      expandedClients.remove(compositeKey);
    } else {
      expandedClients.add(compositeKey);
    }
  }

  /// Vérifier si un client est étendu
  bool isClientExpanded(dynamic compositeKey) {
    return expandedClients.contains(compositeKey);
  }

  /// Réinitialiser les filtres
  void resetFilters() {
    searchQuery = '';
    minDebtAmount = 0.0;
    maxDebtAmount = 0.0;
    showAmountFilter = false;
    expandedClients.clear();
  }

  /// Réinitialiser l'état complet
  void reset() {
    tabIndex = 0;
    debtSubTab = 'prets';
    isSearching = false;
    resetFilters();
    isSyncing = false;
  }
}
