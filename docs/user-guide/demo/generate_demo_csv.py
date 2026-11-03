"""Generate the fictional, importable Memflow documentation demo deck set.

No account, backend, credentials, or timestamps are created by this script.
It writes a deterministic CSV that can be imported from Memflow's Import CSV
screen after a separate demo account has been verified.
"""
from __future__ import annotations

import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUTPUT = ROOT / "data" / "memflow_documentation_demo.csv"
HEADER = [
    "collection", "deck", "question", "correct_answer", "wrong_answer_1",
    "wrong_answer_2", "wrong_answer_3", "hint", "explanation", "level",
    "tags", "source", "cloze_text", "accepted_answers", "cloze_answers",
    "cloze_word_bank",
]

# Each entry is a factual prompt, answer, hint, and short teaching explanation.
# Distractors are selected deterministically from other answers in the same deck.
DECKS: dict[str, dict[str, list[tuple[str, str, str, str]]]] = {
    "Mathématiques": {
        "Analyse mathématique": [
            ("Quelle est la limite de sin(x)/x lorsque x tend vers 0 ?", "1", "Utilisez la limite remarquable en radians.", "La limite remarquable sin(x)/x vaut 1 lorsque x tend vers 0."),
            ("Quelle est la dérivée de xⁿ pour un réel n ?", "n·xⁿ⁻¹", "Faites descendre l'exposant puis diminuez-le de 1.", "La règle de puissance donne d(xⁿ)/dx = n·xⁿ⁻¹, sur le domaine considéré."),
            ("Quelle est la dérivée de eˣ ?", "eˣ", "La fonction exponentielle est sa propre dérivée.", "La dérivée de la fonction exponentielle naturelle eˣ est eˣ."),
            ("Quelle primitive de xⁿ convient si n ≠ −1 ?", "xⁿ⁺¹/(n+1) + C", "Ajoutez 1 à l'exposant puis divisez par ce nouvel exposant.", "La formule de primitive est xⁿ⁺¹/(n+1) + C lorsque n ≠ −1."),
            ("Quelle est la dérivée de ln(x) pour x > 0 ?", "1/x", "Le logarithme naturel a une dérivée réciproque.", "Pour x strictement positif, (ln x)' = 1/x."),
            ("Quelle règle dérive f(g(x)) ?", "f'(g(x))·g'(x)", "Dérivez la fonction extérieure puis multipliez par la dérivée intérieure.", "La règle de chaîne donne f'(g(x)) fois g'(x)."),
            ("Que garantit le théorème des valeurs intermédiaires ?", "Une fonction continue prend toute valeur entre f(a) et f(b).", "Il faut la continuité sur un intervalle fermé.", "Si f est continue sur [a,b], toute valeur comprise entre f(a) et f(b) est atteinte."),
            ("Que signifie f'(a) géométriquement ?", "La pente de la tangente au graphe en a.", "C'est une variation locale au point a.", "La dérivée en a est le coefficient directeur de la tangente au graphe au point d'abscisse a."),
            ("Quand une fonction est-elle continue en a ?", "Quand sa limite en a existe et vaut f(a).", "Comparez la limite et la valeur au point.", "La continuité en a exige que lim(x→a) f(x) existe et soit égale à f(a)."),
            ("Que donne le théorème des accroissements finis ?", "Il existe c entre a et b tel que f'(c)=(f(b)-f(a))/(b-a).", "Comparez une dérivée à la pente de la sécante.", "Pour une fonction continue sur [a,b] et dérivable sur ]a,b[, une dérivée égale la pente moyenne en un point c."),
            ("Quelle est la dérivée de ln|x| pour x ≠ 0 ?", "1/x", "La formule s'étend aux deux intervalles séparés par 0.", "Sur tout intervalle ne contenant pas 0, la dérivée de ln|x| est 1/x."),
            ("Quelle est la somme de la série géométrique de premier terme a et de raison r si |r|<1 ?", "a/(1−r)", "La somme infinie converge uniquement si la raison est de module inférieur à 1.", "La somme a + ar + ar² + ... vaut a/(1−r) pour |r|<1."),
            ("Que décrit la dérivée seconde positive sur un intervalle ?", "La fonction est convexe sur cet intervalle.", "La pente de la dérivée première y augmente.", "Si f'' est positive sur un intervalle, f est convexe sur cet intervalle."),
            ("Que vaut le gradient d'une fonction scalaire de plusieurs variables ?", "Le vecteur de ses dérivées partielles.", "Chaque composante correspond à une variable.", "Le gradient rassemble les dérivées partielles premières et indique la direction de plus forte croissance locale."),
            ("Quelle est la dérivée de cos(x) ?", "−sin(x)", "Le signe est négatif.", "La dérivée de cos(x) est −sin(x), lorsque l'angle est exprimé en radians."),
            ("Que permet une approximation de Taylor au premier ordre près de a ?", "f(a)+f'(a)(x−a)", "C'est l'équation de la tangente au point a.", "Le développement de Taylor d'ordre 1 est la linéarisation f(a)+f'(a)(x−a)."),
            ("Quand un point intérieur est-il critique pour une fonction dérivable ?", "Lorsque sa dérivée y est nulle.", "La tangente est alors horizontale.", "Un point critique d'une fonction dérivable vérifie f'(x)=0."),
        ],
        "Algèbre linéaire": [
            ("Qu'est-ce qu'une combinaison linéaire de vecteurs ?", "Une somme de ces vecteurs pondérés par des scalaires.", "Les coefficients sont des nombres du corps considéré.", "Une combinaison linéaire s'écrit comme une somme de vecteurs multipliés par des scalaires."),
            ("Que signifie que des vecteurs sont linéairement indépendants ?", "Seule la combinaison donnant le vecteur nul a tous ses coefficients nuls.", "Aucun vecteur ne peut être obtenu des autres.", "Une relation linéaire nulle entre des vecteurs indépendants a nécessairement des coefficients tous nuls."),
            ("Qu'est-ce qu'une base d'un espace vectoriel ?", "Une famille libre qui engendre l'espace.", "Elle combine indépendance et génération.", "Une base est une famille à la fois linéairement indépendante et génératrice."),
            ("Que mesure le rang d'une matrice ?", "La dimension de l'espace engendré par ses colonnes.", "C'est aussi la dimension de l'espace de ses lignes.", "Le rang est la dimension de l'image de l'application linéaire associée."),
            ("Quand une matrice carrée est-elle inversible ?", "Lorsque son déterminant est non nul.", "Un déterminant nul révèle une dépendance des colonnes.", "Une matrice carrée est inversible si et seulement si son déterminant est non nul."),
            ("Quelle est la dimension du noyau d'une matrice A de n colonnes et de rang r ?", "n−r", "Utilisez le théorème du rang.", "Le théorème du rang donne dim(ker A)+rang(A)=n."),
            ("Que vérifie un vecteur propre v associé à λ pour A ?", "Av=λv avec v non nul.", "L'image de v garde sa direction.", "Un vecteur propre non nul est multiplié par le scalaire λ sous l'action de A."),
            ("Qu'est-ce qu'une valeur propre de A ?", "Un scalaire λ pour lequel Av=λv admet un vecteur v non nul.", "Elle annule le déterminant de A−λI.", "λ est une valeur propre si det(A−λI)=0."),
            ("Quel est le déterminant de [[a,b],[c,d]] ?", "ad−bc", "Multipliez la diagonale principale puis soustrayez l'autre diagonale.", "Pour une matrice 2×2, le déterminant vaut ad−bc."),
            ("Que vaut le produit scalaire de deux vecteurs orthogonaux ?", "0", "L'angle entre les vecteurs vaut un quart de tour, s'ils sont non nuls.", "L'orthogonalité équivaut à un produit scalaire nul."),
            ("Quelle est la matrice identité I ?", "La matrice diagonale dont la diagonale vaut 1.", "Elle laisse tout vecteur inchangé.", "Pour toute matrice compatible A, IA=AI=A."),
            ("Que peut-on dire du produit matriciel AB en général ?", "Il n'est pas nécessairement égal à BA.", "L'ordre des transformations compte.", "Le produit matriciel n'est généralement pas commutatif."),
            ("Qu'est-ce que l'image d'une application linéaire ?", "L'ensemble des vecteurs atteints par l'application.", "C'est l'ensemble de ses valeurs.", "L'image est l'ensemble {T(v) : v dans le domaine}; elle forme un sous-espace."),
            ("Que signifie qu'une matrice réelle est symétrique ?", "Aᵀ=A", "Ses coefficients sont symétriques par rapport à la diagonale.", "Une matrice symétrique réelle est égale à sa transposée."),
            ("Que vaut la trace d'une matrice carrée ?", "La somme de ses coefficients diagonaux.", "Additionnez les éléments de la diagonale principale.", "La trace est la somme des termes diagonaux."),
            ("Quel lien relie la trace et les valeurs propres comptées avec multiplicité ?", "La trace est leur somme.", "Cette propriété vaut sur le corps complexe et pour les valeurs propres avec multiplicité algébrique.", "La somme des valeurs propres, comptées avec multiplicité, est la trace."),
            ("Que représente le noyau d'une application linéaire T ?", "L'ensemble des vecteurs envoyés sur le vecteur nul.", "Il est défini par T(v)=0.", "Le noyau est {v : T(v)=0} et constitue un sous-espace vectoriel."),
        ],
        "Probabilités": [
            ("Quelle formule donne P(A∪B) ?", "P(A)+P(B)−P(A∩B)", "Soustrayez la partie comptée deux fois.", "La formule d'inclusion-exclusion pour deux événements retire leur intersection comptée deux fois."),
            ("Comment définit-on P(A|B) si P(B)>0 ?", "P(A∩B)/P(B)", "Restreignez l'univers aux cas où B a eu lieu.", "La probabilité conditionnelle de A sachant B est P(A∩B) divisée par P(B)."),
            ("Quelle formule de Bayes relie P(A|B) et P(B|A) ?", "P(B|A)P(A)/P(B)", "Le dénominateur doit être positif.", "Bayes donne P(A|B)=P(B|A)P(A)/P(B) lorsque P(B)>0."),
            ("Quand deux événements A et B sont-ils indépendants ?", "Lorsque P(A∩B)=P(A)P(B).", "La réalisation de l'un ne change pas la probabilité de l'autre.", "L'indépendance équivaut à la factorisation de la probabilité de l'intersection."),
            ("Quelle est l'espérance d'une variable discrète X ?", "La somme des valeurs x pondérées par P(X=x).", "C'est une moyenne pondérée par les probabilités.", "E[X]=Σx·P(X=x), lorsque l'espérance est définie."),
            ("Comment définit-on Var(X) ?", "E[(X−E[X])²]", "Elle mesure la dispersion autour de l'espérance.", "La variance est l'espérance du carré de l'écart à la moyenne."),
            ("Quelles valeurs prend une variable de Bernoulli de paramètre p ?", "1 avec probabilité p et 0 avec probabilité 1−p.", "C'est le modèle d'un succès ou d'un échec.", "Une Bernoulli ne prend que les valeurs 0 et 1."),
            ("Que compte une loi binomiale B(n,p) ?", "Le nombre de succès parmi n essais de Bernoulli indépendants.", "Chaque essai a la même probabilité p de succès.", "Une binomiale compte les succès d'un nombre fixé d'essais indépendants de même probabilité."),
            ("Quelle est l'espérance d'une loi binomiale B(n,p) ?", "np", "Multipliez le nombre d'essais par la probabilité de succès.", "L'espérance de B(n,p) est np."),
            ("Quelle est la variance d'une loi de Bernoulli de paramètre p ?", "p(1−p)", "La variance vaut E[X²]−E[X]².", "Comme X²=X pour une Bernoulli, sa variance est p−p²."),
            ("Quelle valeur moyenne obtient-on pour un dé équilibré à six faces ?", "3,5", "Faites la moyenne de 1,2,3,4,5,6.", "La moyenne des six faces est (1+2+3+4+5+6)/6=3,5."),
            ("Quelle est la probabilité de l'événement contraire de A ?", "1−P(A)", "A et son contraire forment une partition.", "P(Aᶜ)=1−P(A)."),
            ("Que dit la loi des grands nombres ?", "La moyenne empirique tend vers l'espérance quand le nombre d'observations augmente.", "Elle décrit une convergence à long terme sous des hypothèses adaptées.", "Pour des variables indépendantes de même loi et d'espérance finie, la moyenne converge vers l'espérance."),
            ("Que décrit le théorème central limite ?", "La somme centrée et réduite tend vers une loi normale sous des hypothèses usuelles.", "Il explique l'apparition de la loi normale pour des sommes.", "Le théorème central limite donne une convergence en loi vers la normale pour des sommes normalisées."),
            ("Quelle propriété caractérise une loi uniforme continue sur [a,b] ?", "Sa densité vaut 1/(b−a) sur [a,b].", "La densité est constante sur l'intervalle.", "La constante 1/(b−a) assure que l'aire totale sous la densité vaut 1."),
            ("Quelle est l'espérance d'une loi de Poisson de paramètre λ ?", "λ", "Le paramètre correspond au nombre moyen d'événements par unité.", "Pour une loi de Poisson, l'espérance et la variance valent toutes deux λ."),
            ("Deux variables indépendantes ont-elles une covariance nulle ?", "Oui, si leurs espérances sont finies.", "La factorisation de l'espérance du produit annule la covariance.", "L'indépendance implique une covariance nulle lorsque les moments nécessaires existent; la réciproque est fausse en général."),
        ],
    },
    "Informatique": {
        "Algorithmique": [
            ("Quelle complexité temporelle a une recherche binaire sur un tableau trié ?", "O(log n)", "Chaque étape élimine environ la moitié des éléments.", "La recherche binaire divise l'intervalle de recherche par deux à chaque comparaison."),
            ("Quelle complexité a une recherche linéaire dans le pire cas ?", "O(n)", "Elle peut examiner chaque élément.", "Dans le pire cas, la recherche linéaire parcourt les n éléments."),
            ("Quelle complexité temporelle moyenne a le tri fusion ?", "O(n log n)", "Le tableau est séparé puis fusionné à chaque niveau.", "Le tri fusion a une complexité O(n log n) dans le pire cas."),
            ("Quelle est la complexité moyenne usuelle du tri rapide ?", "O(n log n)", "Un pivot bien réparti produit une profondeur logarithmique.", "Le tri rapide est en moyenne O(n log n), mais son pire cas classique est O(n²)."),
            ("Quelle est la structure de données centrale d'un parcours en largeur ?", "Une file FIFO.", "Les sommets sont explorés par distance croissante.", "Une file conserve l'ordre de découverte nécessaire au parcours en largeur."),
            ("Quelle structure accompagne souvent un parcours en profondeur itératif ?", "Une pile.", "Le dernier sommet découvert est traité en premier.", "Une pile explicite reproduit le comportement récursif du parcours en profondeur."),
            ("Quelle condition impose Dijkstra aux poids des arêtes ?", "Ils doivent être non négatifs.", "Un poids négatif invalide la sélection gloutonne du sommet suivant.", "Dijkstra est correct avec des poids non négatifs; les arêtes négatives exigent une autre méthode."),
            ("Sur quel type de graphe un tri topologique est-il défini ?", "Un graphe orienté acyclique.", "Un cycle rend impossible un ordre respectant toutes les dépendances.", "Le tri topologique ordonne les sommets d'un DAG selon ses arcs."),
            ("Que décrit la notation O(f(n)) en analyse d'algorithmes ?", "Une borne asymptotique supérieure à un facteur constant près.", "Elle décrit la croissance pour les grandes tailles d'entrée.", "Big O borne la croissance de la fonction par un multiple de f(n), à partir d'une taille suffisante."),
            ("Qu'est-ce qu'un tri stable ?", "Un tri qui conserve l'ordre relatif des éléments de même clé.", "Les éléments égaux gardent leur ordre d'origine.", "La stabilité préserve l'ordre initial entre éléments dont les clés de tri sont égales."),
            ("Quelle stratégie réduit un grand problème en sous-problèmes mémorisés ?", "La programmation dynamique.", "Elle réutilise les résultats de sous-problèmes qui se recouvrent.", "La programmation dynamique stocke les résultats afin d'éviter des calculs répétés."),
            ("Quelle stratégie choisit à chaque étape une option localement avantageuse ?", "Un algorithme glouton.", "Ce choix n'est optimal globalement que si la propriété gloutonne est démontrée.", "Un algorithme glouton fait un choix local à chaque étape; sa correction dépend du problème."),
            ("À quoi sert un cas de base en récursion ?", "À arrêter la récursion sur une entrée simple.", "Il évite une suite d'appels sans fin.", "Le cas de base fournit le résultat directement et garantit la terminaison avec une progression correcte."),
            ("Que signifie qu'un algorithme termine ?", "Il s'arrête après un nombre fini d'étapes pour chaque entrée autorisée.", "La terminaison est une propriété distincte de la correction.", "Un algorithme terminant ne poursuit pas indéfiniment son exécution."),
            ("Quel invariant aide à démontrer un algorithme itératif ?", "Une propriété vraie avant et après chaque itération.", "L'initialisation, la conservation et la terminaison établissent la preuve.", "Un invariant de boucle relie l'état initial, chaque tour, et le résultat final."),
            ("Quelle complexité temporelle moyenne vise une table de hachage bien dimensionnée ?", "O(1) pour une recherche", "La complexité attendue dépend d'une bonne fonction de hachage et d'un facteur de charge maîtrisé.", "La recherche est en moyenne constante, mais son pire cas peut être linéaire."),
            ("Que représente un graphe non orienté ?", "Un ensemble de sommets reliés par des arêtes sans orientation.", "Une arête {u,v} peut être parcourue dans les deux sens.", "Les arêtes d'un graphe non orienté ne distinguent pas de sommet de départ et d'arrivée."),
        ],
        "Structures de données": [
            ("Quelle est la complexité d'accès par indice dans un tableau ?", "O(1)", "L'adresse de l'élément se calcule directement.", "Un tableau à accès direct permet d'atteindre l'indice i en temps constant."),
            ("Quelle règle suit une pile ?", "LIFO : dernier entré, premier sorti.", "Pensez à une pile d'assiettes.", "Une pile retire d'abord l'élément ajouté le plus récemment."),
            ("Quelle règle suit une file ?", "FIFO : premier entré, premier sorti.", "Pensez à une file d'attente.", "Une file traite les éléments dans leur ordre d'arrivée."),
            ("Quel avantage a une liste chaînée pour insérer après un nœud connu ?", "L'insertion peut se faire en O(1).", "Il faut modifier quelques références, sans décaler tous les éléments.", "Une insertion après un nœud déjà localisé demande un nombre constant de changements de liens."),
            ("Quelle complexité a l'extraction du minimum d'un tas binaire min ?", "O(log n)", "La racine est remplacée puis le tas est rétabli sur sa hauteur.", "La hauteur d'un tas binaire complet est logarithmique en n."),
            ("Qu'est-ce qu'une collision dans une table de hachage ?", "Deux clés différentes obtiennent le même indice de hachage.", "Une stratégie de résolution est alors nécessaire.", "Une collision survient lorsque plusieurs clés se projettent sur le même emplacement."),
            ("Quelle propriété définit un arbre binaire de recherche ?", "Les clés du sous-arbre gauche sont inférieures et celles du droit supérieures selon l'ordre choisi.", "La propriété vaut récursivement pour chaque nœud.", "L'ordre des clés permet de rechercher en éliminant un sous-arbre à chaque étape."),
            ("Quelle hauteur vise un arbre AVL ?", "O(log n)", "L'équilibrage impose une différence de hauteur limitée entre sous-arbres.", "Les rotations AVL maintiennent une hauteur logarithmique en nombre de nœuds."),
            ("À quoi sert un trie ?", "À stocker efficacement des clés composées de caractères ou de préfixes.", "Les chemins partagés représentent des préfixes communs.", "Un trie organise les clés selon leurs symboles successifs et facilite les recherches par préfixe."),
            ("Quelle mémoire occupe une matrice d'adjacence pour V sommets ?", "O(V²)", "Elle réserve une case pour chaque paire de sommets.", "Une matrice d'adjacence stocke V×V relations potentielles."),
            ("Quelle mémoire occupe une liste d'adjacence ?", "O(V+E)", "Chaque sommet et chaque arête est représenté une fois, à un facteur près.", "Les listes d'adjacence sont adaptées aux graphes creux, avec un espace proportionnel à V+E."),
            ("Quelle opération une deque permet-elle ?", "Ajouter ou retirer aux deux extrémités.", "Son nom vient de double-ended queue.", "Une deque expose les opérations d'insertion et de retrait à l'avant et à l'arrière."),
            ("À quoi sert une structure union-find ?", "À suivre des ensembles disjoints et leurs fusions.", "Elle répond aux opérations find et union.", "Union-find regroupe des éléments et teste s'ils appartiennent au même ensemble."),
            ("Dans un tas binaire stocké en tableau à partir de l'indice 0, quel est l'indice du fils gauche de i ?", "2i+1", "Les indices des deux fils suivent une formule simple.", "Pour un tableau indexé à partir de zéro, le fils gauche de i est à 2i+1 et le droit à 2i+2."),
            ("Quelle propriété un ensemble (set) garantit-il ?", "L'unicité de ses éléments.", "Une même valeur n'y figure pas plusieurs fois.", "Un ensemble représente des valeurs distinctes, sans doublon."),
            ("Qu'associe une table de correspondance (map) ?", "Des clés à des valeurs.", "Une clé permet de retrouver la valeur associée.", "Une map stocke des paires clé-valeur et impose généralement l'unicité des clés."),
            ("Quelle structure convient pour traiter des tâches par priorité ?", "Une file de priorité.", "L'élément extrait est celui dont la priorité est la meilleure selon l'ordre choisi.", "Une file de priorité expose l'élément prioritaire, souvent implémentée avec un tas."),
        ],
        "Logique propositionnelle": [
            ("Qu'est-ce qu'une proposition ?", "Un énoncé auquel on peut attribuer vrai ou faux.", "Une question ouverte n'est pas une proposition.", "Une proposition a une valeur de vérité bien définie."),
            ("À quoi l'implication p→q est-elle équivalente ?", "¬p∨q", "Elle est fausse uniquement si p est vraie et q fausse.", "La table de vérité de p→q correspond à celle de ¬p∨q."),
            ("Quelle est la contraposée de p→q ?", "¬q→¬p", "Inversez et niez les deux propositions.", "Une implication est logiquement équivalente à sa contraposée."),
            ("Quelle loi de De Morgan nie p∧q ?", "¬p∨¬q", "La négation échange ∧ avec ∨ et nie chaque terme.", "La négation d'une conjonction est la disjonction des négations."),
            ("Quel schéma décrit le modus ponens ?", "p, p→q, donc q", "Appliquez l'implication à son antécédent.", "Si p est vraie et p implique q, alors q est vraie."),
            ("Quel schéma décrit le modus tollens ?", "p→q, ¬q, donc ¬p", "Niez le conséquent pour nier l'antécédent.", "Le modus tollens est une règle d'inférence valide."),
            ("Qu'est-ce qu'une tautologie ?", "Une formule vraie pour toute valuation.", "Elle ne dépend pas des valeurs de ses variables.", "Une tautologie est satisfaite par toutes les interprétations."),
            ("Qu'est-ce qu'une contradiction logique ?", "Une formule fausse pour toute valuation.", "Aucune interprétation ne la rend vraie.", "Une contradiction est insatisfiable et sa négation est une tautologie."),
            ("Quand p↔q est-elle vraie ?", "Lorsque p et q ont la même valeur de vérité.", "Les deux implications p→q et q→p doivent être vraies.", "L'équivalence logique exige que les deux côtés soient vrais ensemble ou faux ensemble."),
            ("Que signifie ∀x P(x) ?", "P(x) est vraie pour tout x du domaine.", "Le quantificateur universel porte sur chaque élément du domaine.", "La formule affirme que chaque élément satisfait le prédicat P."),
            ("Que signifie ∃x P(x) ?", "Il existe au moins un x du domaine tel que P(x) soit vraie.", "Un seul témoin suffit.", "Le quantificateur existentiel demande au moins un élément satisfaisant P."),
            ("Quelle est la négation de ∀x P(x) ?", "∃x ¬P(x)", "Nier « tous » revient à dire « au moins un ne l'est pas ».", "La négation du quantificateur universel est un quantificateur existentiel sur la négation."),
            ("Qu'est-ce qu'une forme normale conjonctive ?", "Une conjonction de clauses, chaque clause étant une disjonction de littéraux.", "Les clauses sont reliées par ET.", "La forme normale conjonctive (CNF) a la forme AND de OR de littéraux."),
            ("Que signifie qu'une formule est satisfiable ?", "Au moins une valuation la rend vraie.", "Il suffit d'un modèle pour la satisfaire.", "Une formule satisfiable possède au moins une interprétation vraie."),
            ("Quelle est la négation de p∨q ?", "¬p∧¬q", "La négation échange la disjonction contre une conjonction.", "La loi de De Morgan donne ¬(p∨q)=¬p∧¬q."),
            ("Quand l'implication p→q est-elle fausse ?", "Lorsque p est vraie et q est fausse.", "C'est le seul cas qui contredit la promesse « si p, alors q ».", "Une implication matérielle n'est fausse que pour antécédent vrai et conséquent faux."),
            ("Qu'est-ce qu'une inférence valide ?", "Une inférence dont les prémisses vraies garantissent une conclusion vraie.", "Aucun cas ne peut rendre les prémisses vraies et la conclusion fausse.", "La validité porte sur la préservation de la vérité, indépendamment du sujet des propositions."),
        ],
        "Réseaux informatiques": [
            ("À quelle couche OSI associe-t-on le routage IP ?", "Réseau, couche 3", "Elle achemine des paquets entre réseaux.", "La couche réseau OSI s'occupe de l'adressage logique et du routage."),
            ("Quel service traduit couramment un nom de domaine en adresse IP ?", "DNS", "Il résout les noms utilisés par les personnes.", "Le DNS associe des noms de domaine à des enregistrements, dont des adresses IP."),
            ("Quel protocole de transport établit une connexion fiable et ordonnée ?", "TCP", "Il utilise des accusés de réception et retransmissions.", "TCP fournit un flux fiable et ordonné entre applications."),
            ("UDP garantit-il la livraison des datagrammes ?", "Non.", "UDP ne fournit pas de retransmission ou d'ordre garanti par lui-même.", "UDP est un protocole sans connexion qui n'assure pas la livraison."),
            ("À quoi sert DHCP dans un réseau IP ?", "À attribuer automatiquement une configuration IP aux appareils.", "Il peut fournir adresse, passerelle et serveur DNS.", "DHCP distribue une configuration réseau aux clients."),
            ("Quel protocole découvre une adresse MAC à partir d'une adresse IPv4 sur un réseau local ?", "ARP", "Il résout une adresse de couche réseau sur le lien local.", "ARP associe une adresse IPv4 à l'adresse matérielle du prochain saut sur le réseau local."),
            ("Quelle adresse identifie une interface au niveau Ethernet local ?", "Adresse MAC", "Elle est utilisée dans les trames du réseau local.", "Une adresse MAC identifie une interface au niveau liaison, sous réserve des mécanismes de virtualisation ou de randomisation."),
            ("Quel appareil transfère des trames entre ports d'un même réseau local ?", "Un commutateur (switch)", "Il apprend les adresses MAC observées.", "Un switch Ethernet transmet les trames vers le port associé à l'adresse MAC de destination."),
            ("Quel appareil choisit un prochain saut entre réseaux IP ?", "Un routeur", "Il utilise une table de routage.", "Un routeur achemine les paquets entre réseaux selon ses routes."),
            ("Quel est le rôle principal de TLS pour une connexion web ?", "Chiffrer et authentifier la connexion au serveur.", "Le certificat participe à l'authentification du serveur.", "TLS protège la confidentialité et l'intégrité du transport et authentifie généralement le serveur."),
            ("Que signifie le code HTTP 404 ?", "La ressource demandée n'a pas été trouvée.", "C'est une réponse d'erreur côté client.", "HTTP 404 indique que le serveur n'a pas trouvé de représentation pour la ressource ciblée."),
            ("Que signifie le code HTTP 403 ?", "L'accès à la ressource est refusé.", "Le serveur a compris la requête mais refuse de l'autoriser.", "HTTP 403 indique un refus d'accès, même si le serveur a compris la requête."),
            ("Combien de bits contient une adresse IPv6 ?", "128 bits", "Elle est quatre fois plus longue qu'une adresse IPv4 de 32 bits.", "Une adresse IPv6 a une longueur de 128 bits."),
            ("Que représente le /24 dans une notation CIDR telle que 192.0.2.0/24 ?", "24 bits de préfixe réseau", "Le nombre après la barre donne la longueur du préfixe.", "La longueur CIDR indique le nombre de bits significatifs du préfixe réseau."),
            ("Que fait le NAT dans son usage courant à domicile ?", "Il traduit des adresses entre le réseau privé et l'adresse publique.", "Le routeur modifie notamment les adresses et souvent les ports.", "La traduction d'adresses permet à plusieurs hôtes privés de partager une connectivité IPv4 publique."),
            ("Quel échange ouvre une connexion TCP classique ?", "SYN, SYN-ACK, ACK", "C'est la poignée de main en trois temps.", "Le three-way handshake synchronise les numéros de séquence et établit la connexion TCP."),
            ("À quoi sert un port TCP ou UDP ?", "À identifier un point de terminaison applicatif sur un hôte.", "L'adresse IP identifie l'hôte, le port oriente vers le service.", "Un port permet au système de distribuer les données vers le processus ou service concerné."),
        ],
    },
    "Langues": {
        "Anglais": [
            ("Que signifie “reliable” ?", "fiable", "Une personne ou une source sur laquelle on peut compter.", "“Reliable” signifie digne de confiance ou fiable."),
            ("Que signifie “eventually” ?", "finalement", "Il s'agit du résultat après un certain temps.", "“Eventually” signifie finalement, et non « éventuellement » au sens français de peut-être."),
            ("Comment traduire “to borrow” ?", "emprunter", "On prend quelque chose temporairement à quelqu'un.", "“To borrow” signifie emprunter; “to lend” signifie prêter."),
            ("Que signifie “actually” ?", "en fait", "Ce faux ami ne signifie généralement pas « actuellement ».", "“Actually” veut dire en fait ou réellement; “currently” signifie actuellement."),
            ("Comment traduire “although” ?", "bien que", "Ce mot introduit une concession.", "“Although” introduit une idée concessive et se traduit par « bien que » ou « quoique »."),
            ("Que signifie “to achieve a goal” ?", "atteindre un objectif", "Le verbe parle de réussite après un effort.", "“To achieve” signifie atteindre ou accomplir un objectif."),
            ("Comment traduire “to improve” ?", "améliorer", "On rend quelque chose meilleur.", "“To improve” signifie améliorer ou s'améliorer selon le contexte."),
            ("Que signifie “environment” ?", "environnement", "Le mot peut désigner le milieu naturel ou le contexte.", "“Environment” signifie environnement ou contexte."),
            ("Comment traduire “enough” dans “enough time” ?", "assez", "Il indique une quantité suffisante.", "“Enough time” signifie suffisamment de temps."),
            ("Que signifie “to attend a meeting” ?", "assister à une réunion", "Ici, “attend” ne signifie pas « attendre ».", "“To attend” veut dire être présent à un événement."),
            ("Comment traduire “schedule” comme nom ?", "horaire", "Il s'agit d'un plan de dates ou d'heures.", "“Schedule” signifie programme ou horaire selon le contexte."),
            ("Que signifie “instead” ?", "à la place", "Il exprime le remplacement d'une option par une autre.", "“Instead” se traduit notamment par « à la place » ou « plutôt »."),
            ("Que signifie “aware of” ?", "conscient de", "La personne sait ou remarque quelque chose.", "“To be aware of” signifie être conscient de ou avoir connaissance de."),
            ("Comment traduire “feedback” ?", "retour", "Il s'agit d'une réaction ou d'une évaluation communiquée.", "“Feedback” signifie retour ou commentaire, notamment sur un travail."),
            ("Que signifie “to figure out” ?", "comprendre", "On trouve une solution ou on découvre une explication.", "“To figure out” signifie comprendre, découvrir ou trouver une solution."),
            ("Comment traduire “despite” ?", "malgré", "Ce mot est suivi d'un nom ou d'un groupe nominal.", "“Despite the rain” se traduit par « malgré la pluie »."),
            ("Que signifie “to run out of time” ?", "ne plus avoir de temps", "La ressource temps est épuisée.", "“To run out of” signifie manquer de ou épuiser une réserve."),
        ],
        "Néerlandais": [
            ("Que signifie “de fiets” ?", "le vélo", "C'est un moyen de transport courant aux Pays-Bas.", "“De fiets” signifie le vélo."),
            ("Comment traduire “het station” ?", "la gare", "On y prend souvent le train.", "“Het station” signifie la gare ou la station selon le contexte."),
            ("Que signifie “de afspraak” ?", "le rendez-vous", "Il peut s'agir d'une rencontre planifiée.", "“De afspraak” signifie le rendez-vous ou l'accord."),
            ("Comment traduire “gezellig” ?", "convivial", "Ce mot décrit une ambiance agréable et chaleureuse.", "“Gezellig” qualifie une atmosphère chaleureuse, agréable ou conviviale."),
            ("Que signifie “misschien” ?", "peut-être", "Le locuteur exprime une possibilité.", "“Misschien” signifie peut-être."),
            ("Comment traduire “ik begrijp het” ?", "je comprends", "Le verbe est “begrijpen”.", "“Ik begrijp het” signifie « je comprends cela »."),
            ("Que signifie “de sleutel” ?", "la clé", "Elle peut ouvrir une porte ou être une clé au sens figuré.", "“De sleutel” signifie la clé."),
            ("Comment traduire “vroeger” ?", "autrefois", "Il situe quelque chose dans le passé.", "“Vroeger” signifie autrefois ou auparavant."),
            ("Que signifie “het antwoord” ?", "la réponse", "C'est ce que l'on donne à une question.", "“Het antwoord” signifie la réponse."),
            ("Comment traduire “de omgeving” ?", "les environs", "Le mot peut aussi désigner l'environnement.", "“De omgeving” signifie l'environnement ou les environs."),
            ("Que signifie “vergeten” ?", "oublier", "C'est le contraire de se souvenir.", "“Vergeten” signifie oublier."),
            ("Comment traduire “de afspraak verzetten” ?", "reporter le rendez-vous", "On change le moment convenu.", "“Verzetten” signifie déplacer ou reporter une activité planifiée."),
            ("Que signifie “voldoende” ?", "suffisant", "La quantité répond au besoin.", "“Voldoende” signifie suffisant ou assez."),
            ("Comment traduire “de uitdaging” ?", "le défi", "Il demande un effort ou une compétence.", "“De uitdaging” signifie le défi."),
            ("Que signifie “rustig” ?", "calme", "Il peut décrire une personne, un lieu ou un rythme.", "“Rustig” signifie calme ou tranquille."),
            ("Comment traduire “ik ben onderweg” ?", "je suis en route", "La personne a commencé son déplacement.", "“Ik ben onderweg” signifie « je suis en route »."),
            ("Que signifie “de verbetering” ?", "l'amélioration", "C'est le résultat d'un progrès.", "“De verbetering” signifie l'amélioration."),
        ],
    },
}


