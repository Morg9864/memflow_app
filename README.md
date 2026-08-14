<p align="center">
  <img src="memflow.png" alt="MemFlow icon" width="88" />
</p>

<h1 align="center">MemFlow</h1>

<p align="center">
  Application de flashcards Flutter offline-first pour le web et le mobile.
  <br />
  Révision espacée, modes d'étude adaptatifs, import CSV et synchronisation multi-appareils.
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

MemFlow est une application de révision pensée pour rester fluide sans connexion et agréable à utiliser sur mobile comme sur le web. La base locale SQLite fait foi pour tout ce qui est affiché ; Supabase fait foi entre appareils et se synchronise en arrière-plan.

> Local d'abord, toujours. Le réseau rattrape son retard tout seul.

## Points forts

- `Offline-first` : révisions, imports et suppressions fonctionnent sans réseau, puis se synchronisent seuls.
- `Modes adaptatifs` : chaque carte passe du QCM au rappel actif à mesure qu'elle est maîtrisée.
- `Spaced repetition` pour prioriser les cartes à revoir au bon moment.
- `Six modes d'étude` : QCM, flashcards classiques/inversées, texte à trous avec banque de mots, saisie libre, vrai/faux.
- `Organisation par collections et decks` pour structurer les révisions.
- `Import / export CSV` pour alimenter rapidement vos jeux de cartes.
- `Prompt IA intégré` dans l'écran d'import, consultable, copiable et téléchargeable.
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
- `Supabase` pour l'authentification et la synchronisation multi-appareils
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

## Configuration Supabase

Supabase porte l'authentification et la synchronisation entre appareils : les
deux variables sont requises au build. Une fois connecté, l'application
fonctionne hors ligne sur ses données locales.

Variables attendues :

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

Étapes :

1. Copier `.env.example` vers `.env`
2. Renseigner les variables de votre projet Supabase
3. Appliquer les migrations SQL du dossier `supabase/migrations/`, dans l'ordre
   des noms de fichiers
4. Lancer l'application avec `--dart-define-from-file=.env`

Exemple :

```bash
flutter run -d chrome --dart-define-from-file=.env
```

Les valeurs sont lues au bootstrap avec `String.fromEnvironment(...)`.

## Import CSV et prompt IA

L'écran `Importer` permet :

- d'importer un CSV MemFlow ;
- de télécharger un template CSV à jour ;
- de consulter le prompt IA complet utilisé pour générer des CSV ;
- de copier ce prompt dans le presse-papiers ;
- de télécharger ce prompt au format `.md`.

### Format CSV attendu

Colonnes recommandées :

```text
collection;deck;question;correct_answer;wrong_answer_1;wrong_answer_2;wrong_answer_3;hint;explanation;level;difficulty;tags;source;cloze_text;accepted_answers;cloze_answers;cloze_word_bank
```

Rappels importants :

- `accepted_answers` sert au mode `saisie libre`.
- `cloze_text` + `cloze_answers` + `cloze_word_bank` servent au vrai mode `texte à trous`.
- `cloze_text` utilise des trous au format `{{réponse}}`.
- `cloze_answers` contient les bonnes réponses dans l'ordre des trous, séparées par `|`.
- `cloze_word_bank` contient la banque de mots affichée à l'utilisateur, avec bonnes réponses et distracteurs.
- Un ancien CSV avec seulement `cloze_text` reste importable, mais n'active plus le mode `texte à trous` structuré.

Exemple :

```text
React & Hooks;Hooks de base;Quel hook React retourne une valeur et une fonction de mise à jour ?;useState;useEffect;useMemo;useRef;-;useState retourne une valeur actuelle et une fonction pour la modifier.;1;facile;react|hooks;Cours React;React, le hook {{useState}} retourne une valeur actuelle et une fonction pour la {{modifier}}.;useState|use state;useState|modifier;useState|useEffect|afficher|modifier
```

## Structure du projet

Le projet suit une organisation feature-first avec une séparation claire entre UI, domaine et persistance :

```text
lib/
  app/        bootstrap, routeur, providers
  data/       base locale Drift, moteur de synchronisation, repositories
  domain/     modèles et services métier
  features/   home, collections, study, import, stats, profile
  theme/      thèmes et contrôleur d'apparence
  widgets/    composants UI réutilisables
```

## Génération Drift

Si vous modifiez le schéma Drift, regénérez les fichiers :

```bash
dart run build_runner build
```

Mode watch :

```bash
dart run build_runner watch
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
flutter test test/services/csv_import_service_test.dart
flutter test test/features/study/study_screen_test.dart
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
