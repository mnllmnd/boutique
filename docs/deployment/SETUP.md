# Setup local (Windows, sans Docker)

## 1) Installer Postgres
- Téléchargez et installez PostgreSQL depuis https://www.postgresql.org/download/windows/ ou utilisez l'installateur graphique.
- Pendant l'installation, notez le `postgres` superuser password.

## 2) Créer l'utilisateur et la base (cmd.exe)
Ouvrez `cmd.exe` et utilisez l'utilitaire `psql` (ou lancez psql depuis le dossier d'installation) :

```cmd
REM se connecter en tant que superuser postgres
psql -U postgres

-- Dans psql:
CREATE USER boutique_user WITH PASSWORD 'boutique_pass';
CREATE DATABASE boutique_db OWNER boutique_user;
\q
```

## 3) Initialiser les tables
Depuis `cmd.exe` (remplacez le chemin si nécessaire) :

```cmd
psql -U boutique_user -d boutique_db -f "%CD%\\backend\\init.sql"
```

## 4) Backend Node.js
- Ouvrez un terminal dans `backend` :

```cmd
cd backend
npm install
```

- Copiez `.env.example` en `.env` et ajustez si besoin.
- Lancer le serveur :

```cmd
set PGHOST=localhost
set PGPORT=5432
set PGUSER=boutique_user
set PGPASSWORD=boutique_pass
set PGDATABASE=boutique_db
set PORT=3000

npm start
```

Le backend sera accessible sur `http://localhost:3000/api/debts`.

## 5) Mobile (Flutter)
- Installez Flutter SDK (https://docs.flutter.dev/get-started/install/windows) et configurez un émulateur Android ou utilisez `flutter run -d chrome` pour web.
- Dans le dossier `mobile` :

```cmd
cd mobile
flutter pub get
flutter run
```

Note: pour communiquer avec le backend local depuis un émulateur Android utilisez `http://10.0.2.2:3000` (déjà configuré dans l'exemple).

## 6) Commandes rapides (résumé)
- Initialiser DB: `psql -U boutique_user -d boutique_db -f "%CD%\\backend\\init.sql"`
- Lancer backend: `cd backend && npm install && set PGPASSWORD=boutique_pass && npm start`
- Lancer Flutter: `cd mobile && flutter pub get && flutter run`

---
Si vous voulez, je peux aussi :
- Exécuter `npm install` dans `backend` (si vous voulez que j'essaie ici).
- Ajouter des endpoints supplémentaires (modifier /pay, /balance, etc.).
- Committer les fichiers créés.
