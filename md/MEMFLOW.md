# MemFlow — Référence complète

Document de référence décrivant tout ce qui compose MemFlow : le produit, ses
règles métier, son architecture, ses écrans, ses données et sa chaîne de build.

Le `README.md` reste le guide de démarrage rapide (installation, commandes).
Ce document-ci explique **ce que fait l'app et pourquoi**.

---

## 1. Ce qu'est MemFlow

Une application de flashcards à révision espacée, en français, écrite en Flutter
et déployée simultanément en web (memflow.one) et en mobile (Android / iOS).

Le principe produit : **l'utilisateur n'écrit pas ses cartes à la main**. Il
alimente l'app par import CSV — typiquement un CSV généré par une IA à partir de
son cours, via le prompt fourni dans l'app. MemFlow se charge ensuite de
l'organisation, du calendrier de révision et de la variation des modes
d'interrogation.

Trois niveaux de hiérarchie, du plus large au plus fin :

| Niveau | Rôle |
|---|---|
| **Collection** | Une matière (« Systèmes d'exploitation »). Porte une icône emoji et une couleur. |
| **Deck** | Un chapitre dans cette matière. Porte une difficulté. |
| **Flashcard** | Une question. Porte tout l'état de révision espacée. |

Les collections et les decks ne sont jamais créés à la main : ils naissent de
l'import CSV, appariés **par nom** (insensible à la casse). Réimporter un CSV
avec le même nom de collection alimente la collection existante.

---

## 2. Architecture

### Les couches

```
lib/
  app/        bootstrap, router, providers Riverpod, préférences persistées
  data/
    local/    schéma Drift et base SQLite (la source de vérité de l'affichage)
    sync/     moteur de synchronisation avec Supabase
    repositories/  requêtes métier au-dessus de la base locale
  domain/     modèles immuables et services métier purs
  features/   un dossier par écran/fonctionnalité
  theme/      thèmes et contrôleur d'apparence
  widgets/    composants UI partagés (ui.dart)
```

La règle de découpage : `domain/services/` ne contient que des fonctions pures,
testables sans Flutter ni base de données (répétition espacée, progression des
modes, parsing CSV). `data/sync/` est le seul endroit qui parle le dialecte
distant. `AppRepository` est la seule porte d'entrée des écrans : il ne connaît
que la base locale et la file de synchronisation. Tout ce qui touche à l'écran
vit dans `features/`.

### Le flux de données : offline-first

**La base locale SQLite fait foi pour tout ce qui est affiché. Supabase fait foi
entre appareils.** L'application ne consulte jamais le réseau pour peindre un
écran : elle lit sa base locale, et la synchronisation vit sa vie en arrière-plan.

Concrètement :

- **Lectures** — `AppRepository` interroge Drift. Les écrans s'abonnent à des
  `Stream` Drift, qui réémettent d'eux-mêmes dès qu'une table change. À ces flux
  s'ajoute une **horloge** qui tique chaque minute, pour que les compteurs
  « à revoir » basculent tout seuls quand une échéance est franchie sans
  qu'aucune donnée n'ait changé.
- **Écritures** — la ligne est écrite en local puis une intention est déposée
  dans la file de synchronisation, dans la même transaction. L'interface est à
  jour avant que le réseau ait été sollicité.
- **Synchronisation** — `SyncService` pousse la file puis rapatrie l'état
  distant, sur demande après chaque écriture, à intervalle régulier tant qu'il
  reste des envois en attente, et sur signal Realtime quand un autre appareil
  modifie quelque chose.

Hors ligne, tout continue : révisions, imports, suppressions. Les intentions
s'accumulent et partent à la reconnexion. Le profil affiche ce qui reste à
envoyer.

### Les règles de synchronisation

Elles tiennent en trois principes, tous dans `lib/data/sync/`.

**Une intention par entité, jamais de copie de la ligne.** Réviser dix fois la
même carte hors ligne ne produit qu'un seul envoi, et un `delete` remplace
naturellement un `upsert` pas encore parti. Le contenu envoyé est lu dans la
base locale **au moment du push**, pas au moment de la mise en file : une copie
figée divergerait dès la réécriture suivante.

**L'ordre des dépendances est respecté dans les deux sens.** Les créations
remontent des collections vers les cartes, les suppressions descendent dans
l'autre sens. Sans cela une clé étrangère distante casse le push.

**Une écriture locale non poussée est intouchable.** Au rapatriement, toute
ligne portant une intention en attente est ignorée ; pour les autres, la version
la plus récemment modifiée gagne. Ce qui a disparu côté distant disparaît côté
local, sauf ce qui est ainsi protégé — et les lignes devenues orphelines d'un
parent supprimé ailleurs sont nettoyées derrière.

Les journaux de révision échappent à cette réconciliation : ils ne sont jamais
modifiés, seulement ajoutés. Ils sont rapatriés à partir d'un curseur de date,
pas relus intégralement.

### La base locale appartient à un compte

Un seul compte à la fois. À la connexion, si la base porte les données d'un autre
utilisateur, elle est purgée avant toute chose. À la déconnexion, elle est
effacée : sur un appareil partagé, se déconnecter doit vraiment retirer ses
cartes de l'appareil.

L'app exige `SUPABASE_URL` et `SUPABASE_ANON_KEY` au build — l'authentification
en dépend. En revanche un démarrage **sans réseau** est toléré : la session est
restaurée depuis le stockage local et l'app s'ouvre sur ses données.

### Le multi-utilisateur

Chaque table porte une colonne `user_id` avec `default auth.uid()`, protégée par
une policy RLS `auth.uid() = user_id` pour le rôle `authenticated` uniquement.
Le rôle `anon` n'a aucun accès. Côté client, `_selectRows()` ajoute
systématiquement `.eq('user_id', _userId)` : la sécurité est appliquée deux fois,
en base et dans le client.

---

## 3. La révision espacée

`SpacedRepetitionService` — variante de SM-2, sans dépendance externe.

Quatre réponses possibles à la fin d'une carte :

| Réponse | Prochaine échéance | Effet sur l'état |
|---|---|---|
| **Encore** | +5 minutes | `repetitions` → 0, `lapses` +1, intervalle → 0, facilité −0,2, maîtrise perdue |
| **Difficile** | +15 minutes | `repetitions` +1, intervalle ×1,2, facilité −0,08 |
| **Correct** | +1 j, puis 3 j, puis intervalle × facilité | `repetitions` +1 |
| **Facile** | +4 j, puis intervalle × facilité × 1,2 | `repetitions` +1, facilité +0,12 |

Garde-fous : la facilité reste dans [1,3 ; 3,0], l'intervalle « correct » est
plafonné à 120 jours et l'intervalle « facile » à 180 jours — un plafond
délibéré, pour qu'une carte ne disparaisse jamais un an du calendrier.

Une carte est **maîtrisée** à partir de 3 réussites consécutives avec une
facilité ≥ 2,5. Un « Encore » remet `repetitions` à zéro, donc la maîtrise
retombe automatiquement.

Une carte est **due** dès que `due_at <= maintenant`.

### Le suggéré

Après une réponse auto-corrigée (QCM, texte à trous, saisie libre, vrai/faux),
l'app présélectionne « Correct » si la réponse était bonne, « Encore » sinon.
L'utilisateur garde la main sur les quatre boutons : la correction automatique
propose, elle ne décide pas.

---

## 4. La session d'étude

### Composition d'une session

La longueur est un réglage utilisateur (« Cartes par session », 12 par défaut).
Une session ne dépasse **jamais** cette limite.

L'ordre de remplissage :

1. **Le rattrapage** — les cartes ratées lors de la dernière révision, de
   l'échec le plus ancien au plus récent. Plafonné à la moitié de la limite,
   pour que de nouvelles cartes passent même après une mauvaise session.
2. **Les cartes dues**, dans l'ordre d'import. Si rien n'est dû, l'app bascule
   sur l'ensemble des cartes actives du périmètre plutôt que de refuser la
   session.
3. **Le reste du rattrapage**, en dernier recours, si le périmètre ne contient
   rien d'autre — mieux vaut rejouer que servir une session à moitié vide.

Une carte ratée n'est **pas** rejouée dans la session courante : elle ouvre la
suivante. La longueur d'une session reste donc celle choisie, quel que soit le
nombre d'erreurs — c'est le point qui distingue MemFlow d'un Anki classique, où
les ratés s'empilent en fin de session.

Les cartes ratées sont identifiées sans colonne dédiée : `repetitions == 0` et
`lapses > 0` désigne exactement les cartes dont la **dernière** réponse était
fausse, puisqu'un « Encore » remet `repetitions` à zéro et qu'une carte jamais
révisée n'a aucun lapse. Une carte sort du groupe dès qu'elle est réussie.

Les cartes d'un deck ou d'une collection **désactivés** sont exclues des
sessions et des compteurs « à revoir ». Leur historique de révision, lui, reste
comptabilisé dans les statistiques.

### Périmètre

Une session se lance depuis une collection entière (`/study?collectionId=…`) ou
depuis un deck (`/study?deckId=…`).

### Déroulé

À l'ouverture, une feuille de sélection (bottom sheet sur mobile, dialogue sur
desktop) demande le mode d'interrogation. « Adaptatif » présente chaque carte
dans le mode que sa progression lui a attribué (§5). Fermer la feuille sans
choisir annule la session et revient en arrière.

