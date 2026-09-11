# Rapport d’audit — import de questions et session d’étude

## Synthèse

Le produit possède une base saine : le format CSV est centralisé, l’import affiche une prévisualisation avant écriture, les réponses sont évaluées par des règles partagées, les cartes disposent d’un mode adaptatif, et les tests couvrent déjà l’essentiel des parcours nominaux.

La fiabilité réelle reste toutefois inégale. Un CSV produit par un modèle peut facilement être accepté alors qu’il n’est pas conforme au contrat pédagogique ou structurel annoncé. Le risque le plus important côté import est l’absence de validation de schéma suffisamment stricte, suivie par l’absence de dédoublonnage. Côté étude, le risque le plus important est la perte possible d’une révision en attente lorsque la sauvegarde asynchrone échoue ou que l’application est interrompue. Enfin, le taux de réussite affiché mesure la notation choisie par l’utilisateur, et non systématiquement l’exactitude de sa réponse.

## Périmètre et méthode

L’audit porte sur :

- `prompt_csv_memflow_neutre.md` et son chargement dans l’écran d’import ;
- `CsvImportService`, `CsvExportService`, `CardModeService` et les règles de réponse ;
- la création d’une session dans `AppRepository` ;
- le choix du mode, le rendu et la validation des six modes d’étude ;
- la file de sauvegarde des révisions et l’écran de synthèse ;
- les tests unitaires, d’intégration locale et de widgets existants.

La commande `flutter test` a été exécutée avec succès : 90 tests passent. Cette couverture valide les scénarios testés, mais ne démontre pas l’absence des défauts décrits ci-dessous, car plusieurs cas limites ne sont pas testés.

## 1. Chaîne d’import et génération des questions

### 1.1 Ce que le prompt fait bien

Le prompt est riche sur la qualité pédagogique. Il demande une couverture section par section, des questions courtes centrées sur une idée, plusieurs niveaux de difficulté, des distracteurs plausibles, des explications et des textes à trous non mécaniques. Les consignes sur les clozes sont particulièrement utiles : ordre des réponses, compatibilité grammaticale, homogénéité des distracteurs et limitation du nombre de trous (`prompt_csv_memflow_neutre.md:11-182`).

Le contrat de colonnes est explicite et aligné avec le header codé dans l’import et l’export (`prompt_csv_memflow_neutre.md:184-208`, `lib/domain/services/csv_import_service.dart:14-32`, `lib/domain/services/csv_export_service.dart:6-19`). Le fait que l’application permette de copier ou télécharger le prompt depuis l’écran d’import réduit le risque d’utiliser une ancienne version (`lib/features/import/import_screen.dart:20-49`, `lib/features/import/import_screen.dart:184-252`).

Le prompt rappelle aussi que la sortie doit être uniquement un CSV. C’est une bonne protection contre les commentaires, blocs Markdown ou titres ajoutés par le modèle.

### 1.2 Contradictions et limites du prompt

Le prompt demande à la fois de ne laisser aucun champ vide et de laisser les champs optionnels sans contenu lorsque le texte à trous n’est pas pertinent. En pratique, le code accepte les champs optionnels vides et traite même une difficulté vide comme `facile` (`CsvImportService._parseDifficulty`). Le modèle ne sait donc pas clairement si une cellule vide est invalide ou normale.

La notion de « fichier CSV directement importable » n’est pas assez opérationnelle. Il faudrait dire explicitement : séparateur `;`, encodage UTF-8, première ligne obligatoire, 17 colonnes exactement par ligne, guillemets CSV obligatoires autour des champs contenant `;`, `"` ou des retours à la ligne, et séparateur `|` réservé aux listes. Le prompt donne un exemple non cité et non échappé ; un modèle peut produire des lignes qui paraissent correctes visuellement mais que le parseur découpera mal.

Le prompt optimise fortement le nombre de questions (« maximum », « plus grand nombre possible »). Cela peut créer de la redondance, des cartes trop proches et une session dominée par des micro-faits. Il manque un critère de budget : nombre de cartes par section, seuil de similarité, ou priorité à la couverture avant la multiplication des variantes.

