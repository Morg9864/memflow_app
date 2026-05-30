<p align="center">
  <img src="memflow.png" alt="MemFlow icon" width="88" />
</p>

<h1 align="center">MemFlow</h1>

<p align="center">
  Application de flashcards Flutter offline-first pour le web et le mobile.
  <br />
  Révision espacée, modes d'étude variés, import CSV et synchronisation cloud optionnelle.
</p>

<p align="center">
  <img src="design/C%20_%20Greeting%20_%20masonry.png" alt="Écran d'accueil MemFlow" width="320" />
</p>

<p align="center">
  <code>Flutter</code>
  <code>Riverpod</code>
  <code>Drift + SQLite</code>
  <code>go_router</code>
  <code>Supabase</code>
</p>

## Aperçu

MemFlow est une application de révision pensée pour rester fluide sans connexion et agréable à utiliser sur mobile comme sur le web. La base locale est la source de vérité, puis la synchronisation cloud vient en option quand Supabase est configuré.

> Local-first par défaut. Sync seulement si vous en avez besoin.

## Points forts

- `Offline-first` avec persistance locale via Drift et SQLite.
- `Spaced repetition` pour prioriser les cartes à revoir au bon moment.
- `Plusieurs modes d'étude` : QCM, flashcards classiques/inversées, texte à trous, saisie libre, vrai/faux.
- `Organisation par collections et decks` pour structurer les révisions.
- `Import / export CSV` pour alimenter rapidement vos jeux de cartes.
- `Statistiques de progression` pour suivre la série, le taux de réussite et l'activité.
- `Thèmes clair et sombre` avec une UI cohérente sur tous les écrans.

## Interface

<table>
  <tr>
    <td align="center">
      <img src="design/C%20_%20Greeting%20_%20masonry.png" alt="Accueil" width="210" /><br />
      <sub>Accueil</sub>
    </td>
    <td align="center">
      <img src="design/02%20_%20Collection%20detail.png" alt="Détail d'une collection" width="210" /><br />
      <sub>Collection & decks</sub>
    </td>
    <td align="center">
      <img src="design/QCM%20_%20choix%20unique.png" alt="Mode QCM" width="210" /><br />
      <sub>Mode QCM</sub>
    </td>
  </tr>
  <tr>
    <td align="center">
      <img src="design/Light%20_%20Study%20_back_.png" alt="Flashcard avec réponse révélée" width="210" /><br />
      <sub>Flashcard révélée</sub>
    </td>
    <td align="center">
      <img src="design/Texte%20_%20trous.png" alt="Mode texte à trous" width="210" /><br />
      <sub>Texte à trous</sub>
    </td>
    <td align="center">
      <img src="design/05%20_%20Statistics.png" alt="Écran de statistiques" width="210" /><br />
      <sub>Statistiques</sub>
    </td>
  </tr>
</table>

## Stack technique

- `Flutter` + `Dart`
- `flutter_riverpod` pour l'état et l'injection de dépendances
- `go_router` pour la navigation
- `Drift` + `SQLite` pour la base locale
- `Supabase` pour la synchronisation cloud optionnelle
- `shared_preferences` pour les préférences légères
- `file_picker` + `csv` pour l'import/export

## Démarrage rapide

### Prérequis

- Flutter SDK stable
- Dart SDK inclus avec Flutter
- Android Studio et/ou Xcode pour les cibles mobiles
- Un navigateur moderne pour le web

Vérifiez votre environnement :

```bash
flutter doctor
```

### Installation

```bash
flutter pub get
```

### Lancer l'application

Web :

```bash
flutter run -d chrome --dart-define-from-file=.env
```

Android / iOS :

```bash
flutter run --dart-define-from-file=.env
```

## Synchronisation Supabase (optionnelle)

Sans variables Supabase, l'application reste pleinement utilisable en local.

Variables attendues :

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

Étapes :

1. Copier `.env.example` vers `.env`
2. Renseigner les variables de votre projet Supabase
3. Appliquer le schéma SQL situé dans `supabase/migrations/20260529183000_init_memflow.sql`
4. Lancer l'application avec `--dart-define-from-file=.env`

Exemple :

```bash
flutter run -d chrome --dart-define-from-file=.env
```

Les valeurs sont lues au bootstrap avec `String.fromEnvironment(...)`.

## Structure du projet

Le projet suit une organisation feature-first avec une séparation claire entre UI, domaine et persistance :

```text
lib/
  app/        bootstrap, routeur, providers
  data/       base locale, connexions, repositories
  domain/     modèles et services métier
  features/   home, collections, study, import, stats, profile
  theme/      thèmes et contrôleur d'apparence
  widgets/    composants UI réutilisables
```

## Génération Drift

Si vous modifiez le schéma Drift, regénérez les fichiers :

```bash
dart run build_runner build --delete-conflicting-outputs
```

Mode watch :

```bash
dart run build_runner watch --delete-conflicting-outputs
```

## Tests

Lancer toute la suite :

```bash
flutter test
```

Tests ciblés :

```bash
flutter test test/services/spaced_repetition_service_test.dart
flutter test test/services/card_mode_service_test.dart
flutter test test/services/sync_service_test.dart
```

## Build

Web :

[Lien vers le site web](https://www.memflow.one)

Android :

```bash
flutter build apk --debug --dart-define-from-file=.env
```

iOS :

```bash
flutter build ios --debug --dart-define-from-file=.env
```

## Commandes utiles

```bash
flutter analyze
flutter test
flutter clean
flutter pub get
```

## Licence

MIT License - voir le fichier [LICENSE](LICENSE) pour plus de détails.