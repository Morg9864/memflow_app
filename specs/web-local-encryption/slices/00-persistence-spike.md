# Slice 00 — Spike de persistance chiffrée Web

## Contrat

Prouver qu’une base Drift/SQLite WASM peut fonctionner en mémoire, être sérialisée/restaurée sans perte, puis être stockée sous forme d’envelope chiffré dans le stockage navigateur.

## Seam

```dart
abstract interface class WebVaultPersistence {
  Future<EncryptedEnvelope?> read();
  Future<void> write(EncryptedEnvelope envelope);
  Future<void> delete();
}
```

Le spike peut utiliser un export JSON canonique versionné si l’export binaire SQLite n’est pas fiable. Il doit inclure les données, `app_meta_entries` et `sync_queue_entries`.

## Vérifications

- round-trip dans une nouvelle base ;
- écriture atomique et reprise après interruption simulée ;
- aucun texte connu dans IndexedDB/OPFS ;
- mesure de taille et durée pour un jeu de cartes réaliste ;
- comportement quota et données absentes ;
- aucun changement de bootstrap ou d’UX dans cette slice.

## Verdict

Si le snapshot SQLite est fragile ou trop coûteux, retenir l’export JSON canonique pour la suite et documenter ce choix dans le README.
