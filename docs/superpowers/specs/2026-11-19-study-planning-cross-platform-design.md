# Planning des révisions sur l’app et le web

## Intention

Permettre à une personne de choisir les cours à travailler selon une date précise ou une récurrence, pour que la charge visible aujourd’hui corresponde à son programme réel plutôt qu’à toutes les cartes échues de l’année. Le même planning et le même comportement doivent être disponibles dans l’app Flutter (`memflow-app`) et dans l’application web (`memflow-web`).

## Objectifs

- Planifier une collection ou un deck pour une date ponctuelle ou des jours récurrents de la semaine.
- Faire du planning la source par défaut des cartes « à faire aujourd’hui »; le SRS est désactivé par défaut.
- Après une séance ponctuelle, proposer une date sept jours plus tard, permettre une autre date choisie par la personne, ou « terminé jusqu’à réattribution ».
- Ajouter dans les paramètres un réglage permettant d’activer le SRS. Quand il est activé, les échéances carte par carte sont calculées par le SRS et restent indépendantes des dates du planning.
- Aligner l’accueil, la progression quotidienne, les échéances/prochaines séances et les statistiques sur le périmètre planifié, avec la réussite calculée à partir des journaux de révision.
- Garder les données identiques et synchronisées entre l’app et le web, y compris hors ligne côté app selon le mécanisme de synchronisation existant.

## Hors périmètre

- Modifier les intervalles ou l’algorithme SRS existant.
- Remplacer ou réécrire l’historique de révision existant.
- Faire du planning un calendrier général avec rappels push ou notifications.
- Refaire les interfaces globales de l’app ou du web.

## Anti-objectifs

- Afficher par défaut l’ensemble des cartes échues de tous les cours comme charge du jour.
- Laisser croire qu’une séance ponctuelle se répétera automatiquement lorsqu’aucune récurrence n’a été choisie.
- Afficher des compteurs différents pour le même compte selon qu’il utilise l’app ou le web.

## Approches envisagées

1. **Le planning remplace la date SRS.** Chaque occurrence rend son périmètre dû et aligne la prochaine date sur le planning. Simple à comprendre, mais sans véritable mode SRS indépendant.
2. **Le planning pilote les jours de travail par défaut, avec un mode SRS optionnel.** Par défaut, une occurrence rend les cartes du cours sélectionné à faire; les séances récurrentes reviennent à la prochaine occurrence. Le réglage SRS, désactivé par défaut, laisse le SRS établir les échéances des cartes indépendamment du planning. C’est l’approche retenue par Morgan.
3. **Le planning reste une simple sélection de cours, tandis que le SRS continue à piloter tous les compteurs.** Cela préserverait davantage le comportement actuel, mais pourrait réintroduire une charge globale irréaliste.

## Comportement retenu

- Une séance peut viser une collection entière ou un deck, pour une date ou un ou plusieurs jours récurrents.
- Sans SRS, le périmètre et l’occurrence du planning déterminent la charge du jour et la prochaine révision. Une occurrence récurrente revient à sa prochaine date prévue.
- Après une séance ponctuelle, l’app et le web proposent trois suites : accepter la date suggérée (sept jours plus tard), choisir une autre date, ou terminer sans prochaine date (le cours reste terminé jusqu’à ce qu’une nouvelle date lui soit attribuée). Cette proposition est fixe et n’adapte pas son délai à la réussite des réponses; le SRS reste désactivé.
- Avec SRS activé, les dates de révision des cartes sont celles du SRS et ne sont pas déplacées pour les faire coïncider avec le planning. Le planning continue à sélectionner les cours affichés et travaillés chaque jour; les compteurs du jour restent limités à ce périmètre.
- Le taux de réussite du jour est calculé depuis les réponses enregistrées aujourd’hui dans le périmètre prévu. Les statistiques historiques conservent les journaux existants et peuvent être filtrées par collection/deck; elles ajoutent un bilan des séances planifiées et réalisées.
- Les nombres de cartes et les échéances affichés dans les listes, l’accueil, les pages de cours et les statistiques doivent employer les mêmes règles de périmètre et de mode SRS.
- Au premier lancement après mise à jour, si aucun planning n’existe, l’accueil guide la personne pour en créer un et n’affiche pas l’ancien total annuel comme charge quotidienne.
- Les plans et le réglage SRS sont des données du compte, partagées entre app et web. L’app doit conserver les changements localement quand elle est hors ligne puis les synchroniser.

## Contraintes et appels d’implémentation

- Flutter utilise Drift et une synchronisation locale Supabase; le web lit et écrit directement dans Supabase. Les deux clients maintiennent des copies des migrations SQL et doivent partager le même modèle de données et la même sémantique.
- Le SRS actuel conserve intervalle, répétitions et date d’échéance par carte. Le mode par défaut fondé sur les séances ne doit pas détruire ces informations, afin qu’activer le SRS puisse réutiliser l’historique conservé.
- Les collections/decks désactivés restent exclus, comme dans les sessions actuelles.
- Respecter la préférence persistante : ne pas ajouter de bande, encoche ou bloc d’accent contrastant nettement délimité dans l’interface.
- Le concepteur doit choisir la représentation locale et distante des occurrences, la stratégie de résolution des chevauchements, les règles de fuseau horaire et les détails d’interface dans les deux clients, en conservant le comportement décrit ci-dessus.

## Critères d’acceptation

- Une date ponctuelle et une récurrence hebdomadaire peuvent être créées, modifiées et supprimées dans les deux clients.
- Une personne sans planning voit une invitation à planifier plutôt que le total de toutes les cartes échues.
- Une occurrence planifiée ne compte qu’une fois, même si plusieurs plans couvrent le même deck et le même jour.
- Une séance ponctuelle terminée propose une date sept jours plus tard et permet de l’accepter, de choisir une date personnalisée ou de ne pas programmer de date suivante.
- SRS désactivé par défaut : les cartes du périmètre planifié forment la charge de l’occurrence.
- SRS activé : les échéances par carte restent issues du SRS; la charge d’un jour ne sort pas des cours sélectionnés dans le planning.
- L’accueil, les compteurs de collection/deck, l’indicateur de progression, la prochaine révision et les statistiques suivent les mêmes règles dans Flutter et le web.
- Les réglages et plannings synchronisés restent associés au bon compte, y compris après déconnexion/reconnexion et lors d’une utilisation hors ligne de l’app.
- Les changements de l’algorithme existant, l’historique passé et les résultats de réussite ne sont pas altérés.
