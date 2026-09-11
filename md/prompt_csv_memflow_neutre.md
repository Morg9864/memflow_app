# Prompt CSV Memflow

À partir du document fourni, génère un fichier CSV UTF-8 directement importable dans Memflow.

La sortie finale doit respecter le contrat technique et pédagogique ci-dessous. Avant de répondre, effectue le contrôle qualité final décrit à la fin du prompt.

## Objectif

Transformer le contenu du document en une banque de questions d'apprentissage actif.

Le but n'est pas de résumer le document, mais de créer suffisamment de questions utiles pour mémoriser, comprendre et réviser efficacement l'ensemble du contenu. Priorise d'abord la couverture complète du document, puis les variantes réellement utiles. N'ajoute pas de variantes redondantes ou de micro-questions qui testent exactement le même rappel.

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

Pour chaque carte, renseigne `source` avec la section, le chapitre ou le paragraphe du document qui justifie la réponse. Utilise un libellé stable et précis, par exemple `Chapitre 2 — § 2.3`. N'invente pas de référence : si le document ne comporte pas de numérotation, reprends son titre de section.

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

Si la question est de niveau 1, l'indice doit être "-". Les niveaux supérieurs doivent avoir un indice plus informatif, mais sans jamais révéler la réponse, ni donner une partie de la réponse.

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
- tags
- source
- cloze_text
- accepted_answers
- cloze_answers
- cloze_word_bank

Le fichier final doit être un vrai CSV importable, sans texte avant ni après, sans bloc Markdown et sans commentaire.

Contraintes techniques obligatoires :

- encodage UTF-8 valide ;
- séparateur de colonnes : point-virgule `;` ;
- première ligne : le header complet ci-dessus, exactement dans le même ordre ;
- chaque ligne de données contient exactement 16 colonnes ;
- utilise les règles CSV standard : entoure de guillemets doubles tout champ contenant `;`, une virgule, un guillemet ou un retour à la ligne ; dans un champ cité, échappe un guillemet par `""` ;
- les retours à la ligne dans un champ doivent rester à l'intérieur de guillemets doubles ;
- le caractère `|` est réservé aux listes `tags`, `accepted_answers`, `cloze_answers` et `cloze_word_bank` ;
- n'utilise pas `;` comme séparateur à l'intérieur d'un champ sans le protéger par des guillemets ;
- n'ajoute aucune colonne, ne renomme aucune colonne et ne réordonne aucune colonne.

## Règles strictes

- Ne pas inventer d'information.
- Ne pas utiliser d'informations externes.
- Ne pas créer de doublons inutiles : deux cartes ne doivent pas poser la même question sur la même information, même avec une reformulation superficielle.
- Ne pas faire de questions trop vagues.
- Ne jamais créer de questions liés à des images, graphiques, schémas ou tableaux, sauf si le texte les décrit explicitement.
- Les champs obligatoires sont toujours remplis : `collection`, `deck`, `question`, `correct_answer`, `wrong_answer_1`, `wrong_answer_2`, `wrong_answer_3`, `level` et `source`.
- Les champs optionnels `hint`, `explanation`, `tags`, `cloze_text`, `accepted_answers`, `cloze_answers` et `cloze_word_bank` peuvent être vides uniquement lorsque leur usage n'est pas pertinent. N'utilise jamais `-` comme valeur technique de remplacement, sauf pour `hint` d'une carte de niveau 1.
- Respecter exactement le format CSV décrit.
- Pour une carte sans texte à trous, laisse `cloze_text`, `cloze_answers` et `cloze_word_bank` vides.
- Pour une carte avec texte à trous, remplis toujours les trois champs cloze et respecte toutes les règles cloze.
- Vérifie que `correct_answer` est différente de chacune des trois mauvaises réponses et que les trois mauvaises réponses sont différentes entre elles.
- Vérifie que les mauvaises réponses sont plausibles, de longueur comparable à la bonne réponse et grammaticalement compatibles avec la question.
- Vérifie que `accepted_answers`, lorsqu'il est rempli, contient la bonne réponse ou une formulation réellement équivalente.

Règles strictes spécifiques au texte à trous :

