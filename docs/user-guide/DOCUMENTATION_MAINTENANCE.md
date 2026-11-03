# Maintenance du guide utilisateur

## Principe

Décrire les comportements disponibles dans la version réellement observée. Pour chaque changement d’interface, recouper les libellés et les règles dans le projet, puis parcourir le flux sur une tablette Android avec un compte de démonstration isolé. Ne pas présenter une fonctionnalité planifiée ou cachée comme disponible.

## Repérer les chapitres et captures à revoir

| Changement dans Memflow | Contenu à vérifier |
|---|---|
| Routes, destinations ou libellés de navigation | Chapitre 3 ; capture `accueil-demo-annote.png` |
| Collections, decks, tri, recherche ou gestion | Chapitre 4 ; captures `collection-demo-annote.png` et `cartes-algorithmique-annote.png` |
| Modes, correction, échéances ou bilan de révision | Chapitres 5 et 9 ; captures `modes-session-annote.png`, `question-qcm-annote.png`, `correction-qcm-annote.png` et `bilan-session-annote.png` |
| Format CSV/TXT, aperçu, import, restauration ou ressources avancées | Chapitres 6 et 9 ; captures `import-apercu-demo-annote.png` et `import-avance-demo-annote.png` |
| Indicateurs, périodes ou graphiques statistiques | Chapitre 7 ; capture `statistiques-demo-annote.png` |
| Profil, synchronisation, export ou objectif quotidien | Chapitre 8 ; capture `profil-demo-annote.png` |
| Authentification, compte, mot de passe ou limite de session | Chapitres 2 et 8 ; capture `parametres-demo-annote.png` |
| Terminologie nouvelle ou modifiée | Guide entier, sommaire et glossaire |
| Thème, couleurs, polices, rayons ou identité visuelle | PDF entier, couverture, styles et légendes |
| Version de l’application ou Android minimum | Couverture, pied de page et rapport QA |

## Parcours de mise à jour

1. Relever la version de Memflow et les changements visibles dans les routes, textes d’interface, modèles et règles produit.
2. Comparer les libellés et les actions avec le texte de `source/build_pdf.py` ; vérifier les dialogues, confirmations, états vides et erreurs concernés.
3. Utiliser un compte de démonstration distinct. Avant tout changement de session sur une tablette partagée, vérifier la synchronisation du compte déjà ouvert et obtenir l’autorisation du propriétaire. Ne pas effacer le stockage de l’application.
4. Capturer les nouveaux états avec ADB, directement sur la tablette. Garder les captures brutes en temporaire uniquement ; ne jamais publier une adresse email, un identifiant ou un autre élément privé.
5. Mettre à jour le dictionnaire de captures et les masques ciblés dans `source/prepare_screenshots.py`. Le script remplace les PNG des dossiers `originals/` et `annotated/` ; vérifier les fichiers sources avant son exécution.
6. Mettre à jour les figures, légendes et instructions dans `source/build_pdf.py`. Garder la charte et la mise en page approuvées, et réutiliser les mêmes styles.
7. Si le format du jeu de démonstration change, régénérer `demo/data/memflow_documentation_demo.csv` puis le vérifier avec le service d’import de l’application via `demo/verify_demo_csv.dart`.
8. Régénérer le PDF, convertir toutes ses pages en PNG et inspecter chaque page. Contrôler le sommaire cliquable, les signets, les pieds de page, les coupures, les images, les annotations et l’absence de données privées.
9. Mettre à jour `QA_REPORT.md` en distinguant les parcours réellement observés sur tablette, les règles établies par les sources et les limites restantes.

## Captures utilisées par le préparateur

Les fichiers temporaires attendus (captures ADB 1320 × 2112 px en orientation portrait) figurent directement dans le dictionnaire `captures` de `source/prepare_screenshots.py`. Les noms actuels couvrent l’accueil, la collection, la liste de cartes, le choix de mode, l’énoncé, la correction, le bilan, les statistiques, l’aperçu d’import, les options avancées, le profil et les paramètres. Les captures de profil et de paramètres ont un masquage dédié pour l’adresse du compte fictif.

La préparation des captures et la génération du PDF se lancent depuis la racine du dépôt :

```bash
python3 docs/user-guide/source/prepare_screenshots.py
python3 docs/user-guide/source/build_pdf.py
pdftoppm -png -r 120 docs/user-guide/output/Memflow_Guide_Utilisateur.pdf /tmp/memflow-guide-page
```

## Données du compte démo

Le CSV et son générateur sont dans `demo/`. L’import doit être réalisé depuis ce compte uniquement, après vérification visuelle de son identité. L’historique de révision doit venir d’interactions effectives dans l’application. Ne pas fabriquer de dates passées ni modifier directement la base distante ou les règles de planification. Documenter le nombre de jours réellement observé.

## Critères de publication

- Chaque action citée et chaque libellé correspondent à la version observée.
- Les captures montrent l’application réelle et correspondent à la procédure.
- Aucun email ou renseignement personnel n’est lisible dans les PNG, le PDF, les textes alternatifs ou le rapport.
- Les annotations restent cohérentes, discrètes et correctement placées.
- Toutes les pages du PDF sont inspectées après la dernière modification.
- Le rapport QA ne transforme pas une vérification par source en vérification réelle sur tablette.
