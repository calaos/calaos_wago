# Protocole UDP Calaos — ce que la 4.0 change

Port 4646, trames texte, une réponse par requête, attribution **positionnelle** côté serveur
(`WagoMap::udpRequest_cb`) : ce qui arrive est la réponse de la commande en tête de file.

## Version annoncée

`WAGO_GET_VERSION` répond `WAGO_GET_VERSION <H>.<L> <modèle>`. Les programmes de ce dépôt annoncent
**4.0** (`Config.CALAOS_VERSION_H` / `_L`).

`calaos_server` conditionne des choix de protocole à cette valeur — `plcDaliGetCarriesGroup()`
compare au seuil `DALI_GROUP_MAJOR.DALI_GROUP_MINOR`, qui vaut 3.0. **Incrémenter la version dès que
le contrat ci-dessous change**, sinon le serveur ne peut pas savoir à quoi s'attendre.

Le champ `<modèle>` est correct depuis la 4.0 (chaque cible annonce le sien). Il ne l'était pas
avant : les sept programmes 3.0 répondaient tous `750-849`. Ne rien en dériver côté serveur.

## Le champ `address` porte trois sémantiques

Une même valeur signifie, selon le contexte :

| plage | sens |
|---|---|
| `0..DMX_ADDR_BASE` | adresse courte DALI, ou numéro de groupe DALI si le drapeau groupe vaut 1 |
| `DMX_ADDR_BASE+1 .. DMX_ADDR_BASE+DMX_CHANNELS` | canal DMX, numéroté `address - DMX_ADDR_BASE` |

`DMX_ADDR_BASE` vaut 100 et est une borne **exclusive** : `abDMX_Values` est un `ARRAY[1..255]`, donc
le premier canal DMX est l'adresse 101. L'adresse 100 n'est pas une adresse DMX.

## Ordre des paramètres — l'asymétrie est voulue

- `WAGO_DALI_SET <ligne> <drapeau groupe> <adresse> <niveau> <fade>`
- `WAGO_DALI_GET <ligne> <adresse> [<drapeau groupe>]`

Le drapeau est **avant** l'adresse à l'écriture, **après** à la lecture. Un programme antérieur à
3.0 lit l'adresse dans ce même second champ : le drapeau a donc été ajouté en troisième position
pour ne pas déplacer l'adresse. `calaos_server` n'envoie ce troisième champ que si la version
annoncée est ≥ 3.0.

## Réponses d'erreur — nouveau en 4.0

`WAGO_DALI_GET ERR <raison>`

Un programme annonçant **4.0 ou plus** peut répondre cette forme à une lecture qu'il ne sait pas
servir. Raison émise aujourd'hui : `GROUP_UNSUPPORTED`, pour la relecture d'un groupe sur un bus
DALI standard.

Ce qui est **vérifié dans ce dépôt** : `DaliDimValue` n'a aucune entrée de groupe, et `DALI_02` ne
porte aucun bloc fonctionnel de statut par groupe — établi par une sonde de compilation. L'explication
de fond — une trame retour DALI vient d'un seul appareil, une requête adressée à un groupe
provoquerait une collision — relève de la norme et n'est pas vérifiée ici.

⚠️ **La réponse suit `Config.CONFIG_DALI`, pas le matériel présent.** `CONFIG_DALI` (module 641) et
`CONFIG_DALI_647` sont posés par deux tests indépendants du balayage de modules ; rien ne les rend
exclusifs, et le 641 l'emporte — ici comme dans `DaliSwitch` et `DaliDimValue`. Sur une armoire
portant les deux modules, une relecture de groupe répond donc `ERR GROUP_UNSUPPORTED` **alors que le
chemin 753-647 aurait su répondre**, celui-ci tenant sa propre image côté programme. Ne pas conclure
d'un `GROUP_UNSUPPORTED` que l'armoire n'a pas de 647.

### Ce qui n'a pas encore de forme d'erreur

Deux réponses restent des valeurs plausibles pour une question qui n'en a pas :

- **adresse au-delà de `DMX_ADDR_BASE + DMX_CHANNELS`** : la requête retombe sur la voie DALI et
  répond avec l'adresse latchée de la lecture précédente ;
- **armoire sans aucun module DALI** : le chemin 647 répond depuis des tableaux jamais alimentés,
  soit « éteint, niveau 0 ».

Les traiter suppose de décider ce que le serveur doit voir — une raison `ERR` de plus, ou un refus.

Deux contraintes ont façonné cette forme, et elles sont à connaître avant de la modifier :

- **Le verbe est conservé.** `udpReplyMisattributedToDaliGet` jette toute réponse dont le verbe
  commence par `WAGO_` sans être `WAGO_DALI_GET` tant qu'une lecture DALI est en vol. Un
  `WAGO_DALI_GET_ERROR` serait perdu et l'appelant ne verrait que le délai de 2 s.
- **`ERR` n'est pas numérique.** Le serveur lit tout premier champ différent de la chaîne `"0"`
  comme « allumé ». Une sentinelle prise dans le domaine des valeurs — `-1`, `0` — est donc lue
  comme un état. Aucune réponse ne doit encoder « je ne sais pas » dans le domaine des valeurs.

### Ce que `calaos_server` doit implémenter

Tant que ce n'est pas fait, `ERR` est lu comme « allumé », exactement comme `-1` l'était.

1. Dans le callback de la lecture DALI, tester le premier champ **avant** toute conversion
   numérique : s'il vaut `ERR`, rapporter un échec — la même chose qu'un `status = false` de délai
   dépassé — et journaliser la raison.
2. Gater ce test sur la version annoncée si l'on veut rester strict : seul un programme ≥ 4.0 émet
   cette forme.
