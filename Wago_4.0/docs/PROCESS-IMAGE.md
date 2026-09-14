# Image process K-Bus — ce que le programme suppose, et pourquoi

## Les unités en circulation

Trois unités coexistent, et une confusion entre deux d'entre elles est à l'origine de T-2.

| Variable | Unité | Producteur | Consommateurs |
|---|---|---|---|
| `posPAA`, `posPAE`, `sizePAA`, `sizePAE` (`MODULE_INFO.desc`) | **bits** | `ADD_PI_INFORMATION` (mod_com) | `Config` |
| `start_addr_in`, `start_addr_out`, `nb_input_digital`, `nb_output_digital` | **bits** | `Config` | `GetInput`, `SetOutput`, `SendInput`, `ManageOutput`, `PLC_PRG`, `SeedOutputState`, `WAGO_SET_OUTPUT` |
| `OutArrState[]` | **octets** (bit `n` ⇒ `[n / 8]`, `MOD 8`) | `SetOutput`, `PLC_PRG` | `PLC_PRG`, `SeedOutputState` |
| `WORD_ADDRESS` de `read_word`, `write_word`, `read_bit` | **mots** | — | `PLC_PRG` (`start_addr_out / 16`), `GetInput` (`bit / 16`, `MOD 16`), `DaliPrg647` |
| `Config.AddrDali647In`, `AddrDali647Out` | **mots** | `Config` (`posPAE / 16`, `posPAA / 16` du module 647) | `DaliPrg647` |

`AddrDali647*` ne sont valides que si `Config.CONFIG_DALI_647 = TRUE`. Sinon ils valent 0, qui est
une adresse légitime : ne jamais s'en servir comme sentinelle.

`sizePAA` / `sizePAE` sont des `BYTE` : un module complexe de plus de 255 bits ne peut pas être
décrit. Aucun module Calaos connu n'atteint cette taille ; à savoir avant d'en ajouter un.

## L'hypothèse de regroupement

Le coupleur WAGO construit l'image process en plaçant **tous les modules complexes** (orientés mot :
analogiques, DALI, KNX, série…) **d'abord**, dans leur ordre physique, puis **tous les modules
digitaux** (orientés bit), packés bit à bit, dans leur ordre physique — quelle que soit la position
physique des uns par rapport aux autres.

Ce que cela garantit, et sur quoi tout l'aval repose :

- les digitaux de sortie forment **un bloc contigu** commençant à `start_addr_out`, et ceux
  d'entrée un bloc contigu commençant à `start_addr_in` — un scalaire suffit ;
- `start_addr_out` est un **multiple de 16**, les complexes étant alignés mot — les cinq divisions
  par 8 et 16 de `PLC_PRG` ne tronquent pas ;
- les mots de la 647 sont **avant** `start_addr_out / 16` : les boucles `write_word` des digitaux ne
  la recouvrent jamais.

Ce que `ScanError` vérifie, sans rien changer au comportement :

| bit | condition |
|---|---|
| `SCAN_ERR_IN_GAP` | un digital d'entrée dont `posPAE ≠ start_addr_in + cumul` |
| `SCAN_ERR_OUT_GAP` | un digital de sortie dont `posPAA ≠ start_addr_out + cumul` |
| `SCAN_ERR_OUT_ALIGN` | `start_addr_out MOD 16 ≠ 0` |
| `SCAN_ERR_DALI647_ALIGN` | `posPAE` ou `posPAA` de la 647 non multiple de 16 |

Si l'hypothèse tombe — un rack R2 de [BENCH-647.md](BENCH-647.md) qui donne `start_addr_out = 32`
au lieu de 192 — la boucle dégradée de `PLC_PRG`, qui écrit jusqu'au mot 255, passerait par-dessus
la 647 : il faudrait la borner à `(start_addr_out + nb_output_digital - 1) / 16`. Si `OUT_GAP` se
lève, un complexe est intercalé dans le bloc digital et les scalaires ne suffisent plus : c'est le
seul résultat qui rouvrirait la table d'indirection écartée par décision.

## Classification des modules

`channels > 0` ⇒ complexe ; sinon digital si `size > 0`. **Sans borne de taille** : un digital 32
voies et un analogique 8 bits tombent dans la bonne case, ce que les anciennes bornes `<= 16` et
`> 8` empêchaient.

`moduleType IN (641, 647)` — et 646 sur la 849 — force « complexe » indépendamment de `channels`.
La sémantique de `channels` vient de `mod_com`, dont seule la table de symboles est lisible ; ce
qu'il vaut pour une 647 n'a jamais été lu. Si c'était 0, le critère nu compterait la borne comme 192
sorties digitales et `start_addr_out` vaudrait 0 : la boucle d'écriture écraserait sa boîte aux
lettres. `altFormat` existe dans le descripteur et n'est lu par personne ; sens inconnu.

## Pourquoi plus aucune variable localisée sur `%IB0` / `%QB0`

Une variable `AT %QB0` marque `%QB0..23` comme possédés par l'image IEC **par sa déclaration**, pas
par son usage. Le garde qui n'appelle `DaliPrg647` qu'avec une 647 présente ne protège que
l'exécution : sans la borne, le rafraîchissement d'image écrase à chaque cycle ce que `write_word` a
écrit dans ces 24 octets — les 192 premières sorties digitales sont mortes. C'est le symptôme mesuré
au banc qui a justifié le fichier-marqueur de la 3.0.

`FbMaster753_647` prend ses tableaux par valeur (`VAR_INPUT` / `VAR_OUTPUT`, jamais `VAR_IN_OUT`) :
il n'exige aucune localisation, le `AT %IB0` de la documentation WAGO est un exemple. Le programme
utilise donc **un seul idiome** pour toute l'image physique : `read_word` / `write_word` /
`read_bit`, à des adresses calculées par le balayage. La bibliothèque WAGO 641 fait de même —
`FbDALI_Joblist` embarque trois `READ_INPUT_WORD` et trois `WRITE_OUTPUT_WORD`.

La 1.7 était « tout localisé, zéro Mod_com » et fonctionnait sur 750-842, dont Modbus atteignait
l'image de sortie. Les 750-841/849/880 ne le permettent plus : depuis la 1.8, le serveur écrit
`netOutStandard AT %IB512` (zone PFC, coil 4096) et le programme recopie vers les sorties par
`write_word`. **`%QB` appartient au PLC ; c'est Modbus qui n'y accède plus.** Les deux mondes ne se
croisent pas, et c'est ce qui rend l'idiome unique possible.

## Hors périmètre, par décision

- **Table d'indirection** id logique → bit physique : seulement si `OUT_GAP` se lève un jour.
- **Refuser d'écrire** quand `ScanError ≠ 0` : décision d'architecture, pas un diagnostic.
- **Borner la boucle dégradée** par `nb_output_digital` : hygiène, mais aval de ce sujet.
- **Unifier 641 et 647** : bloqué par les bibliothèques elles-mêmes (modèles opposés, retours
  incompatibles, « Both modules cannot be used at the same time »).
- **Faire converger le moteur de règles dégradé et celui de `calaos_server`** : décision de l'auteur,
  ne pas rouvrir.
- **Sentinelle de `Config_File_XML`** (`physicalPos <> 0` seul) ≠ celle de `Config`
  (`moduleType = 0 AND physicalPos = 0`) : équivalentes si `physicalPos` est 1-basé, non mesuré ;
  toucher `Config_File_XML` engage un `FirmwareReset`.
