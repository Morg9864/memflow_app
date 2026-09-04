# Sécurité du stockage local

## État audité

MemFlow utilise Drift avec `drift_flutter` :

- sur les plateformes natives, `driftDatabase` ouvre `memflow.sqlite` avec
  `NativeDatabase` et la bibliothèque SQLite standard fournie par
  `package:sqlite3` ;
- sur le Web, Drift charge `web/sqlite3.wasm`, qui est également la build
  SQLite standard ;
- `sqlcipher_flutter_libs` apparaît dans le lockfile comme dépendance
  transitive historique de `drift_flutter`, mais n'est pas configuré comme
  bibliothèque d'exécution et ne chiffre donc pas la base.

La base persistante actuelle n'est pas chiffrée au niveau SQLite. Les tests
avec `AppDatabase.memory()` ne permettent pas de conclure à un chiffrement
du fichier persistant.

## Pourquoi le chiffrement n'est pas activé ici

La version actuelle de `package:sqlite3` sait charger SQLite3MultipleCiphers
via un `hooks.user_defines` (`source: sqlite3mc`) et Drift expose bien un
callback `setup` pour exécuter `PRAGMA key`. Cela rend le moteur disponible,
mais pas l'intégration complète et sûre de MemFlow :

1. La clé doit être générée par installation et conservée dans le trousseau
   natif (`flutter_secure_storage`), jamais dans SQLite, les préférences
   ordinaires, le dépôt ou une constante compilée.
2. La connexion Drift est créée avant l'authentification et peut être ouverte
   dans un isolate. Il faut donc résoudre la clé de manière asynchrone puis
   la transmettre explicitement à chaque isolate avant l'ouverture SQLite.
3. Les installations existantes possèdent potentiellement un fichier SQLite
   en clair. Ajouter `PRAGMA key` ne le convertit pas : sans migration
   contrôlée (sauvegarde, ouverture en clair, `rekey`, validation puis
   remplacement atomique), l'application peut perdre l'accès aux données.
4. Le Web actuel charge `sqlite3.wasm`, pas `sqlite3mc.wasm`. Activer seulement
   le natif créerait une garantie différente selon la plateforme. La variante
   WASM chiffrée est expérimentale et nécessite aussi une stratégie de clé
   adaptée au stockage navigateur.

Pour ces raisons, aucun `PRAGMA key` factice, clé codée en dur, chiffrement
applicatif incomplet ou dépendance décorative n'a été ajouté.

## Préparation requise pour une implémentation future

Avant d'activer cette fonctionnalité, il faudra une tranche dédiée qui :

- ajoute et configure le trousseau natif avec une politique de suppression /
  réinstallation explicitement décidée ;
- sélectionne SQLite3MultipleCiphers sur les plateformes supportées ;
- implémente une migration des bases en clair avec remplacement atomique et
  récupération en cas d'échec ;
- définit séparément la politique Web (WASM chiffré expérimental ou absence
  explicitement assumée) ;
- teste réellement les octets du fichier : absence d'en-tête SQLite et de
  marqueur en clair, réouverture avec la bonne clé, échec avec une mauvaise
  clé, et migration d'une base existante.