Il demande des distracteurs crédibles, mais sans fournir de test vérifiable. Rien n’empêche une mauvaise réponse d’être identique à la bonne, de répéter un autre distracteur, ou d’être syntaxiquement incompatible. Or ces défauts ont un impact direct sur QCM et vrai/faux.

La consigne « basée uniquement sur le document » est bonne, mais elle ne demande pas de conserver une trace exploitable de la preuve : citation courte, section source ou identifiant de paragraphe. Le champ `source` est présent, mais le prompt ne contraint pas son contenu. La correction humaine est donc difficile.

### 1.3 Fiabilité du CSV produit par un modèle

Évaluation qualitative actuelle :

| Dimension | Niveau | Analyse |
|---|---:|---|
| Présence des 17 colonnes dans l’exemple | Bon | Le header et l’ordre sont clairement documentés. |
| Échappement CSV | Moyen-faible | Le prompt n’explique pas assez les guillemets et retours à la ligne. |
| Types `level` / `difficulty` | Bon | Le domaine des valeurs est décrit et l’import rejette les niveaux invalides. |
| Champs obligatoires | Moyen | L’import les contrôle, mais les colonnes absentes peuvent être remplies par position. |
| Clozes structurelles | Moyen | Plusieurs contrôles existent, mais le texte des placeholders n’est pas comparé aux réponses. |
| Distracteurs | Faible à moyen | Qualité demandée mais aucune validation d’unicité ou d’équivalence. |
| Absence de doublons | Faible | Le prompt le demande, mais l’application crée une nouvelle carte à chaque import. |
| Traçabilité pédagogique | Faible | `source` n’est pas normalisé en section/citation. |

La conclusion est donc la suivante : le prompt est bon pour orienter un modèle vers un contenu utile, mais il ne suffit pas à garantir un CSV conforme. Le parseur est tolérant et peut transformer une sortie imparfaite en cartes partiellement valides, ce qui donne une fausse impression de réussite.

## 2. Fonctionnement concret de l’importeur

### Points positifs

- Fichier vide et CSV mal formé sont signalés avec une erreur lisible.
- Le parseur accepte `;`, `,` et tabulation, avec ou sans header.
- Les valeurs obligatoires, le niveau et la difficulté sont contrôlés avant création de la carte.
- Les listes utilisent une convention simple et cohérente (`|`).
- Les clozes structurées sont activées seulement lorsque `cloze_text`, les réponses et la banque sont présents et compatibles (`lib/domain/services/card_mode_service.dart:17-43`).
- L’import est transactionnel et crée au besoin collection et deck (`lib/data/repositories/app_repository.dart:286-394`).
- Le template et l’export de sauvegarde partagent exactement le même header (`lib/domain/services/csv_export_service.dart`, tests associés).

### Risques prioritaires

1. **Détection de séparateur fragile.** `_detectDelimiter` choisit le caractère le plus fréquent dans les cinq premières lignes, sans vérifier que chaque ligne a le même nombre de colonnes (`lib/domain/services/csv_import_service.dart:45-48`, puis méthode de détection). Une explication riche en virgules peut faire choisir `,` au lieu de `;`, même si le fichier est bien un CSV séparé par `;`.

2. **Aucune validation de largeur de ligne.** Le parseur lit les colonnes disponibles et renvoie une chaîne vide si l’index manque. Une ligne avec 10 ou 20 cellules n’est donc pas rejetée comme structurellement invalide. Avec un header incomplet, le fallback par index peut aussi masquer une colonne mal nommée (`_readValue`).

3. **Header seulement partiellement contrôlé.** La présence de `collection` et `correct_answer` suffit à reconnaître un header. Les 15 autres intitulés peuvent manquer, être dupliqués ou être mal orthographiés sans erreur dédiée.

4. **Décodage UTF-8 permissif.** `allowMalformed: true` remplace les octets invalides au lieu de rejeter le fichier. Des caractères altérés peuvent donc entrer dans les questions ou réponses sans avertissement (`CsvImportService:45-47`).