- si `cloze_text` est rempli, alors `cloze_answers` et `cloze_word_bank` doivent aussi être remplis ;
- `cloze_answers` doit contenir exactement autant d'éléments qu'il y a de trous dans `cloze_text` ;
- `cloze_word_bank` doit contenir toutes les bonnes réponses et quelques distracteurs plausibles ;
- chaque entrée de `cloze_word_bank` doit être grammaticalement compatible avec l'emplacement du trou ;
- aucune entrée de `cloze_word_bank` ne doit rendre la phrase absurde juste par sa forme ; elle doit être plausible comme complétion, même si elle reste factuellement fausse ;
- les distracteurs d'une même bank doivent être formatés comme la bonne réponse, sans indice de casse, d'article ou de structure grammaticale ;
- ne mets pas plusieurs fois inutilement le même mot dans `cloze_word_bank`.

## Contrôle qualité final obligatoire

Avant de produire la réponse finale, contrôle chaque ligne comme si elle allait être importée par un parseur strict :

1. vérifie que la première ligne est le header complet, avec exactement les 16 intitulés attendus ;
2. vérifie que chaque ligne de données possède exactement 16 colonnes après décodage CSV ;
3. vérifie que chaque champ obligatoire est présent et non vide ;
4. vérifie que `level` est un entier entre 1 et 4 ;
5. vérifie qu'aucune ligne ne contient de séparateur `;` non protégé dans un champ ;
6. vérifie l'unicité de la bonne réponse et des mauvaises réponses, ainsi que l'absence de doublons de questions ;
7. pour chaque cloze, compte les occurrences de `{{...}}`, compare ce nombre à `cloze_answers`, vérifie que le contenu des placeholders correspond aux réponses dans le même ordre, puis vérifie que chaque réponse apparaît dans `cloze_word_bank` avec la bonne multiplicité ;
8. vérifie que `source` permet de retrouver la partie du document à l'origine de la carte ;
9. supprime tout texte situé avant ou après le CSV.

Si une ligne ne respecte pas une contrainte, corrige-la avant de répondre. Ne remplace pas une erreur par une explication textuelle hors du CSV.

La difficulté du deck n'est pas une colonne du CSV. Elle est inférée par Memflow après l'import à partir de la moyenne des `level` des cartes du deck : moyenne inférieure à `X,5` vers `X`, moyenne égale ou supérieure à `X,5` vers `X+1`. La valeur obtenue est bornée entre 1 et 4 puis associée ainsi : `1` = `facile`, `2` = `moyen`, `3` = `difficile`, `4` = `avancé`.

## Critère de réussite

Le CSV est réussi si une personne qui maîtrise toutes les questions générées peut comprendre, mémoriser et restituer l'essentiel du document, même si les questions sont posées sous une autre forme.

## Exemple format (pour un cours de droit)

Droit des contrats informatiques;Chapitre 1 — Droit des obligations et des contrats;Le droit des obligations est une branche de quel droit ?;Le droit civil;Le droit pénal;Le droit administratif;Le droit commercial;-;Le droit des obligations est une branche du droit civil.;1;obligation|droit-civil;Chapitre 1 — Droit des obligations et des contrats;Le droit des obligations est une branche du {{droit civil}}.;le droit civil|droit civil;droit civil;droit civil|droit pénal|droit administratif|droit commercial

Droit des contrats informatiques;Chapitre 1 — Droit des obligations et des contrats;En droit civil, qu'est-ce qu'une obligation ?;Un lien juridique entre deux personnes (créancier et débiteur);Une sanction pénale imposée par un juge;Un droit de propriété sur un bien;Une obligation fiscale envers l'État;Revois la définition d'une obligation.;Une obligation est un lien juridique entre un créancier et un débiteur, par lequel le débiteur s'engage à faire, ne pas faire ou donner quelque chose au créancier.;3;obligation|definition;Chapitre 1 — Droit des obligations et des contrats;Une obligation est un {{lien juridique}} entre un {{créancier}} et un {{débiteur}}.;Un lien juridique entre deux personnes (créancier et débiteur)|Un lien juridique entre un créancier et un débiteur|lien juridique entre un créancier et un débiteur;lien juridique|créancier|débiteur;lien juridique|créancier|débiteur|propriétaire|juge|administration