Chaque carte suit le même cycle : question → réponse → auto-correction →
les quatre boutons d'auto-évaluation → carte suivante.

L'enregistrement de la révision est **optimiste** : la carte suivante s'affiche
immédiatement, la sauvegarde part en file d'attente en arrière-plan. En cas
d'échec réseau, une snackbar propose « Réessayer » et la file reprend là où elle
s'était arrêtée, dans l'ordre. Aucune réponse n'est perdue et l'utilisateur n'est
jamais bloqué par la latence.

En fin de session, l'écran de bilan récapitule le nombre de cartes vues, la
répartition des quatre réponses et le taux de réussite, avec trois sorties :
retour à la collection, refaire une session sur le même périmètre, accueil.

### Responsive

Au-delà de 1100 px **et** sur plateforme desktop (Linux, macOS, Windows), la
session passe en deux colonnes : le contenu à gauche, un panneau latéral fixe à
droite qui porte le feedback coloré et les boutons d'évaluation. En dessous, ou
sur le web et le mobile, les boutons restent en grille sous la carte.

---

## 5. Les modes d'interrogation

Six modes jouables.

| Mode | Interaction | Conditions d'activation |
|---|---|---|
| **QCM** | 4 propositions, correction immédiate au clic | toujours |
| **Flashcard** | question → « Révéler » ou balayage vers le haut | toujours |
| **Flashcard inversée** | la réponse est montrée, le concept est à retrouver | toujours |
| **Texte à trous** | banque de mots à placer dans les trous | données cloze structurées valides |
| **Saisie libre** | l'utilisateur tape sa réponse | `accepted_answers` non vide |
| **Vrai / faux** | une affirmation à valider ou rejeter | au moins une mauvaise réponse non vide |

