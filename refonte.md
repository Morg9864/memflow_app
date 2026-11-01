# Refonte UI/UX de Memflow

## 1. Objectif

Transformer Memflow en une application mobile Flutter plus professionnelle, premium, cohérente et fluide, **sans modifier son identité visuelle fondamentale ni ses fonctionnalités**. La refonte doit améliorer la hiérarchie visuelle, la lisibilité, les interactions, les animations et les performances réelles.

### Contraintes non négociables

- **Conserver la palette claire actuelle** : fond crème/blanc cassé et orange existant comme unique couleur d'accent.
- **Ne pas introduire de nouvelles couleurs d'accent**, ni de thème sombre, ni de thème « Vivid ». Privilégier une seule identité claire. Les états fonctionnels doivent rester compréhensibles sans dépendre uniquement de la couleur (icône, texte, forme).
- Conserver le logo Memflow et son identité typographique, hormis de légers ajustements justifiés.
- Préserver l'approche minimaliste, les cartes arrondies et les interfaces aérées.
- Préserver les fonctionnalités, les données, la logique métier et les parcours utilisateurs.
- Éviter les animations purement décoratives, les effets excessifs, les dépendances injustifiées et les réécritures complètes.

> Le but n'est pas de rendre Memflow plus colorée, mais plus élégante, plus cohérente et plus vivante avec sa palette actuelle.

## 2. Diagnostic transversal et améliorations

| Élément | Problème observé | Amélioration attendue |
|---|---|---|
| Hiérarchie visuelle | Informations principales et secondaires trop similaires | Différencier tailles, graisses et espacements ; mettre les actions clés en avant |
| Cartes | Présentation générique, parfois trop vide | Revoir proportions, contenu, alignements et états interactifs |
| Typographie | Certaines légendes trop petites | Établir une échelle typographique cohérente et lisible |
| Espacements | Blocs parfois déconnectés | Uniformiser marges, padding, rythmes verticaux et alignements |
| Icônes | Certaines petites ou peu expressives | Harmoniser famille, taille, épaisseur et placement |
| Boutons | CTA orange fonctionnel mais classique | Affiner dimensions, typographie et feedback au toucher |
| Navigation | Barre inférieure basique | Améliorer état actif, transitions et continuité entre onglets |
| Collections | Titres et informations parfois tronqués | Améliorer organisation, gestion des textes et lisibilité |
| Statistiques | Graphiques discrets ou peu engageants | Renforcer leur présence et les états sans données |
| Animations | Interface globalement statique | Ajouter des mouvements courts, naturels et utiles |

### Design system

Créer ou consolider un système partagé couvrant :

- Couleurs : réutiliser **les valeurs exactes déjà présentes dans le code** ; ne pas inventer une nouvelle palette. Fond crème, surfaces claires, orange d'accent et neutres de texte/bordure.
- Typographie : rôles explicites (titre de page, section, valeur clé, corps, légende), tailles minimales lisibles et interlignage cohérent.
- Espacements : échelle commune pour marges, paddings, séparations et grilles.
- Surfaces : rayons, bordures, ombres très discrètes et élévations cohérentes.
- Boutons : variantes primaire, secondaire, discret, désactivé, pressé et en chargement.
- Cartes : variantes réutilisables et états vide, chargé, sélectionné et interactif.
- Icônes : bibliothèque homogène, tailles et épaisseurs harmonisées.
- Accessibilité : contrastes, tailles de zones tactiles, labels sémantiques, mise à l'échelle du texte et préférence de réduction des animations.

## 3. Refonte écran par écran

### 3.1 Accueil

**Constat :** l'accueil ressemble davantage à un tableau de bord fonctionnel qu'à un produit premium.

- Faire du bloc « 734 cartes à revoir » un point focal clair, avec une hiérarchie et une action évidentes.
- Repenser les cartes « série » et « à revoir », actuellement assez vides : équilibre du contenu, proportions et indicateurs.
- Améliorer les cartes de collections : titre complet ou troncature maîtrisée, nombre de cartes, progression et lisibilité.
- Repositionner ou hiérarchiser les actions secondaires, notamment « Importer CSV ».
- Harmoniser les espaces entre en-tête, indicateurs, collections et CTA.
- Ajouter des états de chargement et des transitions discrètes sans perturber le contenu.

