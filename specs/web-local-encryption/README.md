# Protection locale Web

## Objectif

Protéger au repos les données locales Web avec un mot de passe distinct du compte Supabase, AES-GCM et Web Crypto. Cette V1 ne fournit pas de chiffrement de bout en bout côté serveur.

## Invariant d’architecture

Une seule autorité possède le coffre Web : elle garde la clé uniquement en mémoire, ouvre Drift seulement après déverrouillage et suspend la synchronisation lorsqu’il est verrouillé. Le SQLite WASM persistant actuel ne doit plus recevoir de nouvelles données après migration réussie.

La protection ne couvre pas XSS, extension compromise, navigateur compromis ou données déjà déchiffrées en mémoire. Supabase conserve son modèle actuel.

## Découpage

- Slice 00 — prouver une persistance de coffre chiffrée et atomique.
- Slice 01 — format versionné et primitives Web Crypto.
- Slice 02 — machine d’état du coffre et session mémoire.
- Slice 03 — migration de l’ancien stockage Drift Web.
- Slice 04 — bootstrap, providers, routage et suspension de sync.
- Slice 05 — UX setup/unlock/lock/change-password.
- Slice 06 — durcissement, sauvegarde chiffrée et tests navigateur.

## État actuel

Le stockage natif est déjà chiffré via SQLite3MultipleCiphers. Le Web utilise
encore SQLite WASM standard pour l’application. Un spike isolé de
snapshot/restauration a été ajouté dans
`lib/data/local/connection/web_snapshot_probe.dart`, mais il n’est pas encore
branché au bootstrap.

## Sources techniques

- [Drift Web](https://drift.simonbinder.eu/platforms/web/)
- [Web Crypto API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Crypto_API)
- [`SubtleCrypto.deriveKey`](https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/deriveKey)

## Prochaine étape

Terminer la Slice 00 avec un test navigateur réel du spike : base WASM en
mémoire, export/restauration, puis validation de l’écriture atomique d’un
envelope chiffré dans IndexedDB/OPFS. Ne modifier ni les providers ni l’UX
avant ce verdict.

## TODO global

- [ ] Slice 00 : spike ajouté, gate navigateur et adaptateur atomique à valider.
- [ ] Slice 01 : AES-GCM/PBKDF2, format et tests de corruption.
- [ ] Slice 02 : `WebVault`, états locked/unlocked et clé en mémoire.
- [ ] Slice 03 : migration sans suppression prématurée de l’ancien stockage.
- [ ] Slice 04 : bootstrap, providers et sync conditionnelle.
- [ ] Slice 05 : écrans, auto-lock et changement de mot de passe.
- [ ] Slice 06 : durcissement, CSP, quota, multi-onglets et documentation.

## Next Agent Prompt

Tu reprends la protection locale Web. Commence par la Slice 00 et prouve la frontière de persistance avec un test navigateur réel ou un spike isolé. Ne branche pas encore l’UI. Mets à jour ce README avec le verdict, les limites découvertes et la prochaine slice avant de terminer.