`CardModeService.allowedModesFor()` calcule les modes disponibles **à l'import**
et les fige dans `allowed_test_modes`. Les trois premiers modes sont toujours
possibles ; les autres exigent des données que le CSV doit fournir.

Détails d'implémentation qui comptent :

- **QCM** — l'ordre des propositions est déterministe (tri par `hashCode`) et non
  aléatoire : la même carte présente toujours ses options dans le même ordre.
  Dans la grille desktop, toutes les bulles adoptent la hauteur de l'option la
  plus longue, mesurée avant le rendu, pour que la grille reste régulière.
- **Texte à trous** — les trous s'écrivent `{{réponse}}` dans `cloze_text`. La
  banque de mots est mélangée à chaque affichage, les mots consommés
  disparaissent, le focus saute automatiquement au trou vide suivant, et chaque
  trou est validé indépendamment (vert/rouge par trou).
- **Saisie libre** — la comparaison est normalisée : minuscules, ponctuation et
  accents réduits, espaces compactés. `accepted_answers` permet de lister
  plusieurs formulations acceptables.
- **Vrai / faux** — l'affirmation affichée est tirée au sort parmi la bonne
  réponse et les mauvaises réponses de la carte, puis figée dans l'état de
  session pour qu'elle ne change pas au moindre rebuild. Si la carte n'a aucune
  mauvaise réponse exploitable, elle bascule en flashcard classique plutôt que
  de proposer un vrai/faux toujours vrai.

### La progression automatique des modes

C'est le cœur pédagogique de l'app : une carte ne reste pas éternellement en QCM.

`CardModeService.nextMode()` fait évoluer le mode de la carte selon la réponse.
Un « Encore » ramène au QCM — reconnaissance avant rappel. Un « Correct » promeut
QCM → flashcard → flashcard inversée, à mesure que les répétitions
s'accumulent. Un « Facile » saute directement au mode le plus exigeant que la
carte supporte (saisie libre, puis texte à trous, puis inversée).

En mode **Adaptatif**, c'est ce mode stocké qui est présenté. Imposer un mode
pour une session ne casse pas la progression : c'est le mode **réellement joué**
qui est journalisé et qui sert au calcul du mode suivant. Répondre en vrai/faux
fait donc avancer la carte depuis le vrai/faux, pas depuis un mode qu'on n'a pas
vu.

