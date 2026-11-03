# Rapport qualité — Guide d’utilisation Memflow

**Version documentée :** Memflow 2.4.0<br>
**Date de référence :** 3 novembre 2026<br>
**Appareil :** Samsung SM-X406B, Android 16, API 36, 1320 × 2112 px<br>
**Application Android :** `com.memflow.app.memflow`

## Compte et protection des données

- Avant la déconnexion de l’ancien compte, le profil affichait l’état « Synchronisé ». L’utilisateur a ensuite autorisé explicitement le changement de session. La déconnexion a suivi le parcours normal de l’application ; aucun stockage n’a été effacé manuellement et aucune application tierce n’a été touchée.
- Le compte de démonstration « Camille Martin » a été créé depuis le formulaire normal de l’application avec l’adresse dédiée fournie par l’utilisateur. L’identité du compte actif a été vérifiée dans le profil. L’application n’a pas demandé d’étape de confirmation email pendant ce parcours ; aucune vérification externe de boîte de réception n’est revendiquée.
- Le nom fictif est conservé dans les visuels. L’adresse email réellement fournie pour le compte est masquée dans les captures de profil et paramètres. Aucune donnée d’authentification ou aucun secret n’est inclus dans le dépôt ou le guide.
- Les interactions de cette mission ont eu lieu dans le compte de démonstration. Aucune carte, statistique ou donnée distante du compte personnel n’a été modifiée intentionnellement. La déconnexion normale a retiré de la tablette les données locales de l’ancienne session comme prévu par l’application.

## Données de démonstration

- Le CSV généré contient 153 cartes pédagogiques dans neuf decks et trois collections : Analyse mathématique, Algèbre linéaire, Probabilités, Algorithmique, Structures de données, Logique propositionnelle, Réseaux informatiques, Anglais et Néerlandais.
- L’aperçu intégré à Memflow a détecté 153 cartes, zéro ligne invalide, un séparateur point-virgule et une ligne d’en-tête. Le jeu a été importé une fois depuis le compte démo, après lecture du dialogue de confirmation.
- Le jeu fournit les champs nécessaires aux modes visibles. Le vérificateur local qui appelle le parseur de l’application a reconnu 153 cartes sans erreur ; les modes compatibles ont été contrôlés par le service de modes du projet.
- Une session réelle de 12 cartes en mode QCM a été achevée dans le deck Algorithmique. Les 12 réponses enregistrées ont reçu l’évaluation « Correct ». L’accueil montre ensuite 141 cartes à revoir et 12 cartes faites sur 68 dans Informatique ; les autres collections restent non étudiées.
- Les statistiques couvrent la journée de la capture (une série d’un jour). Aucun historique multi-jour ou horodatage antérieur n’a été ajouté. Le taux de réussite affiché reflète la session effectivement enregistrée, et non des données fabriquées.

## Écrans et parcours observés

Vérifiés sur la tablette avec le compte démo :

- Accueil et rail latéral : collections, cartes à revoir, recherche, progression et démarrage d’étude.
- Détail de la collection Informatique et progression de ses quatre decks.
- Menu « Options du deck » puis « Voir les cartes » ; liste paginée des questions et réponses.
- Sélecteur présentant les six modes et le nombre de cartes compatibles.
- Une session QCM : énoncé, sélection d’une réponse, correction, autoévaluation et bilan final.
- Statistiques après la session : cartes vues, taux de réussite, activité journalière, niveaux et progression de collection.
- Import CSV : sélecteur Android, aperçu du fichier de démonstration, nombre de cartes détectées et options avancées.
- Profil et paramètres du compte, avec statut « Synchronisé », objectif quotidien et limite de cartes par session.

Les interactions destructives (suppression de carte, deck, collection ou compte) n’ont pas été exécutées. Les flux de création et de connexion ont été lus dans l’interface et recoupés dans le code ; aucune nouvelle inscription, réinitialisation de mot de passe ou confirmation email n’a été testée en boîte de réception.

## Captures

- Douze captures sont stockées dans `assets/screenshots/originals/` et leurs versions annotées dans `assets/screenshots/annotated/`.
- Toutes proviennent de Memflow en fonctionnement sur le Samsung SM-X406B, capturées par ADB à la résolution native, en portrait. Elles couvrent l’accueil, la collection, la liste de cartes, les modes, une question, la correction, le bilan, les statistiques, l’aperçu CSV, les options avancées, le profil et les paramètres.
- Les deux vues de compte remplacent l’email par « adresse masquée ». Les fichiers bruts de ces deux captures ne sont pas conservés dans le dépôt. Les autres captures montrent uniquement le contenu fictif du compte démo.
- Les captures sont intégrées aux chapitres Collections et cartes, Réviser ses cartes, Importer et exporter, Suivre sa progression, Profil et paramètres et Tutoriels.

## PDF et contrôle visuel

- Le PDF conserve la couverture, les couleurs, les polices Lora et Outfit, les marges et l’identité de l’édition approuvée. Les ajouts sont des pages illustrées ciblées.
- L’édition finale comprend 23 pages A4. Le sommaire contient douze liens internes vers les chapitres, et les signets de navigation ont été vérifiés dans le PDF.
- La génération utilise ReportLab ; les captures sont préparées avec Pillow. La table des matières et les signets restent générés depuis les titres de chapitre.
- Après génération, le PDF a été rendu page par page en PNG et chaque page a été inspectée visuellement. Les captures et pages nouvellement ajoutées ont également été examinées à plus grande échelle.
- Les liens internes, l’ordre des pages, les en-têtes et pieds de page, les numéros, les légendes, les marges, l’échelle des images, les coupures et le texte extrait ont été contrôlés.
- La recherche des éléments sensibles dans les captures livrées ne doit retrouver aucune adresse email. Le contrôle doit être relancé après chaque régénération.

## Limites restantes

- Une seule journée d’activité est présente ; la progression multi-jour et les graphiques historiques ne peuvent donc pas être montrés sans laisser le temps à l’historique de se constituer naturellement.
- L’unique session enregistrée a obtenu 12 évaluations « Correct ». Les catégories « Encore », « Difficile » et « Facile » n’ont pas été simulées pour fabriquer des résultats variés ; les indicateurs de difficulté ne sont donc pas représentatifs d’un usage prolongé.
- L’inscription n’a pas déclenché de demande de confirmation email dans l’interface observée. La réception d’emails, le flux de confirmation sur une configuration qui l’exigerait et les liens de réinitialisation restent à vérifier avec l’accès à la boîte dédiée.
- Les captures représentent l’orientation portrait de la tablette de référence. Les variantes paysage, les tailles de texte extrêmes et d’autres modèles n’ont pas été recapturés durant cette mise à jour.
- Les interactions d’ajout, de modification et de suppression directe de cartes ne sont pas décrites comme disponibles ; la version observée expose l’import et la suppression avec confirmation depuis la liste.
