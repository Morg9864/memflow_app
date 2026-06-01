# Prompt CSV Memflow

À partir du document fourni et en respectant strictement la structure du fichier CSV détaillés plus loin dans le prompt, génère un nouveau fichier CSV complet, propre et directement importable dans Memflow.

## Objectif

Transformer le contenu du document en une banque de questions d'apprentissage actif.

Le but n'est pas de résumer le document, mais de créer un maximum de questions utiles pour mémoriser, comprendre et réviser efficacement l'ensemble du contenu.

## Analyse du document

Analyse le document dans son intégralité, section par section, sans ignorer de partie importante.

Crée des questions pour couvrir :

- les définitions importantes ;
- les concepts clés ;
- les distinctions entre notions proches ;
- les listes et classifications ;
- les étapes, processus ou méthodes ;
- les conditions d'utilisation ou d'application ;
- les exceptions ou limites ;
- les conséquences importantes ;
- les exemples significatifs ;
- les dates, noms, termes techniques ou références utiles ;
- les formules, règles, calculs ou relations importantes s'il y en a ;
- les idées explicitement mises en avant dans le document.

Aucune partie importante du document ne doit rester sans question.

## Construction des questions

Les questions doivent être :

- claires ;
- précises ;
- courtes ;
- formulées simplement ;
- centrées sur une seule idée à la fois.

Il faut privilégier plusieurs petites questions ciblées plutôt qu'une seule question trop large.

Exemple de mauvaise question :

> Explique tout le fonctionnement du système présenté dans le chapitre.

Exemple de bonnes questions :

> Quel est l'objectif principal du système présenté ?
>
> Quelle est la première étape de son fonctionnement ?
>
> Quelle limite importante est associée à ce système ?

## Niveau de détail attendu

Pour chaque notion importante, crée plusieurs types de questions lorsque c'est pertinent :

- question de définition ;
- question de compréhension ;
- question sur une condition ;
- question sur une exception ;
- question de comparaison ;
- question d'application simple ;
- question de mémorisation directe.

Lorsqu'une liste contient plusieurs éléments :

1. crée une question globale sur la liste ;
2. crée une question individuelle pour chaque élément ;
3. crée, si utile, une question de comparaison entre certains éléments.

## Réponses attendues

La réponse correcte doit être :

- exacte ;
- concise ;
- complète pour la question posée ;
- basée uniquement sur le document fourni.

N'ajoute aucune information externe au document.

## Faux choix

Pour chaque question, crée 3 mauvaises réponses crédibles.

Les mauvaises réponses doivent :

- être plausibles ;
- rester proches du thème de la question ;
- éviter les absurdités évidentes ;
- tester réellement la compréhension.

Attention sur un point : Les mauvaises réponses doivent faire plus ou moins la même longueur que la bonne réponse. Trop souvent, les mauvaises réponses sont trop courtes, ce qui rend facilement la bonne réponse identifiable. Il faut veiller à ce que les mauvaises réponses soient aussi longues que la bonne réponse, pour éviter de donner un indice involontaire.

## Indice

L'indice doit aider sans donner directement la réponse.

Il doit être court, clair et utile, tout en restant suffisamment vague pour encourager la réflexion. 

Si la question est de difficulty facile (soit level 1), l'indice doit être "-". Les niveaux supérieurs doivent avoir un indice plus informatif, mais sans jamais révéler la réponse, ni donner une partie de la réponse. 

Exemple mauvais indice : 

> Question : Qu'est-ce qu'une obligation en droit civil ? Hint : C'est un lien juridique entre deux personnes.

Exemple bon indice :

> Question : Qu'est-ce qu'une obligation en droit civil ? Hint : Revois la définition d'une obligation.


## Explication

L'explication doit :

- justifier la bonne réponse ;
- clarifier brièvement la notion ;
- rester fidèle au document ;
- faire idéalement entre 2 et 5 phrases.

## Texte à trou

Quand c'est pertinent, crée aussi un vrai texte à trous utile pour réviser la même information sous une autre forme.

Ne crée pas mécaniquement un texte à trous pour chaque question si cela donne une phrase artificielle ou peu pédagogique. Le texte à trous doit être naturel, clair et réellement utile à mémoriser.

Le mode texte à trous de Memflow fonctionne avec :

- `cloze_text` : la phrase à compléter ;
- `cloze_answers` : les bonnes réponses, dans l'ordre des trous ;
- `cloze_word_bank` : la banque de mots affichée à l'utilisateur, contenant les bonnes réponses et des distracteurs plausibles.

Règles de qualité pour les textes à trous :

