# Protection locale Web

## Objectif

Protéger au repos les données locales Web avec un mot de passe distinct du compte Supabase, AES-GCM et Web Crypto. Cette V1 ne fournit pas de chiffrement de bout en bout côté serveur.

## Invariant d’architecture

Une seule autorité possède le coffre Web : elle garde la clé uniquement en mémoire, ouvre Drift seulement après déverrouillage et suspend la synchronisation lorsqu’il est verrouillé. Le SQLite WASM persistant actuel ne doit plus recevoir de nouvelles données après migration réussie.

La protection ne couvre pas XSS, extension compromise, navigateur compromis ou données déjà déchiffrées en mémoire. Supabase conserve son modèle actuel.

## Découpage

- [Slice 00](slices/00-persistence-spike.md) — prouver une persistance de coffre chiffrée et atomique.
- [Slice 01](slices/01-crypto-format.md) — format versionné et primitives Web Crypto.
- Slice 02 — machine d’état du coffre et session mémoire.
- Slice 03 — migration de l’ancien stockage Drift Web.
- Slice 04 — bootstrap, providers, routage et suspension de sync.
- Slice 05 — UX setup/unlock/lock/change-password.
- Slice 06 — durcissement, sauvegarde chiffrée et tests navigateur.

## État actuel

Voir l’[état du stockage local](../../lib/data/local/LOCAL_STORAGE_SECURITY.md).
La faisabilité du coffre Web reste à démontrer : la Slice 00 est ouverte,
sans preuve navigateur de restauration ni de persistance chiffrée atomique.

## Sources techniques

- [Drift Web](https://drift.simonbinder.eu/platforms/web/)
- [Web Crypto API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Crypto_API)
- [`SubtleCrypto.deriveKey`](https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/deriveKey)

## Prochaine étape

Exécuter les vérifications de la [Slice 00](slices/00-persistence-spike.md)
dans un navigateur réel et consigner le verdict ici avant de poursuivre.
Le format de snapshot et l’interface de persistance dépendent de ce résultat.
