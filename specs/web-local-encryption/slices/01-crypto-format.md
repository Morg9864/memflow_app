# Slice 01 — Format et primitives cryptographiques

## Contrat

Fournir un module pur, testable sans Flutter ni Drift, qui chiffre et déchiffre un envelope versionné.

## Politique

- AES-256-GCM ;
- IV aléatoire neuf à chaque chiffrement ;
- sel aléatoire ;
- PBKDF2-HMAC-SHA-256 avec coût versionné et benchmarké ;
- aucune clé, mot de passe ou plaintext persistant ;
- mauvais mot de passe et corruption produisent une erreur typée.

## Tests

Round-trip, mauvais mot de passe, ciphertext modifié, métadonnées modifiées, IV différent, format inconnu et limites de taille.

## Dépendance

Cette slice dépend du verdict de la Slice 00 et ne doit pas encore ouvrir la base applicative ni modifier Supabase.
