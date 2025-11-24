# 🧪 GUIDE DE TEST : PRÊTER/EMPRUNTER

## TEST FLOW 1 : PRÊTER (Type: debt)

### Étape 1 : Lancer l'app et aller à HOME PAGE
```
✓ Accueil chargé
✓ Visible : Tab "DETTES" et Tab "CLIENTS"
✓ FAB Button (+) au centre visible
```

### Étape 2 : Cliquer sur (+) Button
```
✓ Bottom Sheet s'affiche
✓ Title : "AJOUTER UNE TRANSACTION"
✓ Visible : 
  - PRÊTER (flèche verte) "Je donne l'argent au client"
  - EMPRUNTER (flèche bleue) "Je reçois l'argent du client"
```

### Étape 3 : Tapper sur PRÊTER
```
✓ AddDebtPage s'ouvre
✓ Title : "NOUVEAU PRÊT"
✓ Subtitle : "Je sors de l'argent au client"
✓ Champs visibles :
  - Client dropdown
  - Montant
  - Échéance
  - Notes
  - Bouton "PRÊTER"
```

### Étape 4 : Remplir et soumettre
```
✓ Sélectionner un client
✓ Entrer montant : 50000
✓ Cliquer "PRÊTER"
✓ ATTENDRE 2-3 secondes
✓ VÉRIFIER Snackbar : "✓ Prêt créé"
✓ REVENIR à HOME PAGE
```

### Étape 5 : Vérifier dans Dettes Tab
```
✓ Nouvelle dette visible dans liste
✓ Montant : 50000 F
✓ Client : le nom choisi
✓ Status : à percevoir
```

### Étape 6 : Ouvrir DEBT DETAILS
```
✓ Cliquer sur la dette créée
✓ DebtDetailsPage s'ouvre
✓ Title : "DÉTAILS DETTE"
✓ AppBar buttons :
  - Bouton +  avec tooltip "Prêter plus"
  - Bouton 💳 avec tooltip "Encaisser"
```

### Étape 7 : Tester les boutons
```
✓ Cliquer Encaisser → AddPaymentPage s'ouvre
✓ Entrer montant, confirmer
✓ Revenir, montant payé mis à jour
```

---

## TEST FLOW 2 : EMPRUNTER (Type: loan)

### Étape 1-2 : Même que PRÊTER
```
✓ HOME PAGE
✓ (+) Button → Bottom Sheet
```

### Étape 3 : Tapper sur EMPRUNTER
```
✓ AddLoanPage s'ouvre
✓ Title : "NOUVEL EMPRUNT"
✓ Subtitle : "Je reçois de l'argent du client"
✓ Champs visibles :
  - Client dropdown
  - Montant
  - Échéance
  - Notes
  - Bouton "EMPRUNTER"
```

### Étape 4 : Remplir et soumettre
```
✓ Sélectionner un client
✓ Entrer montant : 30000
✓ Cliquer "EMPRUNTER"
✓ ATTENDRE 2-3 secondes
✓ VÉRIFIER Snackbar : "✓ Emprunt créé"
✓ REVENIR à HOME PAGE
```

### Étape 5 : Vérifier dans Dettes Tab
```
✓ Nouvel emprunt visible dans liste
✓ Montant : 30000 F
✓ Client : le nom choisi
✓ Status : à rembourser
```

### Étape 6 : Ouvrir DEBT DETAILS
```
✓ Cliquer sur l'emprunt créé
✓ DebtDetailsPage s'ouvre
✓ Title : "DÉTAILS DETTE"
✓ AppBar buttons :
  - Bouton +  avec tooltip "Emprunter plus"
  - Bouton 💳 avec tooltip "Rembourser"
```

### Étape 7 : Tester les boutons
```
✓ Cliquer Rembourser → AddPaymentPage s'ouvre
✓ Entrer montant, confirmer
✓ Revenir, montant payé mis à jour
```

---

## TEST FLOW 3 : COMPARAISON

### Scénario : Créer 1 PRÊT + 1 EMPRUNT pour même client

#### PRÊT (A)
```
Client : Ali
Type : debt (PRÊT)
Montant : 100000 F
Boutons : "Prêter plus" / "Encaisser"
```

#### EMPRUNT (B)
```
Client : Ali
Type : loan (EMPRUNT)
Montant : 50000 F
Boutons : "Emprunter plus" / "Rembourser"
```

### Vérifications
```
✓ Les deux dettes visibles dans tab DETTES
✓ Les boutons sont différents pour A et B
✓ Les actions (paiement/addition) fonctionnent pour chaque type
```

---

## 🔴 CAS D'ERREUR À TESTER

### Test 1 : Aucun client
```
✓ Cliquer (+)
✓ Sélectionner PRÊTER (ou EMPRUNTER)
✓ Dialog : "Aucun client trouvé"
✓ Option "Ajouter client"
✓ Créer client, revenir
✓ Recommencer prêt → OK
```

### Test 2 : Montant invalide
```
✓ Laisser montant vide
✓ Cliquer PRÊTER
✓ Validation error : "Montant invalide"
✓ Remplir montant → OK
```

### Test 3 : Pas de client sélectionné
```
✓ Remplir montant
✓ Cliquer PRÊTER sans sélectionner client
✓ Error ou warning approprié
```

---

## 📊 RÉSULTATS ATTENDUS

| Étape | Résultat | Status |
|-------|----------|--------|
| Bottom sheet affiche | 2 boutons clairs | ✅ Pass |
| Prêt créé | type:'debt' en DB | ✅ Pass |
| Emprunt créé | type:'loan' en DB | ✅ Pass |
| DebtDetails (Prêt) | Boutons "Prêter+", "Encaisser" | ✅ Pass |
| DebtDetails (Emprunt) | Boutons "Emprunter+", "Rembourser" | ✅ Pass |
| Snackbars | Message correct | ✅ Pass |
| Paiements | Fonctionne pour les deux | ✅ Pass |

---

## 📋 CHECKLIST POST-TEST

- [ ] Bottom sheet affiche et fonctionne
- [ ] PRÊTER crée dette type:'debt'
- [ ] EMPRUNTER crée dette type:'loan'
- [ ] Boutons dynamiques dans DebtDetails
- [ ] Snackbars affichent bon message
- [ ] Paiements fonctionnent pour les deux
- [ ] Ajout de montants fonctionne
- [ ] Aucun crash ou erreur

---

## 🐛 DEBUGGING

Si problème détecté :

1. **Vérifier logs Flutter**
   ```bash
   flutter logs
   ```

2. **Vérifier API responses**
   - Ouvrir DevTools
   - Vérifier payload POST
   - Vérifier type field en response

3. **Vérifier base de données**
   ```sql
   SELECT id, client_id, amount, type FROM debts;
   ```

4. **Redémarrer app**
   ```bash
   flutter clean
   flutter run
   ```

---

## 📞 CONTACT SUPPORT

Pour questions ou bugs :
1. Vérifier documentation
2. Consulter logs
3. Créer issue GitHub
4. Contacter développeur

---

**Test Date:** ______________
**Tester:** ______________
**Result:** ✅ PASS / ❌ FAIL

**Notes:**
_________________________________
_________________________________
_________________________________

---

**Status:** Ready for Testing
