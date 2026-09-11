Tu es un senior Flutter developer et UI engineer. Je veux que tu construises une application Flutter complète à partir des screenshots joints.

L’app s’appelle MemFlow. C’est une application Flutter Web/Mobile (mobile/tablette + web) de flashcards avec révision espacée, collections, decks, statistiques, import CSV et synchronisation cloud offline-first.

Analyse très attentivement les images fournies et reproduis le design aussi fidèlement que possible : couleurs, espacements, typographies, cartes, arrondis, hiérarchie visuelle, mode clair et mode sombre, boutons, progress bars, bottom navigation, layout tablette/mobile.

Objectif final : produire un projet Flutter complet, propre, maintenable, compilable, avec une architecture claire, des données locales persistantes et une synchronisation cloud fiable.

---

## 1. Stack technique demandée

Utilise Flutter avec Dart.

Contraintes :

- App Flutter Web + Mobile (Android/iOS + Web), avec UX mobile-first et responsive tablette.
- UI custom, pas une simple app Material standard.
- Utiliser Material 3 uniquement comme base technique, mais le design doit être custom.
- Utiliser une architecture propre :
    - models/
    - services/
    - repositories/
    - providers/ ou controllers/
    - screens/
    - widgets/
    - theme/
    - utils/
- Utiliser Riverpod pour l’état.
- Utiliser go_router pour la navigation.
- Utiliser Drift + SQLite pour la persistance locale (mode hors-ligne robuste).
- Pour Flutter Web, utiliser la variante SQLite compatible web (ex : sqlite3 WASM via Drift) afin de conserver le même modèle de persistance offline-first.
- Utiliser Supabase pour la couche cloud (stockage des données applicatives et synchronisation multi-device).
- Implémenter une synchronisation offline-first entre Drift (local) et Supabase (cloud) :
    - lecture prioritaire en local,
    - file d’opérations locales en attente de sync,
    - tentative de push/pull au retour réseau,
    - stratégie de résolution de conflit simple et explicite (ex : latest `updatedAt` wins).
- Utiliser shared_preferences uniquement pour les petits réglages comme le thème.
- Prévoir un système de thème clair/sombre.
- Ajouter des tests unitaires pour la logique de révision espacée.
- Ajouter des tests unitaires pour la logique d’évolution des modes de test (`CardModeService`).
- Ajouter des tests unitaires de la logique de synchronisation (mapping local/cloud, détection des changements, conflits basiques).

L’app doit rester pleinement utilisable hors-ligne, puis se synchroniser automatiquement avec le cloud quand une connexion est disponible.

---

## 2. Identité visuelle générale

L’app a un style chaleureux, minimaliste, premium, calme, type study app.

Inspiration visuelle :

- Fond principal crème très clair.
- Cartes blanches ou beige clair.
- Accent orange chaud.
- Texte principal très foncé, presque noir.
- Bordures fines beige/gris clair.
- Gros arrondis.
- Beaucoup d’espace blanc.
- UI douce, presque papier.
- Typographie élégante pour les titres, plus lisible pour les labels.

Palette approximative :

- Background light : #FAF7F1 ou #FBF8F3
- Surface : #FFFFFF
- Surface soft : #F7EFE7
- Border : #E7DED3
- Text primary : #1E1715
- Text secondary : #7C6C61
- Accent orange : #E8792F
- Accent orange dark : #C95F22
- Accent orange soft : #FCE9DC
- Red soft : #FBE7E4
- Red text : #D94A3A
- Green soft : #EAF3E7
- Green text : #4D9461
- Blue soft : #EAF0F3
- Blue text : #4D79B5

Mode sombre :

- Background : #130E0B
- Surface : #21170F
- Surface elevated : #2B1D13
- Border : #3E3027
- Text primary : #F6EFE8
- Text secondary : #B9A99B
- Accent orange : #F59B55
- Cards sombres avec teinte chaude.

Typographies :

- Titres principaux : police serif élégante, par exemple Playfair Display, Cormorant Garamond ou équivalent.
- Texte UI, labels, petits textes : Inter, DM Sans ou équivalent.
- Les grands titres doivent avoir un rendu très proche des screenshots.
- Les labels doivent souvent être en uppercase avec letter spacing.

Coins arrondis :

- Petites icônes : 12 à 16 px
- Cards : 20 à 28 px
- Gros boutons : 18 à 22 px
- Cadres principaux : 28 px

Animations :

