# 🔧 TROUBLESHOOTING - Build Gradle Corrompu

## ❌ Problème Rencontré

```
FAILURE: Build failed with an exception

* Where:
Settings file 'android/settings.gradle.kts' line: 20
* What went wrong:
Error resolving plugin [id: 'dev.flutter.flutter-plugin-loader', version: '1.0.0']
> Could not read workspace metadata from C:\Users\bmd-tech\.gradle\caches\8.14\
kotlin-dsl\accessors\56dbf8fcbc33ac62f02ddb82fe49ce4d\metadata.bin
```

**Cause**: Cache Gradle corrompu lors de la première build

---

## ✅ SOLUTION

### Option 1: Script Automatique (Recommandé)

Exécutez le script PowerShell créé:

```powershell
# Ouvrir PowerShell en tant qu'administrateur
cd c:\Users\bmd-tech\Desktop\Boutique
.\rebuild.ps1
```

Cela va:
1. ✅ Supprimer complètement `~/.gradle`
2. ✅ Exécuter `flutter clean`
3. ✅ Réinstaller les dépendances
4. ✅ Relancer `flutter build appbundle --release`

**Temps estimé**: 15-20 minutes

---

### Option 2: Manuel (Si le script échoue)

```powershell
# 1. Arrêter tous les processus Java
taskkill /F /IM java.exe

# 2. Supprimer le cache Gradle
Remove-Item "$env:USERPROFILE\.gradle" -Recurse -Force -ErrorAction SilentlyContinue

# 3. Aller dans le dossier mobile
cd 'c:\Users\bmd-tech\Desktop\Boutique\mobile'

# 4. Nettoyage Flutter
flutter clean

# 5. Réinstaller les dépendances
flutter pub get

# 6. Rebuild
flutter build appbundle --release
```

---

## 📍 Vérifier le Succès

Après la build, vérifiez que le fichier existe:

```powershell
Test-Path 'c:\Users\bmd-tech\Desktop\Boutique\mobile\build\app\outputs\bundle\release\app-release.aab'
```

**Résultat attendu**: `True` + fichier de ~40-50MB

---

## 🎯 Prochaines Étapes (Après Build Réussi)

1. **Configurer Firebase**:
   ```bash
   flutterfire configure
   ```

2. **Créer Google Play Developer Account** (si pas fait)

3. **Uploader l'AAB**:
   - Aller dans Google Play Console
   - Créer une nouvelle app
   - Uploader `app-release.aab`
   - Attendre la revue (2-3 jours)

4. **Publier!** 🚀

---

## 💡 Conseils

- **Temps de build**: 15-20 min (normal pour première build)
- **RAM nécessaire**: Minimum 8GB
- **Disque**: Minimum 20GB libre
- **Internet**: Stable (télécharge 500MB+ de dépendances)

---

## 🔗 Resources

- [Flutter Troubleshooting](https://flutter.dev/docs/testing/troubleshooting)
- [Gradle Cache Issues](https://docs.gradle.org/current/userguide/build_cache.html)
- [Google Play Store Submission](https://support.google.com/googleplay/android-developer)

---

**Status**: 🔄 En attente de rebuild manuel

**Next**: Exécutez `.\rebuild.ps1` et attendez la complétion
