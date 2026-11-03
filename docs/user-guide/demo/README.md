# Jeu de démonstration Memflow

Ce dossier contient un jeu de cartes fictif et reproductible pour illustrer le guide utilisateur. Il ne contient aucune information d’authentification et le générateur ne se connecte à aucun backend.

## Contenu généré

`data/memflow_documentation_demo.csv` contient 153 cartes non répétitives, réparties dans neuf decks :

- **Mathématiques** : Analyse mathématique, Algèbre linéaire et Probabilités (51 cartes).
- **Informatique** : Algorithmique, Structures de données, Logique propositionnelle et Réseaux informatiques (68 cartes).
- **Langues** : Anglais et Néerlandais (34 cartes).

Les cartes comprennent les trois distracteurs obligatoires, des niveaux 1 à 4, des indices, des explications, des tags et des champs adaptés aux modes de saisie libre et texte à trous. Le jeu comprend 54 cartes avec réponse acceptée et 36 avec un trou structuré.

## Reproduire le fichier

Depuis la racine du dépôt :

```bash
python3 docs/user-guide/demo/generate_demo_csv.py
```

Le script produit un CSV UTF-8 sans BOM, séparé par des points-virgules et conforme aux 16 colonnes de `CsvImportService`. Les distracteurs sont sélectionnés de façon déterministe au sein de chaque deck.

## Charger dans Memflow

1. Vérifiez visuellement que le compte actif est le compte de démonstration.
2. Ouvrez **Importer** puis **Importer un fichier CSV**.
3. Choisissez `memflow_documentation_demo.csv` et relisez l’aperçu.
4. Vérifiez que les neuf decks apparaissent et que les champs de texte à trous sont reconnus.
5. Confirmez la restauration uniquement dans ce compte dédié. L’import ajoute les cartes au contenu existant.

Ne sélectionnez pas ce fichier depuis le compte personnel. La déconnexion de Memflow retire les données locales du compte courant; vérifiez d’abord son état de synchronisation.

## Progression de démonstration

Le générateur ne fabrique ni historique, ni dates de révision, ni statistiques. Pour montrer une progression authentique, étudiez des cartes dans l’application et utilisez les réponses **Encore**, **Difficile**, **Correct** et **Facile** comme elles reflètent réellement la réponse donnée. Les graphiques d’activité se remplissent au fil des jours. N’écrivez pas de dates historiques dans la base distante et ne modifiez pas les journaux de révision.