- Transitions douces de 150 à 250 ms.
- Animation sur la révélation d’une carte.
- Feedback visuel quand on sélectionne une réponse.
- Progress bars animées.
- Changement de thème animé si possible.

---

## 3. Données et modèles

Créer les modèles suivants :

### Collection

Champs :

- id
- name
- description
- icon
- totalCards
- masteredPercentage
- color
- createdAt
- updatedAt

Exemples :

- React & Hooks
- Python
- Algorithmes
- SQL & BDD
- HTTP & Réseaux

### Deck

Champs :

- id
- collectionId
- name
- difficulty : facile, moyen, avancé
- totalCards
- dueCards
- progress
- status : nouveau, maîtrisé, dues
- createdAt
- updatedAt

Exemples pour React & Hooks :

- Hooks de base : 24 cartes, facile, maîtrisé
- Gestion d’état : 18 cartes, moyen, 5 dues
- Cycle de vie : 14 cartes, moyen, nouveau
- Context API : 12 cartes, avancé, 3 dues
- Performance & memo : 16 cartes, avancé, nouveau
- Routing avec React Router : 14 cartes, moyen, nouveau

### Flashcard

Champs :

- id
- collectionId
- deckId
- question
- correctAnswer
- answer (optionnel, alias rétrocompatible de correctAnswer)
- wrongAnswer1
- wrongAnswer2
- wrongAnswer3
- hint
- explanation
- currentTestMode
- allowedTestModes
- lastTestMode
- modeHistory
- clozeText
- acceptedAnswers
- source
- difficulty
- level
- tags
- dueAt
- lastReviewedAt
- intervalDays
- easeFactor
- repetitions
- lapses
- mastered
- createdAt
- updatedAt

Créer un enum `TestMode` avec au minimum :

- multipleChoice (QCM à 4 réponses, réponse unique)
- classicFlashcard (question puis réponse révélée)
- reversedFlashcard (réponse vers question/concept)
- cloze (texte à trous)
- freeText (saisie libre)
- trueFalse (vrai/faux)
- ordering (optionnel)
- matching (optionnel)

Règles de base :

- Le premier mode d’une carte doit toujours être `multipleChoice`.
- Les trois fausses réponses sont obligatoires pour valider une carte importée ou mockée.
- `allowedTestModes` dépend des données disponibles (ex : `cloze` seulement si `clozeText` est renseigné ; `freeText` seulement si `acceptedAnswers` est renseigné).

Levels :

- Niveau 1 : Basique.
- Niveau 2 : Intermédiaire.
- Niveau 3 : Actif.
- Niveau 4 : Avancé.

Note : le niveau pédagogique et le mode de test sont distincts. Le niveau exprime la difficulté globale ; le mode exprime l’interaction utilisateur lors de la révision.

Exemple de carte :
Question :
Quel hook React permet d’exécuter un effet de bord après le rendu ?

Réponse :
useEffect, il s’exécute après que le DOM soit mis à jour. Le tableau de dépendances contrôle quand l’effet se relance.

Hint :
Un tableau vide [] fait que l’effet ne s’exécute qu’une seule fois, au montage.

### ReviewResult

Valeurs :

- again : Encore, je ne savais pas
- hard : Difficile, avec effort
- good : Correct, je savais
- easy : Facile, trop simple

### Services métier dédiés

Créer deux services distincts :

- `SpacedRepetitionService` : décide quand la carte revient (`dueAt`, `intervalDays`, `easeFactor`, etc.).
- `CardModeService` (ou `TestModeService`) : décide comment la carte est testée (`currentTestMode`) selon l’historique et la note.

Ces deux logiques doivent rester séparées.

---

## 4. Logique de révision espacée

Implémenter une logique simple de spaced repetition.

Quand l’utilisateur note une carte :

### Again

- lapses + 1
- repetitions = 0
- intervalDays = 0
- dueAt = maintenant + 10 minutes
- mastered = false

### Hard

- repetitions + 1
- intervalDays = max(1, intervalDays \* 1.2)
- easeFactor baisse légèrement
- dueAt = maintenant + intervalDays

### Good

- repetitions + 1
- intervalDays :
    - si première réussite : 1 jour
    - deuxième réussite : 3 jours
    - ensuite : intervalDays \* easeFactor
- easeFactor stable
- dueAt = maintenant + intervalDays

### Easy

- repetitions + 1
- intervalDays :
    - si première réussite : 4 jours
    - ensuite : intervalDays _ easeFactor _ 1.4
- easeFactor augmente légèrement
- dueAt = maintenant + intervalDays
- mastered = true si repetitions >= 3 et easeFactor élevé

