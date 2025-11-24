# QUICK REFERENCE: PRÊTER/EMPRUNTER

## 🎯 CE QUI A CHANGÉ

### HOME PAGE
- **FAB Button** : Affiche bottom sheet avec 2 choix
  - ✅ PRÊTER (vert, flèche haut)
  - ✅ EMPRUNTER (bleu, flèche bas)

### ADD DEBT PAGE
- Titre : "NOUVEAU PRÊT" (au lieu de "NOUVELLE DETTE")
- Sous-titre : "Je sors de l'argent au client"
- Bouton : "PRÊTER" (au lieu de "CRÉER LA DETTE")
- Snackbar : "Prêt créé"
- **Type API** : `'type': 'debt'`

### ADD LOAN PAGE
- Titre : "NOUVEL EMPRUNT" ✅ (inchangé)
- Sous-titre : "Je reçois de l'argent du client" 
- Bouton : "EMPRUNTER" (au lieu de "CRÉER L'EMPRUNT")
- **Type API** : `'type': 'loan'` ✅ (déjà présent)

### DEBT DETAILS PAGE
- **Prêt** (type: 'debt')
  - Bouton +  → "Prêter plus"
  - Bouton 💳 → "Encaisser"
  
- **Emprunt** (type: 'loan')
  - Bouton +  → "Emprunter plus"
  - Bouton 💳 → "Rembourser"

---

## 📊 MATRICE DE DÉCISION

| Situation | Type | Boutons | Sens |
|-----------|------|---------|------|
| Je **donne** argent au client | `debt` | Encaisser / Prêter+ | ⬆️ Je sors argent |
| Je **reçois** argent du client | `loan` | Rembourser / Emprunter+ | ⬇️ Je reçois argent |

---

## 🔧 FICHIERS TOUCHÉS

```
mobile/lib/
├── main.dart                    ← _showAddChoice(), createLoan()
├── add_debt_page.dart          ← Textes "PRÊT", type:'debt'
├── add_loan_page.dart          ← Textes "EMPRUNT"
└── debt_details_page.dart      ← Labels dynamiques
```

---

## ✅ CHECKLIST VALIDATION

- [x] Bottom sheet affiche 2 options claires
- [x] PRÊTER lance AddDebtPage avec type:'debt'
- [x] EMPRUNTER lance AddLoanPage avec type:'loan'
- [x] Boutons dans DebtDetailsPage sont dynamiques
- [x] Snackbars affichent le bon message
- [x] Code compile sans erreurs critiques
- [x] Documentation complète

---

## 🚀 DÉPLOIEMENT

1. Push du code vers main
2. Tester les deux flows
3. Valider avec utilisateurs
4. Déployer vers production

---

## 📞 SUPPORT

Pour toute question sur l'implémentation :
- Voir `IMPLEMENTATION_PRETER_EMPRUNTER.md` (détails techniques)
- Voir `PRETER_EMPRUNTER_VISUAL_SUMMARY.md` (UI/UX)
- Voir ce fichier pour quick reference

---

**Last Updated:** 22 Novembre 2025
**Status:** ✅ Ready for Testing