3. Ne pas ajouter de verbe dédié côté automate sans lever d'abord le filtre de
   `udpReplyMisattributedToDaliGet`.

## Verbes de diagnostic

Pour le banc ([BENCH-647.md](BENCH-647.md)). `calaos_server` ne les consomme pas ; `WAGO_INFO` n'a
pas bougé. Ils font partie du contrat **4.0** — la version en cours de construction, pas encore
sortie ; la version annoncée n'est incrémentée qu'après une sortie.

| requête | réponse |
|---|---|
| `WAGO_GET_LAYOUT` | `WAGO_LAYOUT <start_addr_in> <start_addr_out> <scan_error> <dali647_in> <dali647_out> <feedback_last>` |
| `WAGO_GET_INFO_MODULE <n>` | `WAGO_MODULE <n> <moduleType> <physicalPos> <sizePAE> <sizePAA> <posPAE> <posPAA> <channels> <altFormat>` — les quatre derniers sont nouveaux, **en fin**. Hors `0..63`, les huit champs valent `NA` : la trame garde ses 10 champs |
| `WAGO_GET_OUTPUT_WORD <w>` | `WAGO_OUTPUT_WORD <w> <valeur>` — lecture de l'image de sortie par `READ_OUTPUT_WORD`, sans variable localisée. `<valeur>` vaut `NA` si le bloc rend `ERROR` : une lecture refusée ne doit pas ressembler à un mot qui vaut 0 |
| `WAGO_GET_STATE` | `WAGO_STATE <cycle> <outloop> <branch> <hb> <hb_et_ms> <led> <err_dig> <err_dali>` |
| `WAGO_GET_NETOUT_WORD <w>` | `WAGO_NETOUT_WORD <w> <valeur\|NA>` — `netOutStandard` tel que le programme le lit. `<w>` en mots, `0..15` |
| `WAGO_GET_OUTSTATE_WORD <w>` | `WAGO_OUTSTATE_WORD <w> <valeur\|NA>` — la table dégradée `OutArrState`. `<w>` en mots **absolus**, `0..255` |
| `WAGO_GET_WRITTEN_WORD <w>` | `WAGO_WRITTEN_WORD <w> <valeur\|NA>` — la dernière valeur passée à `WRITE_OUTPUT_WORD` pour ce mot. `NA` tant que rien n'y a été écrit depuis le démarrage |
| `WAGO_GET_OUTPUT_CHAIN <n>` | `WAGO_OUTPUT_CHAIN <n> <word> <bit> <netout> <outstate> <written> <readback>` — les quatre maillons pour la sortie `n`, l'automate résolvant lui-même mot et bit |

Unités : `start_addr_*` et `posPA*` en **bits**, `dali647_*` et `<w>` en **mots**. `scan_error` est le
`ScanError` de [PROCESS-IMAGE.md](PROCESS-IMAGE.md).

`dali647_in`, `dali647_out` et `feedback_last` valent la chaîne **`NA`** quand `CONFIG_DALI_647` est
faux. Pas `0` : personne n'écrit le feedback sans la borne, et `0` est son « tout va bien » — la
même règle que `WAGO_DALI_GET ERR`, appliquée à nous-mêmes. `feedback_last` est le dernier
`bFeedback` **non nul** du maître 647 ; il n'est jamais remis à zéro.


`WAGO_GET_OUTPUT_CHAIN` existe pour que **l'automate** convertisse le numéro de sortie en mot et en
bit : chaque conversion d'unité laissée à l'outil est un endroit de plus où la confusion
bit / octet / mot peut revenir, et c'est de là que venait T-2. Les quatre maillons se lisent dans
l'ordre `netout → outstate → written → readback` ; le cinquième, l'image physique, se lit en Modbus
(`0x0200 + word`). Le premier maillon qui ne porte pas la valeur attendue nomme le défaut.

`branch` vaut `0` si le bloc de sortie ne tourne pas (`nb_module_out = 0`), `1` en mode dégradé,
`2` en mode serveur. `cycle` et `outloop` avancent ensemble tant que le bloc s'exécute : les deux
figés disent « programme arrêté », `outloop` figé seul dit « bloc non atteint ». `err_dig` et
`err_dali` sont l'`ERROR` de `WRITE_OUTPUT_WORD`, agrégé sur toute la boucle du cycle.

⚠️ `UDPServer` s'exécute **avant** le bloc de sortie : les compteurs, `branch` et les deux drapeaux
d'erreur datent donc du cycle précédent. Sans conséquence pour un diagnostic, mais à savoir en
lisant une trace.

⚠️ `WAGO_MODULE` gagne quatre champs en fin. Si `calaos_server` ou `calaos_installer` parse cette
réponse par **nombre** de champs, il faut le vérifier dans `calaos_base` avant de déployer ; un
lecteur positionnel qui ne lit que les cinq premiers ne voit rien.

Ces verbes tombent sous le filtre `udpReplyMisattributedToDaliGet` **uniquement** pendant une lecture
DALI en vol : sur banc, ne pas enchaîner les deux.

## Sérialisation des requêtes

`WagoMap::UDPCommand_cb` ne sort rien tant que la commande en tête est `inProgress`, et
`udpRequest_cb` ne dépile qu'à la réponse : **une seule commande est en vol à la fois**. Deux
conséquences pour l'automate :

- les courses décrites en [T-8](done/T-8.md) ne peuvent pas venir de `calaos_server` ; les latches
  posés côté automate sont une défense contre un autre émetteur UDP, pas contre lui ;
- une lecture sans réponse bloque la file **2 s**, le temps du délai. Répondre une erreur coûte donc
  strictement moins cher que se taire.