Les stats doivent se mettre à jour automatiquement.

### Logique des modes de test (évolutive)

Le mode de test initial d’une carte est toujours `multipleChoice`.

Pour une carte en mode QCM (`multipleChoice`) :

- Afficher la question.
- Afficher l’indice si disponible.
- Afficher 4 propositions (1 correcte + 3 fausses).
- Mélanger automatiquement l’ordre des propositions.
- N’autoriser qu’une seule sélection.
- Après validation : afficher correct/incorrect, la bonne réponse, puis l’explication si elle existe.
- Afficher ensuite les boutons de note : Encore, Difficile, Correct, Facile.

Pré-suggestion de note (modifiable par l’utilisateur) :

- Réponse QCM incorrecte : pré-suggérer `again`.
- Réponse QCM correcte : pré-suggérer `good`.

Évolution du mode selon la note (gérée par `CardModeService`) :

Again

- La carte reste en `multipleChoice` ou y revient.
- Objectif : renforcer la reconnaissance de base.

Hard

- La carte peut rester en `multipleChoice` ou passer en `classicFlashcard`.
- Objectif : réduire progressivement le guidage sans le supprimer.

Good

- La carte peut passer en `classicFlashcard`.
- Si réussites répétées : possibilité de passer en `reversedFlashcard`.

Easy

- La carte passe vers un mode plus actif quand possible :
    - `reversedFlashcard`
    - `cloze` si `clozeText` existe
    - `freeText` si `acceptedAnswers` existe
- Objectif : augmenter la difficulté cognitive progressivement.

Important :

- `SpacedRepetitionService` décide le timing de réapparition.
- `CardModeService` décide le mode de test suivant.
- Les deux décisions sont appliquées après chaque révision.

---

## 5. Écrans à construire

### A. Home screen

Reproduire l’écran d’accueil visible dans les screenshots.

Contenu :

- Logo MemFlow en haut à gauche.
    - “Mem” en noir.
    - “Flow” en orange.
- Deux boutons en haut à droite :
    - notifications
    - statistiques ou activité
- Message :
    - BONJOUR, Morgan
    - 12 cartes t’attendent ce matin.
    - Le nombre doit être dynamique selon les cartes dues.
- Barre de recherche.
- Trois cards statistiques :
    - 14j de série
    - 87% réussite
    - 12 à revoir
- Section Collections.
- Une grande carte mise en avant “React & Hooks”.
- Ensuite une grille 2 colonnes de collections :
    - Python
    - Algorithmes
    - SQL & BDD
    - HTTP & Réseaux
- Chaque carte contient :
    - icône
    - titre
    - nombre de cartes
    - progress bar
- Bottom navigation fixe :
    - Accueil
    - Stats
    - Importer
    - Profil

Interaction :

- Tap sur une collection ouvre CollectionDetailScreen.
- Recherche filtre les collections.
- Le thème clair/sombre est accessible via un bouton ou via profil.

---

### B. Collection detail screen

Reproduire l’écran “React & Hooks”.

Contenu :

- Bouton retour.
- Bouton thème en haut à droite.
- Icône collection React.
- Titre : React & Hooks.
- Sous-titre : Maîtriser l’écosystème React moderne.
- Trois stats :
    - 98 cartes
    - 42% maîtrise
    - 6 dues
- Section Decks avec compteur “6 packs”.
- Liste de decks sous forme de cards horizontales.
- Chaque deck contient :
    - icône
    - nom
    - metadata : nombre de cartes + difficulté
    - petite progress bar
    - badge à droite :
        - Maîtrisé
        - Nouveau
        - 5 dues
        - 3 dues
    - chevron
- Bouton “Importer un CSV” sous la liste.
- Floating Action Button orange en bas à droite pour lancer la session de révision.

Interaction :

- Tap sur un deck ouvre une session de révision filtrée sur ce deck.
- FAB lance une session avec toutes les cartes dues de la collection.
- Import CSV ouvre ImportScreen.

---

### C. Study screen, face question

Reproduire l’écran minimal centré.

Contenu :

- Status bar simulée uniquement si nécessaire, sinon respecter SafeArea.
- Bouton fermer en haut à gauche.
- Titre du deck centré : Hooks de base.
- En haut :
    - progress bar horizontale orange.
    - compteur : 7/12.
- Badge niveau :
    - icône œil
    - Basique, Niv. 1
- Petits points de progression à droite.
- Au centre :
    - label QUESTION
    - grande question centrée.
    - astuce en italique.