Le vrai/faux n'entre jamais dans cette progression : c'est un mode de
reconnaissance faible, disponible sur demande mais qui ne constitue pas une
étape de maîtrise.

---

## 6. Écrans et navigation

Navigation par `go_router`, avec une redirection d'authentification globale : non
connecté → `/auth` ; connecté sur `/auth` → `/` ; lien de récupération de mot de
passe cliqué → `/reset-password`, quelle que soit la destination demandée.

Une barre de navigation basse relie les quatre destinations principales :
Accueil, Stats, Importer, Profil.

| Route | Écran | Ce qu'on y fait |
|---|---|---|
| `/auth` | Connexion | Inscription (nom + email + mot de passe) ou connexion, mot de passe oublié |
| `/reset-password` | Nouveau mot de passe | Saisie du nouveau mot de passe après clic sur le lien reçu |
| `/` | Accueil | Salutation personnalisée, avancement du jour, 3 tuiles (série, réussite, à revoir), recherche et grille des collections |
| `/collection/:id` | Détail collection | Compteurs, lancement de session, tri des decks, changement d'icône, activation/désactivation, suppression |
| `/collection/:id/due-cards` | Échéances | Liste paginée des cartes avec leur date de prochaine révision, reprogrammation manuelle |
| `/deck/:id/cards` | Cartes du deck | Liste paginée des questions/réponses, suppression carte par carte |
| `/study` · `/study/:deckId` | Session | Le cœur de l'app (§4, §5) |
| `/session-summary` | Bilan | Récapitulatif de fin de session |
| `/stats` | Statistiques | Série, cartes vues, réussite, activité 14 jours, répartition par niveau |
| `/import` | Import CSV | Chargement, prévisualisation, prompt IA, template |
| `/profile` | Profil | Objectif quotidien, thème, export CSV, version, liens légaux, déconnexion, suppression de compte |
| `/settings` | Paramètres du compte | Nom d'affichage, email, mot de passe, cartes par session |
| `/legal/:doc` | Documents légaux | Confidentialité, CGU, mentions légales |
| _(inconnue)_ | 404 | Page dédiée avec le chemin demandé et un retour à l'accueil |

### Actions destructrices

Suppression de collection, de deck et de carte passent toutes par un dialogue de
confirmation. La suppression en base est en cascade : supprimer une collection
emporte ses decks, ses cartes et ses journaux.

La **désactivation** est l'alternative non destructive, pensée pour l'après-
examen : le deck ou la collection reste visible mais grisé, ses cartes sortent
des sessions et des compteurs, et tout est réversible d'un clic.

### Pagination

Les deux écrans de liste longue (cartes d'un deck, échéances d'une collection)
utilisent `PaginatedListController` : pages de 40, chargement à l'approche du bas
de la liste, et rafraîchissement automatique quand un événement Realtime touche
la table concernée — en conservant le nombre d'éléments déjà affichés, pour que
le scroll ne saute pas sous les doigts.

---

## 7. Import et export CSV

### Le format

Dix-sept colonnes, séparateur `;` recommandé :

```
collection;deck;question;correct_answer;wrong_answer_1;wrong_answer_2;wrong_answer_3;
hint;explanation;level;difficulty;tags;source;cloze_text;accepted_answers;
cloze_answers;cloze_word_bank
```

Le parseur détecte automatiquement le séparateur (`;`, `,` ou tabulation) sur les
cinq premières lignes, et détecte la présence d'un en-tête à la présence des
colonnes `collection` et `correct_answer`. Sans en-tête, il retombe sur les
positions ci-dessus. Les valeurs multiples se séparent par `|`.

### Les validations

L'import est **transparent avant d'être permissif** : chaque ligne rejetée est
listée avec son numéro et sa raison, et la prévisualisation annonce le nombre de
cartes détectées avant toute écriture. Les règles :

- collection, deck, question, bonne réponse et les **trois** mauvaises réponses
  sont obligatoires ;
- `level` est un entier de 1 à 4 ;
- `difficulty` vaut `facile`, `moyen` ou `avancé` (vide = facile) ;
- si `cloze_answers` ou `cloze_word_bank` est renseigné, tout le bloc cloze doit
  être cohérent : un `cloze_text` présent, au moins un trou `{{…}}`, autant de
  réponses que de trous, une banque de mots contenant toutes les bonnes réponses
  et sans doublon inutile.

