# 🏛️ Annuaire Officiel - Lookup Automatique

## 📋 Quoi de Neuf?

Quand un **propriétaire de boutique** (présent dans la table `owners`) vous crée une dette ou un contact, le système cherche automatiquement ses **informations officielles** dans l'annuaire!

## 🎯 Cas d'Usage

### Avant ❌
```
Jean (boutique) t'envoie une demande de paiement
- Son numéro: +237 123 456 789
- Dans ses contacts: son nom = "Client" ou le numéro brut
- ❌ Confus: tu ne sais pas à qui tu dois payer
```

### Après ✅
```
Jean (boutique) t'envoie une demande de paiement
- Son numéro: +237 123 456 789
- Système cherche dans la table owners
- Trouve: "Jean Dupont" ou "Boutique Jean"
- ✅ Clair: tu sais exactement à qui tu dois
```

## 🔄 Flux Détaillé

### Scénario 1: Jean me Crée un Contact

```
1. Jean POST /clients avec mon numéro
   POST /clients
   {
     "client_number": "+237 999 888 777",  ← Mon numéro
     "name": "Mon Client"                   ← Son idée de mon nom
   }

2. Système:
   ✅ Cherche si contact existe déjà (matching)
   ✅ Cherche mon profil dans owners par numéro
   ✅ Trouve mes infos: shop_name="Mon Shop" ou first_name="Jean"
   
3. Résultat:
   Créé: "Jean Dupont" (nom officiel)  ← Pas "Mon Client"!
```

### Scénario 2: Jean me Crée une Dette

```
1. Jean POST /debts avec mon numéro
   POST /debts
   {
     "client_number": "+237 999 888 777",  ← Mon numéro
     "amount": 10000
   }

2. Mon serveur (quand j'affiche la dette):
   GET /debts
   ✅ Voit que creditor_phone = "+237 123 456 789"
   ✅ Cherche ce numéro dans owners
   ✅ Trouve: shop_name="Boutique Jean"
   
3. Affichage:
   "Tu dois: 10000F à Boutique Jean"  ← Nom officiel!
```

## 📊 Table `owners` - Priorité de Noms

```sql
SELECT * FROM owners WHERE phone = '...';

Priorité:
1. shop_name (boutique)
2. first_name + last_name (propriétaire)
3. numéro de téléphone (fallback)

Example:
- shop_name = "Boutique Jean"          → "Boutique Jean" ✅
- shop_name = NULL, first_name = "Jean", last_name = "Dupont" → "Jean Dupont" ✅
- Tous NULL → "+237 123 456 789"
```

## 🔍 Où le Lookup Se Produit?

### 1. **Route `POST /clients`**
```javascript
// Quand quelqu'un me crée un contact
findOrCreateClient(clientNumber, clientName, avatarUrl, ownerPhone)
  → Cherche officialOwner = getOfficialOwnerName(clientNumber)
  → Crée client avec officialName si trouvé
```

### 2. **Route `GET /debts`**
```javascript
// Quand j'affiche les dettes reçues
for (const debt of debts) {
  if (!isCreatedByMe) {  // ← Je dois de l'argent
    officialName = await getOfficialOwnerName(debt.creditor)
    displayCreditorName = officialName || debt.creditor
  }
}
```

## 💻 Code - Implémentation

### Fonction Principale
```javascript
async function getOfficialOwnerName(ownerPhone) {
  // Chercher dans la table owners
  const res = await pool.query(
    'SELECT shop_name, first_name, last_name FROM owners WHERE phone = $1',
    [ownerPhone]
  );
  
  if (res.rowCount === 0) return null;
  
  const owner = res.rows[0];
  
  // Priorité 1: shop_name
  if (owner.shop_name?.trim()) {
    return owner.shop_name;
  }
  
  // Priorité 2: first_name + last_name
  const firstName = owner.first_name?.trim() || '';
  const lastName = owner.last_name?.trim() || '';
  if (firstName || lastName) {
    return `${firstName} ${lastName}`.trim();
  }
  
  // Fallback: NULL (utiliser le numéro ou le nom fourni)
  return null;
}
```

### Appels dans `findOrCreateClient`
```javascript
// Quand on crée un client avec un numéro inconnu
const officialOwner = await getOfficialOwnerName(clientNumber);
if (officialOwner) {
  console.log(`Nom officiel trouvé: ${officialOwner}`);
  officialName = officialOwner;  // ← Utiliser le nom officiel
}

const newClient = await pool.query(
  'INSERT INTO clients (client_number, name, ...) VALUES ($1, $2, ...)',
  [clientNumber, officialName || clientNumber, ...]
);
```

