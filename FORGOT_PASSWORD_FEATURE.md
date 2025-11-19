# Fonctionnalité Mot de Passe Oublié

## Vue d'ensemble
La fonctionnalité "Mot de passe oublié" a été implémentée pour permettre aux utilisateurs de récupérer l'accès à leur compte en répondant à une question secrète qu'ils ont définie lors de l'inscription.

## Flux utilisateur

### 1. Inscription (RegisterPage)
L'utilisateur doit maintenant définir une question secrète personnalisée et une réponse lors de l'inscription:
- **Question secrète**: Texte libre (ex: "Nom de votre premier animal?")
- **Réponse secrète**: Réponse personnalisée (ex: "Rex")

### 2. Connexion (LoginPage)
Un nouveau lien "Mot de passe oublié?" a été ajouté sous le bouton de connexion.

### 3. Récupération du mot de passe (ForgotPasswordPage)
1. L'utilisateur entre son **numéro de téléphone**
2. Il clique sur **"Continuer"**
3. Le backend récupère sa question secrète (GET `/api/auth/forgot-password/:phone`)
4. La question s'affiche à l'écran
5. L'utilisateur entre sa **réponse secrète**
6. L'utilisateur entre son **nouveau mot de passe**
7. Il clique sur **"Réinitialiser le mot de passe"**
8. Si la réponse est correcte, le mot de passe est réinitialisé (POST `/api/auth/reset-password`)

## Modifications du code

### Frontend (mobile/lib/login_page.dart)

#### Classe RegisterPage (_RegisterPageState)
- ✅ Ajout de `securityQuestionCtl` TextEditingController
- ✅ Ajout de `securityAnswerCtl` TextEditingController
- ✅ Nouveaux champs TextField pour question et réponse
- ✅ Modification de `doRegister()` pour envoyer les données au backend

#### Classe LoginPage (_LoginPageState)
- ✅ Ajout du lien "Mot de passe oublié?" 
- ✅ Navigation vers ForgotPasswordPage

#### Classe ForgotPasswordPage (nouvelle)
- ✅ Champ pour le numéro de téléphone
- ✅ Bouton pour récupérer la question secrète
- ✅ Affichage de la question secrète
- ✅ Champ pour l'entrée de la réponse
- ✅ Champ pour le nouveau mot de passe
- ✅ Bouton pour réinitialiser le mot de passe
- ✅ Appels API sécurisés avec gestion d'erreurs

### Backend (backend/routes/auth.js)

#### Endpoint: GET `/api/auth/forgot-password/:phone`
```javascript
// Récupère la question secrète d'un utilisateur
- Input: phone number (URL param)
- Output: { security_question: "..." }
- Erreurs: 404 si utilisateur non trouvé, 400 si pas de question définie
```

#### Endpoint: POST `/api/auth/reset-password`
```javascript
// Réinitialise le mot de passe après vérification de la réponse
- Input: { phone, security_answer, new_password }
- Output: { success: true, message: "...", user: {...} }
- Processus:
  1. Vérifie que l'utilisateur existe
  2. Compare la réponse avec le hash stocké (bcrypt.compare)
  3. Si match, hache le nouveau mot de passe
  4. Met à jour la base de données
```

### Base de données (backend/migrations/004_add_security_question.sql)

Ajout de deux colonnes à la table `owners`:
```sql
security_question VARCHAR(255) -- Question personnalisée
security_answer_hash VARCHAR(255) -- Réponse hachée (bcrypt)
```

## Sécurité

✅ **Réponse secrète hachée**: Les réponses sont hachées avec bcrypt (même que les mots de passe)
✅ **Nouveau mot de passe haché**: Le mot de passe est également haché avant stockage
✅ **Comparaison sécurisée**: Utilisation de `bcrypt.compare()` pour éviter les attaques timing
✅ **Validation entrée**: Trimmed et lowercased les réponses avant comparaison
✅ **Gestion des erreurs**: Messages d'erreur génériques pour éviter les fuites d'information

## Endpoints API

| Méthode | Route | Description | Auth |
|---------|-------|-------------|------|
| GET | `/api/auth/forgot-password/:phone` | Récupérer la question secrète | Non |
| POST | `/api/auth/reset-password` | Réinitialiser le mot de passe | Non |

## Données stockées

Pour chaque utilisateur (`owners` table):
- `security_question`: VARCHAR(255) - Question personnalisée
- `security_answer_hash`: VARCHAR(255) - Hash bcrypt de la réponse

## Tests recommandés

1. **Test inscription avec question secrète**
   - Vérifier que la question et la réponse sont stockées en base
   - Vérifier que la réponse est hachée (pas en plaintext)

2. **Test récupération de mot de passe**
   - Entrer un numéro valide → voir la question
   - Entrer une mauvaise réponse → recevoir une erreur
   - Entrer la bonne réponse → réinitialiser le mot de passe
   - Se reconnecter avec le nouveau mot de passe

3. **Test sécurité**
   - Vérifier que les réponses ne sont pas visibles en plaintext
   - Vérifier qu'on ne peut pas remettre à zéro le mot de passe sans la bonne réponse

## Prochaines améliorations (optionnel)

- [ ] Support de plusieurs questions secrètes
- [ ] Limite de tentatives pour entrer la réponse
- [ ] Email ou SMS de confirmation avant réinitialisation
- [ ] Histórique des changements de mot de passe
- [ ] Option "se souvenir de cet appareil" après reset
