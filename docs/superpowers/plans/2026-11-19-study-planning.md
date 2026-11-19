# Planning des révisions sur Flutter et le web

Design validé dans `../specs/2026-11-19-study-planning-cross-platform-design.md`.

## Contrat partagé

- `study_plans` contient `id` (UUID), `user_id` (UUID du compte), `collection_id` (texte), `deck_id` (texte nullable), `start_date` (date civile ISO YYYY-MM-DD), `weekdays` (tableau d'entiers ISO 1=lundi à 7=dimanche, vide pour un plan ponctuel), `follow_ups` (objet JSON, vide par défaut), `updated_at` (horodatage) et `deleted_at` (horodatage nullable). Une entrée de `follow_ups` associe une date d'occurrence à la date suivante choisie, strictement postérieure, ou à null. Les dates d'une chaîne ponctuelle partent de `start_date`. Utiliser un garde contre les valeurs invalides en lecture. Le choix se conserve sur la ligne du plan, y compris pour une séance clôturée sans date suivante. La suppression renseigne `deleted_at` pour signaler le changement en temps réel et empêcher une réédition hors ligne de restaurer la ligne.
- `study_preferences` contient `user_id` (UUID, clé primaire), `srs_enabled` (booléen), `updated_at` (horodatage). Une ligne absente équivaut à SRS désactivé.
- Supabase écarte les mises à jour du planning et du réglage dont l'horodatage est antérieur à la version enregistrée. Flutter récupère les journaux en suivant leur réception par Supabase (`received_at`). Les statistiques les classent par date de révision (`created_at`).
- Les jours du planning et les journaux quotidiens utilisent la convention UTC déjà utilisée pour les statistiques de MemFlow. Les récurrences commencent à start_date. Une séance passée ne gonfle pas automatiquement le compteur du lendemain.
- Les cartes actives couvertes par les occurrences du jour sont dédupliquées par ID. Une carte ayant une révision durable datée du jour est comptée une fois comme travaillée, quelle que soit la réponse. Les tentatives enregistrées déterminent le taux de réussite, absent sans tentative. Une session du planning sélectionne exclusivement les cartes encore à faire, puis applique la limite existante. La révision libre reste disponible.
- SRS désactivé, ignorer due_at pour sélectionner et présenter la charge du planning. SRS activé, compter les cartes échues du périmètre planifié et préserver les échéances SRS visibles hors du planning. Les cartes déjà travaillées aujourd'hui comptent dans l'avancement. Les réponses continuent d'alimenter le calcul SRS existant, dont les dates sont masquées en mode planning.
- Une séance ponctuelle propose J+7, une autre date strictement future ou aucune replanification, après traitement de toutes les cartes prévues. La décision s'applique à l'occurrence précise. Les séances récurrentes suivent leur prochaine date prévue.
- Les statistiques historiques restent consultables, avec filtre par deck ou collection et bilan du planning sur quatorze jours. Le bilan compte une fois chaque deck prévu pour une date et marque comme travaillé un créneau qui contient une révision enregistrée ou une décision de suivi. Distinguer progression (cartes uniques traitées) et réussite (réponses correctes).
- L'interface réutilise les composants et les styles existants, sans encoche, bande ni bloc d'accent contrastant.

## Séquence

1. Préparer une migration identique pour les deux dépôts, avec accès authentifié et contrôle des liens vers les cours du compte.
2. Flutter. Étendre Drift et sa synchronisation, puis intégrer la planification à l'accueil, aux séances, aux cours, aux échéances, aux paramètres et aux statistiques.
3. Web. Étendre le dépôt Supabase et les pages existantes, puis intégrer les mêmes entrées, compteurs, réglages et décisions.
4. Comparer les règles et les accès des deux clients, vérifier les migrations et les diagnostics de compilation locaux.