5. **Doublons non traités.** `importCards` génère un nouvel UUID pour chaque ligne puis insère la carte. Une réimportation du même backup ajoute donc les mêmes cartes. Le message de confirmation prévient l’utilisateur, mais ne propose ni aperçu des doublons ni stratégie de fusion (`lib/features/import/import_screen.dart:103-142`, `lib/data/repositories/app_repository.dart:286-394`).

6. **Validation cloze incomplète.** `validateStructuredCloze` vérifie le nombre de trous et la présence des réponses dans la banque, mais pas l’égalité entre le contenu de `{{...}}` et `cloze_answers` (`lib/domain/services/answer_rules.dart:18-72`). Un CSV peut donc afficher un placeholder différent de la réponse effectivement utilisée pour corriger et afficher la solution.

7. **Qualité sémantique non contrôlée.** Rien ne vérifie que `correct_answer` est distincte des trois mauvaises réponses, que les mauvaises réponses sont distinctes entre elles, que la banque cloze ne contient pas de variante équivalente inattendue, ou que `accepted_answers` contient bien la réponse correcte.

8. **Ambiguïté autour des modes.** Une carte dispose toujours de QCM, flashcard classique et flashcard inversée ; saisie libre dépend de `accepted_answers`, cloze de ses trois champs, et vrai/faux de la présence d’au moins une mauvaise réponse. Le prompt devrait exposer cette conséquence, sinon l’utilisateur peut croire qu’une cellule remplie suffit à activer un mode.

### Améliorations recommandées pour l’import

Priorité P0 :

- Imposer un header complet, unique et exactement égal au header canonique ; rejeter les colonnes manquantes, inconnues ou dupliquées.
- Vérifier que chaque ligne non vide contient exactement 17 colonnes.
- Détecter le séparateur par cohérence de largeur de ligne, avec priorité explicite à `;`, plutôt que par fréquence brute.
- Décoder en UTF-8 strict et signaler les octets invalides.
- Ajouter des erreurs de ligne pour doublon de bonne/mauvaise réponse, mauvaise réponse répétée et réponse cloze incohérente.
- Comparer le texte des placeholders à `cloze_answers`, ou supprimer le contenu du placeholder comme source de vérité et utiliser un token positionnel explicite.

Priorité P1 :

- Introduire une clé stable de carte, par exemple `collection + deck + question`, et proposer à l’import : ajouter, ignorer, remplacer ou fusionner.
- Afficher le nombre de lignes, la largeur attendue, les erreurs groupées par type et un aperçu des cartes invalides.
- Ajouter un validateur réutilisable côté export et côté import, afin de garantir que tout backup produit par l’application passe le même contrat.
- Documenter dans le prompt un mini-exemple avec une question contenant un point-virgule, une virgule, des guillemets et un retour à la ligne.

Priorité P2 :

- Demander un champ `source` structuré, par exemple `Chapitre 2 — § 2.3`, et demander au modèle de remplir ce champ pour chaque carte.
- Remplacer « maximum de questions » par une couverture mesurable et un contrôle de redondance.
- Fournir un second prompt de réparation : entrée = CSV rejeté + erreurs, sortie = CSV corrigé uniquement.

## 3. Session d’étude : du démarrage aux résultats

### 3.1 Choix de la manière d’étudier

Lorsque le mode n’est pas imposé par la route, `StudyScreen` ouvre un bottom sheet sur mobile ou une boîte de dialogue sur écran large (`lib/features/study/study_screen.dart:92-119`, `lib/features/study/mode_selection_sheet.dart`). Les six modes sont proposés : adaptatif, QCM, flashcard, flashcard inversée, saisie libre, vrai/faux et cloze.

Le choix « Adaptatif » passe par `forcedMode: null`, puis chaque carte utilise son `currentTestMode`. Les autres choix forcent le mode au niveau de la session, mais `_resolveMode` retombe sur un mode compatible si la carte ne dispose pas des données nécessaires (`lib/data/repositories/app_repository.dart:1062-1104`). C’est robuste contre les imports incomplets, mais l’interface ne prévient pas à l’avance combien de cartes seront réellement jouées dans le mode choisi.

Points positifs : choix explicite, responsive, fermeture interprétée comme abandon, et fallback sûr pour les cartes incompatibles. Point négatif principal : le choix cloze ou saisie libre peut produire une session mixte sans indication, alors que l’utilisateur a demandé un mode homogène.