### 3.2 Statistiques

**Constat :** écran parmi les plus perfectibles visuellement.

- Structurer les indicateurs principaux : série, cartes vues, réussite.
- Donner davantage de présence au graphique d'activité, sans surcharge.
- Clarifier les graphiques de progression : axes, légendes, données, périodes et états vides.
- Repenser les cartes « Progression par niveau » pour rendre les résultats immédiatement compréhensibles.
- Utiliser uniquement l'orange existant, ses nuances de transparence si nécessaire, et les neutres du thème clair.
- Ne pas inventer de données pour remplir les graphiques ; concevoir de vrais états sans données.

### 3.3 Collections et choix du mode de session

**Constat :** succession répétitive de cartes blanches, petites icônes et textes courts.

- Renforcer la distinction visuelle entre les collections et entre les modes sans introduire de nouvelles couleurs.
- Revoir la composition, la taille des icônes, les titres et les descriptions.
- Différencier par la mise en page les modes **Adaptatif, QCM, Flashcard, Flashcard inversée et Saisie libre**.
- Rendre la sélection et le démarrage d'une session immédiatement compréhensibles.
- Améliorer la transition collection → choix du mode → session.
- Gérer proprement les titres longs et les petits écrans.

### 3.4 Session de révision — priorité maximale

**Constat :** parcours central de Memflow, où l'utilisateur passe le plus de temps.

1. **Carte de question :** adapter les proportions aux textes courts et longs, améliorer la typographie et réduire les espaces vides injustifiés.
2. **Réponses QCM :** clarifier les états normal, pressé, sélectionné, correct et incorrect ; utiliser texte, icônes et mouvement plutôt que de nouvelles couleurs.
3. **Progression :** rendre la barre et les indicateurs plus élégants ; animer les changements de façon courte et régulière.
4. **Question suivante :** créer une transition naturelle, sans flash ni saut brutal de layout.
5. **Feedback :** révéler validation, correction et explication progressivement, avec un retour tactile mesuré si pertinent.
6. **Saisie libre :** soigner le champ de texte, l'apparition du clavier et le repositionnement de l'interface.
7. **Flashcards :** améliorer les gestes, le retournement et la stabilité visuelle ; éviter les effets trop longs.
8. **États limites :** longues questions, longues réponses, petit écran, interruption, chargement et fin de session.

### 3.5 Import CSV

- Clarifier la hiérarchie entre l'action d'import, les instructions et les options avancées.
- Donner des indications compréhensibles sur les formats acceptés et la progression.
- Concevoir des états cohérents : fichier choisi, import en cours, succès, erreur et données invalides.
- Conserver le même design system que le reste de Memflow.

### 3.6 Profil et paramètres

- Regrouper les réglages par catégories cohérentes au lieu de multiplier les blocs isolés.
- Uniformiser lignes, icônes, espacements, titres et contrôles.
- Supprimer les sélecteurs de thème sombre et « Vivid » si la décision produit est bien d'imposer uniquement le thème clair.
- Garantir une cohérence totale avec l'accueil et les sessions.

## 4. Navigation, animations et sensation de fluidité

| Interaction | Résultat recherché |
|---|---|
| Changement d'onglet | Transition légère, sans rechargement visible |
| Ouverture d'une collection | Fondu/glissement subtil ou transition partagée pertinente |
| Appui sur un bouton | Réponse immédiate et légère compression |
| Sélection d'une réponse | Feedback clair, animation de validation courte |
| Question suivante | Transition directionnelle fluide et stable |
| Barre de progression | Changement de valeur animé sans saccade |
| Ouverture du clavier | Repositionnement naturel, sans saut de contenu |
| Chargement | Skeletons ou états de chargement cohérents |
| Défilement | Scrolling stable, sans rebuilds inutiles |

### Recommandations Flutter