def slug(value: str) -> str:
    return "".join(ch.lower() if ch.isalnum() else "-" for ch in value).strip("-")


def rows():
    for collection, decks in DECKS.items():
        for deck, cards in decks.items():
            answers = [item[1] for item in cards]
            for i, (question, answer, hint, explanation) in enumerate(cards):
                wrong: list[str] = []
                step = 1
                while len(wrong) < 3:
                    candidate = answers[(i + step) % len(answers)]
                    if candidate.casefold() != answer.casefold() and candidate not in wrong:
                        wrong.append(candidate)
                    step += 1
                level = (i % 4) + 1
                cloze_text = cloze_answer = cloze_bank = ""
                accepted = ""
                if i % 4 == 1:
                    # Keep a complete, valid one-hole cloze with a deterministic bank.
                    cloze_answer = answer
                    cloze_text = f"{hint} : {{{{{answer}}}}}."
                    cloze_bank = "|".join([answer, *wrong[:2]])
                if i % 3 == 1:
                    accepted = answer.lower()
                yield [
                    collection, deck, question, answer, *wrong, hint, explanation,
                    str(level), f"{slug(collection)}|{slug(deck)}|demo", "Fiche de démonstration",
                    cloze_text, accepted, cloze_answer, cloze_bank,
                ]


def main() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    count = 0
    with OUTPUT.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream, delimiter=";", lineterminator="\n", quoting=csv.QUOTE_MINIMAL)
        writer.writerow(HEADER)
        for row in rows():
            writer.writerow(row)
            count += 1
    print(f"Wrote {count} fictional demo cards to {OUTPUT}")


if __name__ == "__main__":
    main()
