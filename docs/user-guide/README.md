# Guide utilisateur Memflow

Guide officiel en français pour Memflow sur tablette Android. Cette édition décrit Memflow 2.4.0 et conserve la maquette éditoriale approuvée.

## Contenu

- `output/Memflow_Guide_Utilisateur.pdf` : édition PDF prête à distribuer.
- `source/build_pdf.py` : texte, styles existants, navigation interne et génération PDF.
- `source/prepare_screenshots.py` : préparation des captures ADB, annotations cohérentes avec la charte et masquage de l’adresse du compte démo.
- `assets/branding/` : logo Memflow issu du projet.
- `assets/screenshots/originals/` : captures authentiques de Memflow sur la tablette, protégées contre l’exposition de l’adresse email.
- `assets/screenshots/annotated/` : captures annotées utilisées dans le document.
- `demo/` : jeu CSV fictif, générateur et vérificateur compatible avec le parseur de l’application.
- `DOCUMENTATION_MAINTENANCE.md` : méthode de mise à jour.
- `QA_REPORT.md` : vérifications réellement effectuées et limites.

## Régénérer le PDF

Depuis la racine du dépôt, avec Python 3, ReportLab, Pillow, les polices Outfit et Lora du projet et Poppler disponibles :

```bash
python3 docs/user-guide/source/prepare_screenshots.py
python3 docs/user-guide/source/build_pdf.py
```

Le premier script attend les captures temporaires listées dans son dictionnaire `captures` sous `/tmp`. Après avoir suivi `DOCUMENTATION_MAINTENANCE.md` et repris des captures réelles avec ADB, adaptez leurs noms dans ce script. Il supprime les anciennes images du dossier `originals/` et `annotated/` avant de les remplacer ; vérifiez son dictionnaire avant exécution. L’adresse email du compte démo est remplacée par la mention « adresse masquée ».

## Mettre à jour le jeu de démonstration

Pour régénérer le CSV fictif puis vérifier son format avec le parseur réel de l’application :

```bash
python3 docs/user-guide/demo/generate_demo_csv.py
dart run docs/user-guide/demo/verify_demo_csv.dart
```

Le CSV est destiné à l’import depuis un compte de démonstration isolé. Relisez l’aperçu dans l’application avant de confirmer une restauration. Le générateur n’accède à aucun backend et ne crée aucun historique artificiel.

## Rendre et contrôler le PDF

```bash
pdftoppm -png -r 120 docs/user-guide/output/Memflow_Guide_Utilisateur.pdf /tmp/memflow-guide-page
pdfinfo docs/user-guide/output/Memflow_Guide_Utilisateur.pdf
```

Rendez toutes les pages et inspectez-les visuellement après chaque modification. Contrôlez également le sommaire, les signets, les numéros de page, les légendes et l’absence de données privées. Supprimez les fichiers temporaires après vérification.
