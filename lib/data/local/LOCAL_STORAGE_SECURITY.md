# Sécurité du stockage local

## État implémenté

MemFlow utilise Drift avec `drift_flutter` :

- sur les plateformes natives, `driftDatabase` ouvre `memflow.sqlite` avec
  `NativeDatabase` et la bibliothèque SQLite standard fournie par
  `package:sqlite3` ;
- sur le Web, Drift charge `web/sqlite3.wasm`, qui est également la build
  SQLite standard ;
La base persistante native est maintenant ouverte avec SQLite3MultipleCiphers,
sélectionné par `hooks.user_defines`, puis protégée par `PRAGMA key` avant que
Drift n'exécute ses migrations. Une clé aléatoire de 256 bits est générée une
fois par installation et stockée par `flutter_secure_storage` (KeyStore
Android / Keychain Apple). Elle n'est jamais écrite dans SQLite, les
préférences ou le dépôt.

L'ouverture de la base est asynchrone et terminée dans le bootstrap avant le
lancement de l'interface. La même clé, qui est une donnée sérialisable, est
transmise au callback exécuté dans l'isolate Drift. Les fichiers SQLite en
clair créés par les anciennes versions sont convertis avec `PRAGMA rekey` avant
l'ouverture chiffrée ; en cas d'échec de lecture préalable, le fichier n'est
pas modifié.

Le Web reste volontairement sur `sqlite3.wasm` standard : son stockage n'est
pas chiffré au niveau SQLite. La protection annoncée ici concerne Android et
iOS (ainsi que les autres plateformes natives qui embarquent la build
SQLite3MultipleCiphers).

La suppression du trousseau, la réinstallation de l'application ou un appareil
réinitialisé rendent la base chiffrée irrécupérable sans sauvegarde exportée,
ce qui est le comportement attendu d'une clé par installation.