- Privilégier les primitives adaptées : `AnimatedSwitcher`, `AnimatedContainer`, `Hero`, `AnimatedOpacity` et `AnimationController` quand un contrôle fin est nécessaire.
- Préférer les animations courtes et utiles, plutôt qu'une animation systématique de chaque élément.
- Éviter les animations coûteuses sur de grandes surfaces ou déclenchant des reconstructions excessives.
- Respecter les réglages système de réduction des mouvements.
- Vérifier les performances **en mode profile sur un appareil réel** avec Flutter DevTools : temps de frame, rebuilds, chargements et scroll.
- Tester la fluidité sur des appareils moins puissants, et pas uniquement sur un émulateur haut de gamme.
- Garder des retours tactiles mesurés, compatibles avec la plateforme et désactivables si nécessaire.

## 5. Performance et robustesse

- Réduire les rebuilds inutiles et isoler les widgets fréquemment mis à jour.
- Optimiser les listes de collections, les images et les éléments lourds.
- Éviter les requêtes ou calculs bloquants pendant les transitions.
- Conserver l'état des onglets lorsque c'est pertinent.
- Mettre en cache les données utiles et gérer les états chargement/erreur/hors connexion.
- Tester les textes longs, les tailles de police agrandies, les petits écrans et les claviers ouverts.
- Vérifier l'accessibilité : contraste, lecture d'écran, navigation, zones tactiles et retours d'état.
- Ajouter ou adapter des tests pour les parcours essentiels afin de prévenir les régressions.

## 6. Ordre d'exécution recommandé

1. **Audit et design system** : inventorier les composants, relever les valeurs exactes de la palette existante, définir typographie, espacements, cartes, boutons et icônes.
2. **Sessions de révision** : moderniser questions, réponses, progression, transitions et feedbacks.
3. **Accueil et collections** : renforcer la hiérarchie et la lisibilité de la progression.
4. **Navigation et animations** : fluidifier les transitions et interactions sans surcharge.
5. **Statistiques** : rendre graphiques et indicateurs plus lisibles et engageants.
6. **Écrans secondaires** : finaliser import CSV, profil, états vides, erreurs et accessibilité.
7. **Validation** : mesurer les performances et tester les parcours complets.

## 7. Critères d'acceptation

- [ ] Une seule identité claire, avec **la palette actuelle inchangée** et l'orange actuel comme unique accent.
- [ ] Aucun thème sombre ou « Vivid » proposé à l'utilisateur.
- [ ] Logo, données, fonctionnalités et parcours essentiels préservés.
- [ ] Typographie, espacements, cartes, icônes et boutons cohérents entre les écrans.
- [ ] Accueil plus lisible, avec action principale immédiatement identifiable.
- [ ] Collections et modes distincts sans dépendre de nouvelles couleurs.
- [ ] Sessions de révision fluides, lisibles et stables avec contenus courts ou longs.
- [ ] Animations utiles, courtes et respectueuses des préférences d'accessibilité.
- [ ] Graphiques compréhensibles, y compris sans données.
- [ ] Import CSV et paramètres alignés sur le design system.
- [ ] Absence de sauts de layout et de blocages visibles lors des transitions courantes.
- [ ] Performances contrôlées sur appareil réel et tests essentiels validés.

## 8. Consignes d'implémentation pour Claude Code

Avant toute modification, inspecter le code Flutter de Memflow et produire :

1. Un audit des composants et écrans existants.
2. Une liste des valeurs exactes des couleurs déjà utilisées.
3. Un plan de refonte priorisé, avec fichiers concernés et risques.
4. Une proposition de design system **sans changement de palette**.

Ensuite, procéder **écran par écran**, avec des changements incrémentaux, testables et faciles à relire. Ne pas refondre la logique métier ni ajouter de nouvelles fonctionnalités sans demande explicite. Après chaque phase, vérifier la cohérence visuelle, les interactions, les tests et les performances.

**Principe directeur :** Memflow doit conserver sa personnalité claire, crème et orange, mais atteindre le niveau de finition, de cohérence et de fluidité d'une application mobile mature.