Cette dernière validation est stricte par choix : un texte à trous à moitié
configuré produit un mode injouable, il vaut mieux le refuser à l'import que le
découvrir en pleine session.

### Le prompt IA

`prompt_csv_memflow_neutre.md` est embarqué comme asset et affiché dans l'écran
d'import, avec copie dans le presse-papiers et téléchargement. Il décrit à un
modèle comment transformer un cours en banque de questions au format MemFlow. Le
même écran propose le téléchargement d'un template CSV vide.

### L'export

Depuis le profil, « Exporter les cartes en CSV » produit un fichier reprenant
exactement le format d'import : ce qui sort peut être réimporté.

---

## 8. Statistiques et progression

Deux surfaces distinctes.

**Accueil** — les indicateurs du jour : série en cours, taux de réussite global,
nombre de cartes à revoir. La ligne d'accroche compare les cartes dues à
l'objectif quotidien (20 par défaut) et bascule sur « Objectif atteint »
lorsqu'il n'y a plus rien à réviser.

**Statistiques** — série, total de cartes vues, taux de réussite, histogramme
d'activité sur 14 jours, et répartition des cartes par niveau (Basique,
Intermédiaire, Actif, Avancé — le `level` du CSV).

La **série** compte les jours consécutifs, en partant d'aujourd'hui et en
remontant, où au moins une révision a été enregistrée. Elle se calcule en heure
locale, pas en UTC. Le **taux de réussite** est le rapport des journaux
`was_correct` sur le total, sur toute l'historique.

Les journaux de révision ne sont jamais filtrés par l'état activé/désactivé :
désactiver un deck retire ses cartes du futur, pas son historique du passé.

---

## 9. Compte utilisateur

Authentification Supabase par email et mot de passe. Le nom d'affichage est
stocké dans les métadonnées utilisateur (`display_name`) et retombe sur la partie
locale de l'email s'il est absent.

Gérés depuis les paramètres : nom d'affichage, email (avec email de confirmation
sur la nouvelle adresse), mot de passe, nombre de cartes par session.

La **suppression de compte** est volontairement manuelle : l'app ouvre le client
mail de l'utilisateur avec une demande pré-remplie vers l'adresse de support,
identifiant de compte inclus. Aucune suppression automatique n'est câblée.

Documents légaux (confidentialité, CGU, mentions légales) rendus dans l'app à
partir de sections écrites en dur, plus la page de licences open source native de
Flutter.

---

## 10. Design system

Style « papier chaud » : fond crème, cartes blanches, accent orange, grands
arrondis, beaucoup de blanc.

Quatre thèmes : **Système**, **Clair**, **Sombre** et **Vivid** — ce dernier est
une palette bleue/magenta à contraste élevé, techniquement un thème clair. Le
choix est persisté et accessible depuis n'importe quel écran via le bouton
palette.

Typographie : **Lora** (serif) pour les titres, **Outfit** pour le texte et les
libellés, chargées par `google_fonts`.

Les couleurs sémantiques de correction (vert réussite, rouge erreur, orange
difficile, bleu facile) sont définies en dur et **identiques en clair et en
sombre** — un choix assumé pour que le vert reste le vert.

Le contenu est contraint à 920 px de large et centré : sur grand écran, l'app ne
s'étire pas, elle se centre. `AppScaffold` applique cette contrainte partout.

Tous les composants partagés vivent dans `lib/widgets/ui.dart` — la règle : un
widget y entre dès qu'il est utilisé par deux écrans, sinon il reste privé à son
écran.

---

## 11. Réglages persistés

Trois réglages en `shared_preferences`, chacun avec son contrôleur Riverpod :

| Réglage | Défaut | Bornes | Où le modifier |
|---|---|---|---|
| Thème | Système | — | Bouton palette, profil |
| Objectif quotidien | 20 | 1–999 | Profil |
| Cartes par session | 12 | 1–999 | Paramètres |

`shared_preferences` ne sert **qu'à** ces préférences légères : aucune donnée
métier n'y transite.

---

## 12. Base de données

Le même modèle est décrit deux fois, et les deux doivent rester alignés :

- **Localement** — les tables Drift de `lib/data/local/database.dart`, plus une
  file de synchronisation et une table de métadonnées (propriétaire de la base,
  curseur des journaux). Ces deux dernières ne sont jamais synchronisées : elles
  décrivent l'état de cet appareil-ci.
- **À distance** — les migrations de `supabase/migrations/`, à appliquer dans
  l'ordre des noms de fichiers.

