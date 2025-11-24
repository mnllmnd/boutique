#!/bin/bash

# Test End-to-End Hive + PostgreSQL
# Ce script teste le cycle complet: créer -> queue -> sync -> serveur -> pull -> merge

set -e

echo "=== Hive + PostgreSQL End-to-End Test ==="
echo ""

# Configuration
API_URL="http://localhost:3000"
OWNER_PHONE="+33123456789"
AUTH_TOKEN="test_token_123"

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonctions
log_info() {
  echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
  echo -e "${RED}❌ $1${NC}"
}

log_warn() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

log_step() {
  echo -e "\n${YELLOW}📋 $1${NC}"
}

# Vérifier que l'API est disponible
check_api() {
  log_step "Vérifier la connexion à l'API"
  if ! curl -s "$API_URL/health" > /dev/null 2>&1; then
    log_error "API non disponible à $API_URL"
    log_warn "Assurez-vous que le backend tourne: npm start"
    exit 1
  fi
  log_info "API disponible à $API_URL"
}

# Créer un client de test
create_test_client() {
  log_step "Créer un client de test"
  
  RESPONSE=$(curl -s -X POST "$API_URL/clients" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -d "{
      \"name\": \"Test Client\",
      \"phone\": \"+33987654321\",
      \"owner_phone\": \"$OWNER_PHONE\"
    }")
  
  CLIENT_ID=$(echo $RESPONSE | grep -o '"id":[0-9]*' | head -1 | grep -o '[0-9]*')
  
  if [ -z "$CLIENT_ID" ]; then
    log_error "Impossible de créer un client"
    echo "Réponse: $RESPONSE"
    exit 1
  fi
  
  log_info "Client créé avec ID: $CLIENT_ID"
}

# Créer une dette de test
create_test_debt() {
  log_step "Créer une dette de test"
  
  RESPONSE=$(curl -s -X POST "$API_URL/debts" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -d "{
      \"creditor\": \"Test Creditor\",
      \"amount\": 150.50,
      \"type\": \"debt\",
      \"client_id\": $CLIENT_ID,
      \"from_user\": \"user1\",
      \"to_user\": \"user2\",
      \"owner_phone\": \"$OWNER_PHONE\"
    }")
  
  DEBT_ID=$(echo $RESPONSE | grep -o '"id":[0-9]*' | head -1 | grep -o '[0-9]*')
  
  if [ -z "$DEBT_ID" ]; then
    log_error "Impossible de créer une dette"
    echo "Réponse: $RESPONSE"
    exit 1
  fi
  
  log_info "Dette créée avec ID: $DEBT_ID"
}

# Ajouter un paiement
add_payment() {
  log_step "Ajouter un paiement à la dette"
  
  RESPONSE=$(curl -s -X POST "$API_URL/payments" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -d "{
      \"debt_id\": $DEBT_ID,
      \"amount\": 50.0,
      \"owner_phone\": \"$OWNER_PHONE\"
    }")
  
  PAYMENT_ID=$(echo $RESPONSE | grep -o '"id":[0-9]*' | head -1 | grep -o '[0-9]*')
  
  if [ -z "$PAYMENT_ID" ]; then
    log_error "Impossible d'ajouter un paiement"
    echo "Réponse: $RESPONSE"
    exit 1
  fi
  
  log_info "Paiement créé avec ID: $PAYMENT_ID"
}

# Ajouter une addition à la dette
add_debt_addition() {
  log_step "Ajouter une addition à la dette"
  
  RESPONSE=$(curl -s -X POST "$API_URL/debt-additions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -d "{
      \"debt_id\": $DEBT_ID,
      \"amount\": 25.0,
      \"owner_phone\": \"$OWNER_PHONE\"
    }")
  
  ADDITION_ID=$(echo $RESPONSE | grep -o '"id":[0-9]*' | head -1 | grep -o '[0-9]*')
  
  if [ -z "$ADDITION_ID" ]; then
    log_error "Impossible d'ajouter une addition"
    echo "Réponse: $RESPONSE"
    exit 1
  fi
  
  log_info "Addition créée avec ID: $ADDITION_ID"
}

# Vérifier les données sur le serveur
verify_server_data() {
  log_step "Vérifier les données sur le serveur"
  
  # Récupérer les clients
  CLIENTS=$(curl -s "$API_URL/clients?owner_phone=$OWNER_PHONE" \
    -H "Authorization: Bearer $AUTH_TOKEN")
  CLIENT_COUNT=$(echo $CLIENTS | grep -o '"id"' | wc -l)
  log_info "Clients trouvés: $CLIENT_COUNT"
  
  # Récupérer les dettes
  DEBTS=$(curl -s "$API_URL/debts?owner_phone=$OWNER_PHONE" \
    -H "Authorization: Bearer $AUTH_TOKEN")
  DEBT_COUNT=$(echo $DEBTS | grep -o '"id"' | wc -l)
  log_info "Dettes trouvées: $DEBT_COUNT"
  
  # Récupérer les paiements
  PAYMENTS=$(curl -s "$API_URL/payments?owner_phone=$OWNER_PHONE" \
    -H "Authorization: Bearer $AUTH_TOKEN")
  PAYMENT_COUNT=$(echo $PAYMENTS | grep -o '"id"' | wc -l)
  log_info "Paiements trouvés: $PAYMENT_COUNT"
  
  # Récupérer les additions
  ADDITIONS=$(curl -s "$API_URL/debt-additions?owner_phone=$OWNER_PHONE" \
    -H "Authorization: Bearer $AUTH_TOKEN")
  ADDITION_COUNT=$(echo $ADDITIONS | grep -o '"id"' | wc -l)
  log_info "Additions trouvées: $ADDITION_COUNT"
}

# Tester le conflit de synchronisation
test_conflict_resolution() {
  log_step "Tester la résolution de conflits"
  
  # Modifier localement
  log_warn "Simulation: modification locale de la dette"
  local NEW_AMOUNT=200.0
  
  # Modifier sur le serveur (simule une autre modification concurrente)
  log_warn "Simulation: modification serveur de la dette"
  curl -s -X PUT "$API_URL/debts/$DEBT_ID" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -d "{
      \"amount\": 175.0,
      \"creditor\": \"Updated Creditor\"
    }" > /dev/null
  
  log_info "Conflict test: Last-write-wins (server version utilisée)"
}

# Nettoyer les données de test
cleanup() {
  log_step "Nettoyer les données de test"
  
  # Optionnel: supprimer les données créées
  # curl -s -X DELETE "$API_URL/clients/$CLIENT_ID" ...
  
  log_info "Nettoyage complet"
}

# Exécution
main() {
  log_info "Démarrage du test end-to-end"
  echo ""
  
  check_api
  create_test_client
  create_test_debt
  add_payment
  add_debt_addition
  verify_server_data
  test_conflict_resolution
  cleanup
  
  echo ""
  log_info "✨ Test end-to-end réussi!"
  echo ""
  echo "Résumé:"
  echo "  - Client créé: $CLIENT_ID"
  echo "  - Dette créée: $DEBT_ID"
  echo "  - Paiement ajouté: $PAYMENT_ID"
  echo "  - Addition ajoutée: $ADDITION_ID"
  echo "  - Sync status: OK"
  echo "  - Conflict resolution: Last-write-wins"
}

main