### 3.2 Composition de la session

Le repository exclut les collections et decks désactivés, met d’abord les cartes échouées à la session précédente, puis les cartes dues, et respecte la limite de session (`lib/data/repositories/app_repository.dart:934-1061`). Les cartes ratées sont plafonnées à environ la moitié de la session pour laisser entrer du nouveau contenu ; si elles sont le seul contenu, elles remplissent la session.

Cette stratégie est lisible, déterministe et couverte par des tests. Elle ne mélange toutefois pas les cartes futures si quelques cartes dues suffisent à remplir partiellement la session : une session peut donc être plus courte que la limite. L’ordre est l’ordre d’import, et non un ordre aléatoire ou une priorité explicite par échéance parmi les cartes dues.

### 3.3 Évaluation des réponses

- **QCM :** quatre options sont construites puis triées par hash ; la comparaison ignore casse et espaces (`StudyRules:19-27`, `StudyCard.buildOptions`). La normalisation est cohérente, mais les doublons sémantiques importés ne sont pas empêchés.
- **Flashcard classique :** la question est affichée puis la réponse révélée ; l’utilisateur s’auto-évalue.
- **Flashcard inversée :** la réponse devient le recto et la question la correction. C’est utile pour le rappel bidirectionnel, mais dépend d’un contenu de question et de réponse bien rédigé.
- **Vrai/faux :** une proposition est tirée parmi la bonne réponse et les mauvaises réponses puis conservée pour la carte (`StudyRules:29-52`). C’est un mécanisme simple et testable. Il reste vulnérable aux mauvaises réponses dupliquées ou trop évidentes.
- **Saisie libre :** elle accepte `accepted_answers`, sinon retombe sur `correct_answer`. La comparaison est stricte hors casse et espaces : ponctuation, accents composés/décomposés, variantes morphologiques et synonymes ne sont pas tolérés (`lib/domain/services/answer_rules.dart:1-10`, `StudyRules:54-60`). C’est prévisible mais potentiellement sévère pour des réponses générées par modèle.
- **Cloze :** les trous sont construits par expression régulière, la banque est mélangée, chaque mot est consommé une fois et tous les trous doivent être corrects (`StudyRules:62-107`). L’interface permet le remplissage progressif et affiche la solution. La correction exige toutefois la totalité des trous et ne propose pas de score partiel dans les résultats.

### 3.4 Avancement et persistance

Après validation, les boutons « Encore », « Difficile », « Correct » et « Facile » sont disponibles. La carte suivante est affichée immédiatement, tandis que la sauvegarde est placée dans une file en mémoire (`lib/features/study/study_screen.dart:284-390`). La transaction locale écrit la carte mise à jour et le journal de révision ensemble (`lib/data/repositories/app_repository.dart:204-280`), ce qui est un bon choix pour la cohérence locale et la synchronisation.

Le modèle de répétition espacée est simple et bien isolé : `again` remet les répétitions à zéro et programme rapidement, `good` et `easy` augmentent progressivement l’intervalle, avec des plafonds et une règle de maîtrise (`lib/domain/services/spaced_repetition_service.dart`).

Risque critique : en cas d’échec d’une sauvegarde, la file reste uniquement en mémoire et un SnackBar propose de réessayer. Si l’utilisateur ferme l’application, navigue hors du flux ou si le dernier envoi échoue, la révision peut être perdue. Le commentaire du code protège explicitement le dernier envoi avant la navigation, mais attendre une file qui s’est arrêtée après erreur ne garantit pas que l’écriture a réussi. La file devrait être persistée localement ou la navigation vers le résumé devrait être bloquée tant que toutes les écritures n’ont pas abouti.

Autre point métier : `submitReview` reçoit `wasCorrect`, mais le planning est calculé uniquement à partir de `reviewResult`. L’utilisateur peut répondre faux puis choisir « Correct » ; le journal conserve `wasCorrect: false`, mais la carte est planifiée comme `good` et le résumé compte cette révision dans la réussite (`lib/data/repositories/app_repository.dart:208-258`, `lib/domain/models/models.dart:747-755`). Cette séparation peut être volontaire pour l’auto-évaluation, mais le libellé « réussite » est alors trompeur.