Ce qui circule entre les deux est sérialisé dans `SyncService` ; c'est le seul
endroit où les noms de colonnes distants apparaissent, et des tests verrouillent
la forme exacte des payloads.

Trois décisions de schéma méritent d'être connues :

- **`color` est un `bigint`**, pas un `integer` : une couleur Flutter opaque
  (ARGB avec alpha `0xFF`) dépasse la borne des entiers signés 32 bits.
- **Les identifiants sont des `text`**, pas des `uuid` : ce sont des UUID v4
  générés côté client, ce qui permet d'écrire hors ligne sans aller-retour.
- **Les dates locales sont des entiers** (millisecondes epoch), converties en
  ISO UTC à l'envoi. Les comparaisons Dart portent sur l'instant absolu, donc le
  fuseau n'entre jamais en jeu ; seuls les calculs par jour (série, activité)
  repassent en heure locale, volontairement.

Les index distants couvrent les clés étrangères, `due_at` et `updated_at` — les
trois axes sur lesquels l'app filtre et trie réellement.

Si le schéma Drift change, il faut régénérer le code :

```bash
dart run build_runner build
```

---

## 13. Tests, build et déploiement

### Tests

`flutter test` couvre trois étages :

- la **logique métier pure** (répétition espacée, progression des modes, parsing
  CSV, contrôleur de session, pagination) ;
- le **comportement hors ligne**, sur une vraie base SQLite en mémoire et un
  client Supabase sans session — donc sans le moindre accès réseau. C'est la
  situation exacte d'un utilisateur déconnecté : import, révision, suppression et
  statistiques doivent fonctionner à l'identique ;
- le **rendu des écrans sensibles** (session d'étude en mobile/tablette/desktop,
  détail de collection, thème vivid, route inconnue).

La règle : les services de `domain/` sont testés sans Flutter ni base ; la couche
données l'est sur `AppDatabase.memory()` ; les écrans le sont par `testWidgets`
avec un repository injecté — `StudyController.forTesting()` existe exactement
pour ça.

Ce qui n'est **pas** couvert automatiquement : le push et le pull réels contre
Supabase, qui demanderaient un serveur. Les invariants locaux dont ils dépendent
(ordre de la file, collapsing des intentions, purge au changement de compte,
nettoyage des orphelins, forme des payloads) le sont, eux.

### Environnement

Les secrets passent par `--dart-define-from-file=.env` et sont lus au bootstrap
via `String.fromEnvironment`. Ils sont donc **compilés dans le binaire** : la clé
`anon` de Supabase est publique par nature, c'est la RLS qui protège les données.

### Déploiement

Le web est déployé sur Vercel : `build.sh` clone le SDK Flutter puis lance
`flutter build web` en injectant les variables d'environnement ; `vercel.json`
réécrit toutes les routes vers `index.html` (l'app est une SPA).

Le numéro de version est écrit à **deux endroits** qui doivent rester
synchronisés : `pubspec.yaml` et `lib/app/app_version.dart` (affiché dans le
profil).

---

## 14. Limites connues

**Pas de détection de connectivité.** L'app ne sait pas qu'elle est hors ligne :
elle tente, échoue, et réessaie — après chaque écriture, toutes les 30 secondes
tant qu'il reste des envois en attente, et au retour d'un signal Realtime. La
reprise est donc au pire différée d'une trentaine de secondes après le retour du
réseau, sans dépendance supplémentaire à embarquer.

**Le rapatriement est complet.** Collections, decks et cartes sont relus
intégralement à chaque synchronisation, pour pouvoir détecter ce qui a été
supprimé ailleurs sans table de pierres tombales. Seuls les journaux de révision,
qui grossissent sans fin, sont incrémentaux. À l'échelle d'un utilisateur c'est
sans conséquence ; sur un jeu de cartes très volumineux, ce serait le premier
endroit à rendre incrémental.

**Le dernier écrivain gagne.** La résolution de conflit compare les dates de
modification, sans fusion champ par champ. Deux appareils qui modifient la même
carte pendant la même fenêtre hors ligne : le plus récent écrase l'autre. Pour
des cartes personnelles, c'est le compromis raisonnable.

**Les compteurs d'écran chargent toutes les cartes en mémoire.** L'accueil, les
listes et les statistiques matérialisent l'ensemble des cartes pour recalculer
les totaux. C'est immédiat en local et borné par la taille du jeu de cartes ; les
journaux de révision, eux, ne sont jamais matérialisés, seulement agrégés en SQL.