- En bas :
    - indication “Glisse vers le haut”.
    - bouton principal orange “Révéler la réponse”.

Interactions :

- Tap sur “Révéler la réponse” affiche la réponse.
- Swipe up affiche aussi la réponse.
- Animation douce entre face question et face réponse.

---

### D. Study screen, face réponse

Reproduire l’écran avec grande carte blanche.

Contenu :

- Même header.
- Grande card blanche avec border.
- Dans la card :
    - label QUESTION
    - question
    - séparateur horizontal
    - label RÉPONSE
    - réponse en grand texte
    - décor cercle semi-transparent en haut à droite
- Sous la card :
    - label “COMMENT TU T’EN ES SORTI ?”
- Grille 2x2 de boutons de notation :
    - Encore
        - sous-texte : Je ne savais pas
        - fond rouge pâle
        - texte rouge
    - Difficile
        - sous-texte : Avec effort
        - fond orange pâle
        - texte orange
    - Correct
        - sous-texte : Je savais
        - fond vert pâle
        - texte vert
    - Facile
        - sous-texte : Trop simple
        - fond bleu/gris pâle
        - texte bleu
- Après tap sur une note :
    - enregistre la révision
    - passe à la carte suivante avec animation
    - met à jour progress bar et compteur
- À la fin de la session :
    - afficher un écran de résumé.

Important :

- Dans la version claire, le bouton “Correct” doit afficher “Correct”, pas “Je savais” comme titre.
- Le sous-texte reste “Je savais”.

---

### E. Study screen, dark mode

Créer le même écran de réponse en mode sombre.

Le rendu doit être proche du screenshot dark :

- Fond brun/noir.
- Card brun foncé.
- Texte crème.
- Accent orange lumineux.
- Boutons de notation sombres avec couleurs légèrement teintées.
- Progress bar et badges adaptés.

Le changement de thème doit conserver l’état de la session.

---

### F. Statistics screen

Reproduire l’écran “Statistiques”.

Contenu :

- Titre : Statistiques.
- Bouton thème en haut à droite.
- Trois cards stats :
    - 14 série
    - 2 184 cartes vues
    - 87% réussite
- Grande card :
    - titre : Activité, 4 dernières semaines.
    - texte à droite : 22 jours d’étude.
    - heatmap 4 semaines x 7 jours.
    - Colonnes : L, M, M, J, V, S, D.
    - Lignes : S1, S2, S3, S4.
    - Les cases actives sont orange.
    - Les cases inactives sont beige très clair.
- Section : Progression par niveau.
- Liste de niveaux :
    - Niv. 1, Basique, Fondations et reconnaissance, 142
    - Niv. 2, Intermédiaire, Compréhension guidée, 96
    - Niv. 3, Actif, Rappel actif et reformulation, 54
    - Niv. 4, Avancé, Maîtrise contextuelle, 28
- Chaque ligne a :
    - icône
    - titre
    - sous-titre
    - progress bar
    - nombre à droite

Les stats doivent venir des données locales, mais fournir des données mockées au départ.

---

### G. Import screen

Créer un écran d’import CSV cohérent avec le design.

Fonctions :

- Importer un fichier CSV.
- Ajouter un bouton explicite : “Télécharger le template CSV”.
- Accepter les séparateurs :
    - point-virgule ;
    - virgule ,
    - tabulation
- Accepter les fichiers avec ou sans header.
- Format recommandé :
  collection;deck;question;correct_answer;wrong_answer_1;wrong_answer_2;wrong_answer_3;hint;explanation;level;difficulty;tags;source;cloze_text;accepted_answers

Champs obligatoires :

- collection
- deck
- question
- correct_answer
- wrong_answer_1
- wrong_answer_2
- wrong_answer_3

Champs optionnels :

- hint
- explanation
- level
- difficulty
- tags
- source
- cloze_text
- accepted_answers

Si pas de header :

- colonne 1 : collection
- colonne 2 : deck
- colonne 3 : question
- colonne 4 : correct_answer
- colonne 5 : wrong_answer_1
- colonne 6 : wrong_answer_2
- colonne 7 : wrong_answer_3
- colonne 8 : hint optionnel
- colonne 9 : explanation optionnel
- colonne 10 : level optionnel
- colonne 11 : difficulty optionnel
- colonne 12 : tags optionnel
- colonne 13 : source optionnel
- colonne 14 : cloze_text optionnel
- colonne 15 : accepted_answers optionnel

Règles de parsing :