- privilégie en général 1 à 3 trous par texte ;
- fais porter les trous sur les éléments discriminants : notions, dates, termes techniques, conditions, exceptions, étapes clés ;
- évite de trouer des articles, prépositions, auxiliaires ou mots-outils ;
- évite les phrases bancales ou simplement copiées puis mutilées ;
- évite les trous ambigus où plusieurs options pourraient convenir ;
- la banque de mots doit être crédible, homogène en longueur et en registre ;
- les distracteurs doivent être plausibles, mais ne pas rendre la phrase absurde ;
- chaque option de `cloze_word_bank` doit pouvoir remplacer le trou en produisant une phrase grammaticalement correcte ;
- les distracteurs doivent être du même type grammatical que la bonne réponse : si le trou attend un groupe nominal, une date, un verbe à l'infinitif, une condition ou une expression figée, toutes les options doivent suivre ce même format ;
- harmonise la forme des options d'une même banque : article ou non, singulier ou pluriel, genre, niveau de précision et casse initiale ;
- n'utilise jamais la casse comme indice involontaire : si la bonne réponse apparaît en minuscule dans la phrase, les distracteurs ne doivent pas la trahir par une majuscule initiale, sauf contrainte intrinsèque impossible à éviter ;
- avant de valider une bank, remplace mentalement le trou par chaque option et supprime toute proposition qui donne une phrase syntaxiquement cassée, sémantiquement incohérente ou manifestement hors cadre ;
- `cloze_answers` doit reprendre exactement les bonnes réponses dans l'ordre des trous ;
- `cloze_word_bank` doit contenir toutes les bonnes réponses, plus quelques distracteurs plausibles.

Le trou doit être indiqué avec le format suivant :

`{{réponse attendue}}`

Exemple :

Question :

> Quel est le rôle principal de la mémoire cache ?

Texte à trou :

> La mémoire cache sert principalement à {{accélérer l'accès aux données fréquemment utilisées}}.

Exemple avec plusieurs trous :

> React, le hook {{useState}} retourne une valeur actuelle et une fonction pour la {{modifier}}.

Dans ce cas :

- `cloze_answers` = `useState|modifier`
- `cloze_word_bank` = `useState|useEffect|afficher|modifier`

## Difficulté

Attribue une difficulté cohérente :

- facile : définition simple, fait isolé ou information directe ;
- moyen : mécanisme, relation entre concepts ou explication en plusieurs éléments ;
- avancé : comparaison, exception, raisonnement ou application plus complexe.

## Format CSV

Respecte strictement les colonnes du décrites ci-dessous, dans le même ordre, avec les mêmes intitulés.

Colonnes à respecter :

- collection
- deck
- question
- correct_answer
- wrong_answer_1
- wrong_answer_2
- wrong_answer_3
- hint
- explanation
- level
- difficulty
- tags
- source
- cloze_text
- accepted_answers
- cloze_answers
- cloze_word_bank

Le fichier final doit être un vrai CSV importable, sans texte avant ni après.

## Règles strictes

- Ne pas inventer d'information.
- Ne pas utiliser d'informations externes.
- Ne pas créer de doublons inutiles.
- Ne pas faire de questions trop vagues.
- Ne pas laisser de champ vide.
- Respecter exactement le format CSV décrit.
- Générer le plus grand nombre possible de questions utiles.
- Privilégier la couverture complète du document plutôt que des questions superficielles.

Règles strictes spécifiques au texte à trous :

- si `cloze_text` est rempli, alors `cloze_answers` et `cloze_word_bank` doivent aussi être remplis ;
- `cloze_answers` doit contenir exactement autant d'éléments qu'il y a de trous dans `cloze_text` ;
- `cloze_word_bank` doit contenir toutes les bonnes réponses et quelques distracteurs plausibles ;
- chaque entrée de `cloze_word_bank` doit être grammaticalement compatible avec l'emplacement du trou ;
- aucune entrée de `cloze_word_bank` ne doit rendre la phrase absurde juste par sa forme ; elle doit être plausible comme complétion, même si elle reste factuellement fausse ;
- les distracteurs d'une même bank doivent être formatés comme la bonne réponse, sans indice de casse, d'article ou de structure grammaticale ;
- ne mets pas plusieurs fois inutilement le même mot dans `cloze_word_bank`.

## Critère de réussite

Le CSV est réussi si une personne qui maîtrise toutes les questions générées peut comprendre, mémoriser et restituer l'essentiel du document, même si les questions sont posées sous une autre forme.

## Exemple format (pour un cours de droit)

Droit des contrats informatiques;Chapitre 1 — Droit des obligations et des contrats;Le droit des obligations est une branche de quel droit ?;Le droit civil;Le droit pénal;Le droit administratif;Le droit commercial;-;Le droit des obligations est une branche du droit civil.;1;facile;obligation|droit-civil;Chapitre 1 — Droit des obligations et des contrats;Le droit des obligations est une branche du {{droit civil}}.;le droit civil|droit civil;droit civil;droit civil|droit pénal|droit administratif|droit commercial

Droit des contrats informatiques;Chapitre 1 — Droit des obligations et des contrats;En droit civil, qu'est-ce qu'une obligation ?;Un lien juridique entre deux personnes (créancier et débiteur);Une sanction pénale imposée par un juge;Un droit de propriété sur un bien;Une obligation fiscale envers l'État;Revois la définition d'une obligation.;Une obligation est un lien juridique entre un créancier et un débiteur, par lequel le débiteur s'engage à faire, ne pas faire ou donner quelque chose au créancier.;3;avancé;obligation|definition;Chapitre 1 — Droit des obligations et des contrats;Une obligation est un {{lien juridique}} entre un {{créancier}} et un {{débiteur}}.;Un lien juridique entre deux personnes (créancier et débiteur)|Un lien juridique entre un créancier et un débiteur|lien juridique entre un créancier et un débiteur;lien juridique|créancier|débiteur;lien juridique|créancier|débiteur|propriétaire|juge|administration