### 3.5 Affichage des résultats

L’écran final affiche le nombre de cartes, les quatre catégories d’auto-évaluation et un taux de réussite (`lib/features/study/session_summary_screen.dart:28-75`). Les actions de retour à la collection, répétition de session et accueil sont claires.

Le résultat est compact et lisible. Il manque cependant : le mode choisi ou le mode réellement joué, le nombre de réponses objectivement correctes, les cartes à revoir, les erreurs par type, le temps passé et les sauvegardes en attente. Pour une session contenant plusieurs modes, aucune information n’explique le fallback appliqué.

## 4. Plan d’amélioration priorisé

### P0 — fiabilité des données

1. Rendre le validateur CSV strict : header canonique, 17 colonnes, séparateur cohérent, UTF-8 valide.
2. Ajouter les contrôles d’unicité et de cohérence des réponses et des clozes.
3. Persister la file des révisions dans la base locale, avec état `pending/failed/sent`, retry automatique et écran de résolution avant abandon.
4. Décider explicitement si la réussite signifie « réponse objectivement correcte » ou « niveau choisi par l’utilisateur », puis renommer et calculer les indicateurs en conséquence.

### P1 — expérience et diagnostic

1. Afficher avant le démarrage le nombre de cartes compatibles avec le mode choisi et le nombre de cartes qui utiliseront un fallback.
2. Afficher dans l’aperçu d’import les doublons potentiels et les cartes qui n’auront pas de saisie libre/cloze/vrai-faux.
3. Ajouter un écran de résumé avec deux métriques distinctes : exactitude et auto-évaluation.
4. Ajouter un bouton « reprendre les sauvegardes » et une indication persistante des révisions non synchronisées.

### P2 — qualité pédagogique

1. Produire un prompt plus court mais plus exécutable, avec un contrat machine-readable et des exemples d’échappement CSV.
2. Exiger une source par carte et un identifiant stable de section.
3. Dédupliquer les questions sémantiquement proches et limiter le nombre de variantes par notion.
4. Prévoir un validateur externe ou une commande de contrôle qui donne au modèle les erreurs exactes à corriger.

## 5. Tests à ajouter

- CSV séparé par `;` dont les explications contiennent beaucoup de virgules.
- Champ contenant `;`, guillemets, retour à la ligne et caractère UTF-8 invalide.
- Header manquant, incomplet, dupliqué, mal orthographié et colonne supplémentaire.
- Ligne trop courte ou trop longue.
- Réponses correctes et mauvaises identiques ou dupliquées.
- Placeholder `{{A}}` avec `cloze_answers=A|B` et cas de placeholder répété.
- Réimport du même backup : vérifier la stratégie choisie.
- Session forcée cloze avec mélange de cartes compatibles et incompatibles, en affichant le fallback.
- Échec de sauvegarde sur une carte intermédiaire puis fermeture/nouvelle ouverture.
- Échec de sauvegarde de la dernière carte : le résumé ne doit pas masquer une révision non persistée.
- Réponse fausse suivie de « Correct » : vérifier séparément la planification, l’exactitude et le taux affiché.
- Abandon avant la fin : vérifier le comportement de la file et le message utilisateur.

## Conclusion

Memflow est déjà solide sur l’architecture et les parcours nominaux. Le prompt est pédagogiquement ambitieux et le code sait exploiter proprement ses champs avancés quand ils sont bien formés. La faiblesse actuelle vient surtout d’un contrat trop tolérant : un modèle peut produire un fichier qui semble valide, être partiellement accepté, puis générer des cartes incohérentes ou dupliquées.

La priorité est donc de déplacer la confiance du prompt vers un validateur strict et explicatif, puis de rendre la persistance des révisions durable avant de poursuivre les améliorations de présentation. Une fois ces deux garanties acquises, le choix adaptatif, les six modes et l’écran de synthèse pourront fournir une expérience réellement fiable plutôt qu’une expérience seulement convaincante dans les cas heureux.