- `tags` accepte plusieurs tags séparés par `|`.
- `accepted_answers` accepte plusieurs réponses séparées par `|`.
- `cloze_text` peut suivre une syntaxe de trous comme `React utilise {{useEffect}} ...`.
- Si `cloze_text` est vide, ne pas activer `cloze` dans `allowedTestModes`.
- Si `accepted_answers` est vide, ne pas activer `freeText` dans `allowedTestModes`.
- Si une des 3 mauvaises réponses est absente, la ligne est invalide (premier mode obligatoire en QCM).

Afficher un preview avant import :

- nombre de cartes détectées
- lignes invalides
- erreurs précises par ligne
- collection cible
- deck cible
- erreurs éventuelles
- bouton confirmer l’import

Après confirmation :

- créer les collections/decks manquants si nécessaire
- créer les cartes
- revenir à la collection ou à l’accueil

Template CSV à générer/télécharger depuis l’app :

collection;deck;question;correct_answer;wrong_answer_1;wrong_answer_2;wrong_answer_3;hint;explanation;level;difficulty;tags;source;cloze_text;accepted_answers
React & Hooks;Hooks de base;Quel hook React permet d’exécuter un effet de bord après le rendu ?;useEffect;useState;useMemo;useCallback;Un tableau vide [] limite l’effet au montage.;useEffect s’exécute après le rendu et permet de gérer des effets de bord.;1;facile;react|hooks;Cours React;React utilise {{useEffect}} pour exécuter un effet de bord après le rendu.;useEffect|use effect
React & Hooks;Hooks de base;Quel hook permet de stocker un état local dans un composant ?;useState;useEffect;useRef;useReducer;Il retourne une valeur et une fonction de mise à jour.;useState permet de déclarer une donnée réactive locale au composant.;1;facile;react|state;Cours React;Le hook {{useState}} permet de stocker un état local.;useState|use state

---

### H. Profile screen

Créer un écran profil simple mais propre.

Contenu :

- Nom utilisateur : Morgan
- Objectif quotidien
- Thème clair/sombre/système
- Réinitialiser les données mockées
- Exporter les cartes en CSV
- Version app

### I. Modes d’étude dynamiques (important)

La session d’étude doit supporter plusieurs rendus selon `currentTestMode` :

- `multipleChoice` : écran QCM (question + 4 choix + correction + explication + notation).
- `classicFlashcard` : comportement question puis révélation de la réponse.
- `reversedFlashcard` : affichage inversé réponse -> rappel du concept/question.
- `cloze` : texte à trous interactif.
- `freeText` : saisie libre avec comparaison tolérante via `acceptedAnswers`.
- `trueFalse` : affirmation à valider/refuser.
- `ordering` et `matching` : optionnels, mais prévoir un fallback propre si non implémentés complètement.

Contraintes d’enchaînement :

- Toute première révision d’une carte commence en `multipleChoice`.
- Après notation, appliquer à la fois la mise à jour SRS et l’évolution de mode.
- Le thème clair/sombre ne doit jamais réinitialiser l’état de session ni le mode courant.

---

## 6. Composants réutilisables

Créer des widgets propres :

- AppScaffold
- BottomNavBar
- StatCard
- CollectionCard
- FeaturedCollectionCard
- DeckCard
- ProgressBar
- LevelBadge
- StudyProgressHeader
- FlashcardQuestionFace
- FlashcardAnswerFace
- MultipleChoiceCard
- McqOptionTile
- ModeSwitcher (interne/session)
- ReviewButton
- HeatmapGrid
- ThemeToggleButton
- CsvImportPreview
- EmptyState
- PrimaryButton
- IconTile

Les composants doivent être suffisamment génériques pour éviter la duplication.

---

## 7. Navigation

Routes :

- /
- /collection/:collectionId
- /study
- /study/:deckId
- /stats
- /import
- /profile
- /session-summary

Utiliser go_router.

La bottom navigation doit rester sur :

- Home
- Stats
- Import
- Profile

Pas de bottom navigation pendant la session d’étude.

---

## 8. Données mockées initiales

Au premier lancement, injecter des données mockées si la base locale est vide.

Créer au moins :

- 5 collections
- 6 decks pour React & Hooks
- 24 cartes dans Hooks de base
- quelques cartes dues
- quelques cartes maîtrisées
- des stats de révision sur 4 semaines

Les cartes mockées doivent inclure des données complètes :

- 1 bonne réponse + 3 mauvaises réponses
- hint
- explanation
- clozeText pour une partie des cartes
- acceptedAnswers pour une partie des cartes
- allowedTestModes calculés correctement
- currentTestMode initialisé à `multipleChoice`

