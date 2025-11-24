# 🌐 URLs Obligatoires pour Publication

## À Publier sur votre Site Web

Ces URLs sont **obligatoires** pour Google Play et App Store.

### 1️⃣ Privacy Policy
**URL:** `https://boutique.example.com/privacy-policy`

Fichier fourni: `PRIVACY_POLICY.md`
- Adaptes les informations générales
- Remplace `support@boutique.example.com` par votre email
- Remplace `https://boutique.example.com` par votre domaine
- Doit être **HTTP (i.e., https://)**

### 2️⃣ Terms of Service (Conditions d'Utilisation)
**URL:** `https://boutique.example.com/terms`

Fichier fourni: `TERMS_OF_SERVICE.md`
- Vérifie les sections légales applicables
- Remplace emails et contacts
- Recommandé mais pas obligatoire pour Google Play
- Obligatoire pour App Store

### 3️⃣ Support/Contact
**URL:** `https://boutique.example.com/support`

Contenu suggeré:
```html
<h1>Support Boutique</h1>

<h2>Contactez-nous</h2>
<p>Email: support@boutique.example.com</p>
<p>Heures: Lundi-Vendredi, 9h-18h</p>

<h2>FAQ</h2>
<ul>
  <li>Comment créer un compte?</li>
  <li>Comment ajouter une dette?</li>
  <li>Comment synchroniser?</li>
  <li>Mes données sont-elles sécurisées?</li>
</ul>
```

---

## Template Site Simple

Si vous n'avez pas encore de site, voici un template minimal:

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width">
    <title>Boutique - App Gestion de Dettes</title>
    <style>
        body { font-family: sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
        a { color: #7C3AED; }
    </style>
</head>
<body>
    <h1>🏪 Boutique</h1>
    <p>Application de gestion de dettes pour petits commerces</p>
    
    <h2>Télécharger</h2>
    <a href="https://play.google.com/store/apps/details?id=com.mnllmnd.boutique">
        Google Play Store
    </a>
    |
    <a href="https://apps.apple.com/app/boutique/id000000000">
        App Store
    </a>
    
    <h2>Navigation</h2>
    <ul>
        <li><a href="/privacy-policy">Privacy Policy</a></li>
        <li><a href="/terms">Terms of Service</a></li>
        <li><a href="/support">Support</a></li>
    </ul>
    
    <footer>
        <p>&copy; 2025 Boutique. <a href="mailto:support@boutique.example.com">Contact</a></p>
    </footer>
</body>
</html>
```

---

## Où Héberger?

### Options Gratuites
- **GitHub Pages** - `https://mnllmnd.github.io/boutique`
- **Netlify** - `https://boutique.netlify.app`
- **Vercel** - `https://boutique.vercel.app`

### Options Payantes
- **Domain Name** - `boutique.app` (~$10-50/an)
- **Web Hosting** - OVH, Hostinger (~$3-5/mo)

---

## Template GitHub Pages

Si utilisant GitHub:

1. Créer repo `boutique-website`
2. Créer fichier `docs/index.html`
3. Aller à Settings → Pages
4. Choisir source: `docs`
5. URL automatique: `https://mnllmnd.github.io/boutique-website`

---

## Checklist Publication d'URL

- [ ] Privacy Policy en ligne et accessible
- [ ] Terms of Service en ligne et accessible
- [ ] Email support valide et actif
- [ ] URLs HTTPS (pas HTTP)
- [ ] Pas de 404 errors
- [ ] Contenu lisible sur mobile

---

## Exemples d'URL Finales

```
Privacy Policy:
https://boutique.example.com/privacy-policy
OU
https://boutique-app.com/legal/privacy

Terms of Service:
https://boutique.example.com/terms
OU
https://boutique-app.com/legal/terms

Support:
https://boutique.example.com/support
OU
https://support.boutique.example.com
```

---

**Note:** Ces URLs seront vérifiées par les reviewers de Google et Apple.
Assurez-vous qu'elles sont accessibles et à jour!