## 📋 Exemple Complet

### Situation:
```
Propriétaire A (shop_name = "Boutique A"):
- phone = "+237 111 111 111"
- shop_name = "Boutique A"
- first_name = "Antoine"
- last_name = "Martin"

Propriétaire B (moi):
- phone = "+237 222 222 222"
```

### Étape 1: Antoine Crée un Contact pour moi
```bash
# Antoine (serveur A) POST /clients
curl -X POST http://boutique-a/api/clients \
  -H "x-owner: +237 111 111 111" \
  -d '{
    "client_number": "+237 222 222 222",
    "name": "Client de test"
  }'
```

### Étape 2: Mon Serveur Reçoit
```javascript
// Mon serveur traite le POST /clients
findOrCreateClient(
  "+237 222 222 222",  // Mon numéro
  "Client de test",    // Proposé par Antoine
  null,
  "+237 111 111 111"   // Le propriétaire de la boutique A
)

// Cherche getOfficialOwnerName("+237 222 222 222")
// → Null (je ne suis pas dans les owners du serveur A)

// Crée client: "Client de test"
```

### Étape 3: Antoine Voit le Contact
```javascript
// Côté Antoine: Contact créé avec mon nom "Client de test"
// (C'est normal, il ne peut pas connaître mon profil officiel)
```

### Étape 4: Antoine me Crée une Dette
```bash
# Antoine POST /debts avec mon numéro
curl -X POST http://boutique-a/api/debts \
  -H "x-owner: +237 111 111 111" \
  -d '{
    "client_number": "+237 222 222 222",
    "amount": 5000
  }'
```

### Étape 5: Je Reçois la Dette
```bash
# Moi: GET /debts

Résultat:
{
  "id": 999,
  "type": "loan",  # ← Inversé (c'est un emprunt pour moi)
  "creditor": "+237 111 111 111",
  "creditor_name": "Antoine Martin",  # ← Ou "Boutique A" si c'est son shop_name
  "amount": 5000,
  "display_creditor_name": "Boutique A"  # ← Nom officiel trouvé!
}
```

## 🎯 Avantages

✅ **Clarté** - Voir les vrais noms au lieu des numéros
✅ **Confiance** - Vérifier que tu dois vraiment à cette boutique
✅ **Automatique** - Aucune saisie manuelle
✅ **Cohérence** - Même nom partout (officiel)
✅ **Scalable** - Fonctionne avec des centaines de boutiques

## ⚠️ Cas Particuliers

### Cas 1: Personne non dans `owners`
```
Jean (contact random) me crée un contact
→ getOfficialOwnerName("+237 ...") = NULL
→ Utilise le nom fourni par Jean
```

### Cas 2: Propriétaire sans profil complet
```
owners row pour +237 123 456 789:
- shop_name = NULL
- first_name = "Jean"
- last_name = NULL

→ Utilise "Jean" (priorité 2)
```

### Cas 3: Contact déjà existant
```
J'ai déjà "Jean Dupont" dans mes contacts
Quelqu'un me crée un nouveau contact avec même numéro
→ Matching détecte le doublon
→ Utilise le contact existant
```

## 🔧 Configuration / Installation

1. **Rien à faire!** La fonctionnalité utilise la table `owners` existante
2. **Migration 017**: Ajoute `normalized_phone` (optionnel, pour améliorer le matching)
3. **Redémarrer le backend**: `npm start`

## 📝 Logs pour Monitorer

```
✅ [MATCHING CLIENTS] Nom officiel trouvé pour +237123456789: Boutique Jean
✅ [DEBT DISPLAY] Créancier +237111111111 trouvé dans l'annuaire: Boutique A
```

## 🧪 Test Rapide

```javascript
// 1. Vérifier la table owners
SELECT phone, shop_name, first_name, last_name FROM owners LIMIT 5;

// 2. Créer un client avec un numéro de propriétaire existant
curl -X POST http://localhost:3000/api/clients \
  -H "x-owner: +237600000000" \
  -H "Content-Type: application/json" \
  -d '{
    "client_number": "+237700000000",  # ← Numéro existant dans owners
    "name": "Essai"
  }'

// 3. Vérifier le résultat - devrait avoir le nom officiel!
```

## 🎉 Résumé

**Avant**: Contacts avec des noms génériques (Client, Contact) ou numéros
**Après**: Noms officiels des propriétaires de boutiques trouvés automatiquement

C'est comme avoir un **annuaire téléphonique intégré** où chaque numéro est reconnu! 📞✨
