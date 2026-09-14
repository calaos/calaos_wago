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
servir. Raison émise aujourd'hui : `GROUP_UNSUPPORTED` — relecture d'un groupe sur un bus DALI
standard, impossible par construction (une trame retour DALI vient d'un seul appareil, une requête
adressée à un groupe provoquerait une collision ; le chemin 753-647, lui, répond car il tient sa
propre image côté programme).

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

## Sérialisation des requêtes

`WagoMap::UDPCommand_cb` ne sort rien tant que la commande en tête est `inProgress`, et
`udpRequest_cb` ne dépile qu'à la réponse : **une seule commande est en vol à la fois**. Deux
conséquences pour l'automate :

- les courses décrites en [T-8](done/T-8.md) ne peuvent pas venir de `calaos_server` ; les latches
  posés côté automate sont une défense contre un autre émetteur UDP, pas contre lui ;
- une lecture sans réponse bloque la file **2 s**, le temps du délai. Répondre une erreur coûte donc
  strictement moins cher que se taire.