Exemples de flashcards React :

1. Question : Quel hook React permet d’exécuter un effet de bord après le rendu ?
   Réponse : useEffect, il s’exécute après que le DOM soit mis à jour. Le tableau de dépendances contrôle quand l’effet se relance.
   Hint : Un tableau vide [] fait que l’effet ne s’exécute qu’une seule fois, au montage.

2. Question : Quel hook permet de stocker un état local dans un composant ?
   Réponse : useState permet de déclarer une valeur d’état et une fonction pour la modifier.

3. Question : À quoi sert useMemo ?
   Réponse : useMemo mémorise le résultat d’un calcul pour éviter de le recalculer inutilement.

4. Question : À quoi sert useCallback ?
   Réponse : useCallback mémorise une fonction entre deux rendus, souvent pour éviter des re-renders inutiles.

5. Question : Pourquoi ne faut-il pas appeler un hook dans une condition ?
   Réponse : React doit appeler les hooks dans le même ordre à chaque rendu pour associer correctement leur état interne.

Ajouter assez de cartes pour que l’interface ait de vraies données.

Important : toutes les premières révisions des cartes mockées démarrent en QCM.

---

## 9. Responsive design

L’app doit être belle :

- sur téléphone
- sur tablette
- en portrait principalement

Breakpoints :

- < 600 px : layout mobile une colonne
- 600 à 900 px : layout compact/tablette
- > 900 px : layout tablette proche des screenshots

Sur tablette :

- largeur max du contenu : environ 920 px
- centrer le contenu
- conserver les grands espacements
- éviter que les cards deviennent trop larges

Sur mobile :

- réduire les paddings
- les grilles 2 colonnes peuvent passer en 1 colonne si nécessaire
- préserver la lisibilité

---

## 10. Détails UI importants

Reproduire ces détails :

- Le fond n’est jamais blanc pur, il est crème.
- Les cards ont une bordure fine, très subtile.
- Les ombres sont très légères.
- L’accent orange est utilisé avec parcimonie.
- Les grands titres utilisent une police serif.
- Les labels sont en uppercase avec letter spacing.
- Les progress bars sont fines, arrondies, avec un track beige.
- Les icônes sont dans des petits carrés arrondis.
- Les boutons de review sont grands, calmes, colorés mais doux.
- Le bouton principal “Révéler la réponse” est orange plein, large, en bas.
- La study screen doit donner une impression très zen et concentrée.
- La version sombre ne doit pas être noire pure, mais brun/noir chaleureux.

---

## 11. Accessibilité

Ajouter :

- contrastes corrects
- tailles de texte lisibles
- semantics labels sur les boutons importants
- support du text scaling raisonnable
- boutons suffisamment grands pour le tactile

---

## 12. Qualité du code

Je veux du code propre et directement exploitable.

Règles :

- Pas de fichier énorme.
- Pas de logique métier dans les widgets.
- La logique de spaced repetition doit être dans un service séparé.
- Les repositories gèrent la persistance.
- Les widgets restent principalement déclaratifs.
- Les couleurs et styles doivent être centralisés.
- Ajouter des commentaires uniquement quand c’est utile.
- Ne pas créer une simple maquette statique : les interactions doivent fonctionner.
- Ne pas implémenter de backend custom : utiliser Supabase comme backend managé, avec une logique applicative majoritairement côté app.
- Ne pas laisser de TODO critique.

---

## 13. Écran de fin de session

À la fin d’une session :

- Afficher “Session terminée”.
- Résumé :
    - cartes vues
    - encore
    - difficile
    - correct
    - facile
    - taux de réussite
- Boutons :
    - Retour à la collection
    - Refaire une session
    - Accueil

Design cohérent avec le reste.

---

## 14. Ce que tu dois livrer

Génère directement le projet Flutter complet.

Je veux :

1. Le code complet.
2. La structure de fichiers.
3. Les dépendances à ajouter dans pubspec.yaml.
4. Les commandes pour lancer le projet.
5. Une courte explication de l’architecture.
6. Les éventuelles limites restantes, s’il y en a.

Important :

- Ne te contente pas d’un exemple minimal.
- Ne fais pas seulement une UI statique.
- Le projet doit compiler.
- L’app doit être utilisable avec les données mockées dès le premier lancement.
- Reproduis le design des screenshots le plus fidèlement possible.
- Si un détail manque, fais un choix cohérent avec le style visuel existant.
