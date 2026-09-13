# Commandes cmdfile CoDeSys 2.3 (WAGO-I/O-PRO)

Extrait de l'aide installee :
`C:\Program Files (x86)\WAGO Software\CODESYS V2.3\Documents\English\CoDeSys_V23_E.pdf`,
annexe F « Command Line-/Command File », chapitres 10.24 et 10.25.

Les commandes marquees **[verifie]** ont ete testees sur cette installation
avec `wago_881.pro`. Celles marquees **[non teste]** sont reprises de l'aide
telle quelle.

> Les commandes `online ...` sont listees pour etre completes. **Elles sont
> interdites dans ce depot** (aucun acces automate) — voir `CLAUDE.md`.

## Appel

```
"<chemin de codesys.exe>" /cmd "<chemin du fichier .cds>"
```

Forme generale documentee :

```
"<codesys.exe>" "<projet.pro>" /<commande1> /<commande2> ...
```

## Regles de syntaxe du fichier de commandes

- Pas de sensibilite a la casse.
- Un `;` commence un commentaire : tout ce qui suit est ignore.
- Les parametres contenant des espaces doivent etre entre guillemets. **[verifie]**
- Prefixer une commande par `@` empeche son affichage dans les messages.
- Les caracteres accentues ne sont permis que si le fichier est en **ANSI**
  (c'est ce que produit `echo` sous cmd, donc OK par defaut).
- Mots-cles utilisables dans les parametres, entoures de `$` :
  `$PROJECT_NAME$`, `$PROJECT_PATH$`, `$PROJECT_DRIVE$`, `$COMPILE_DIR$`,
  `$EXE_DIR$`.

## Options de ligne de commande (10.24)

| Option | Effet |
|---|---|
| `/cmd <cmdfile>` | execute les commandes du fichier **[verifie]** |
| `/batch` | demarre sans interface et renvoie le code d'erreur ; **inutilisable ici, voir plus bas** |
| `/out <outfile>` | duplique tous les messages dans `<outfile>` |
| `/show hide\|icon\|max\|normal` | etat de la fenetre CoDeSys |
| `/noinfo` | pas d'ecran de demarrage |
| `/userlevel <groupe>` | groupe d'utilisateurs |
| `/password <mdp>` | mot de passe du groupe |
| `/notargetchange` | changement de cible uniquement via la commande `target` |
| `/online`, `/run`, `/openfromplc`, `/visudownload` | **interdits ici** (acces automate) |

### `/batch` ne fonctionne pas sur cette installation **[verifie]**

C'est la cause du blocage initial du projet. Avec `/batch`, CoDeSys rend la
main immediatement avec le code `-2147204861` (`0x80044103`) **sans executer
la moindre commande** — pas meme `out open`, donc aucun log n'est produit.

Teste sur `wago_881.pro`, l'echec est independant du contenu du `.cds` :

| variante | `/batch` | resultat |
|---|---|---|
| `query off ok` (forme documentee) | oui | echec, 0 objet |
| `query off` + `onerror continue` | oui | echec, 0 objet |
| aucune ligne `query` | oui | echec, 0 objet |
| projet passe en 1er argument | oui | echec, 0 objet |
| `query off` | **non** | OK, 87 objets |
| `query off ok` | **non** | OK, 87 objets |

Ce n'est donc pas un probleme de syntaxe du fichier de commandes.
**Ne pas remettre `/batch` dans les scripts.** La fenetre CoDeSys s'affiche
pendant l'operation, sans consequence ; les dialogues sont traites par
`query off`.

## Controle du deroulement

| Commande | Effet |
|---|---|
| `onerror continue` | poursuit malgre une erreur **[non teste]** |
| `onerror break` | arrete a la premiere erreur **[non teste]** |
| `delay <ms>` | attente **[non teste]** |
| `call <cmdfile> <p1> ... <p10>` | appelle un autre `.cds`, parametres en `$0`-`$9` **[non teste]** |
| `system <commande>` | commande systeme **[non teste]** |

## Dialogues

| Commande | Effet |
|---|---|
| `query on` | les dialogues s'affichent et attendent l'utilisateur |
| `query off ok` | tous les dialogues repondent « OK » **[verifie]** |
| `query off no` | tous les dialogues repondent « No » **[non teste]** |
| `query off cancel` | tous les dialogues repondent « Cancel » **[non teste]** |

### `query off` sans argument : non documente mais c'est ce qu'on utilise **[verifie]**

L'aide ne decrit que les trois formes `query off ok|no|cancel`. La forme nue
`query off` fonctionne pourtant, et elle ne se comporte pas comme
`query off ok` : elle semble choisir le **bouton par defaut de chaque
dialogue**. Mesure sur le meme import :

| dialogue rencontre | `query off` | `query off ok` |
|---|---|---|
| `PRINTPROGRESS` (OK) | `Ok` | `Ok` |
| `The version of at least one library has changed...` (OK) | `Ok` | `Ok` |
| `Taskconfig import: Do you want to overwrite the system events?` (YESNO) | **`No`** | **`Yes`** |

Les scripts gardent volontairement **`query off`** : repondre `No` preserve les
evenements systeme de la configuration de taches deja presents dans le `.pro`,
et c'est avec cette reponse que l'aller-retour `.exp -> .pro -> .exp` a ete
verifie idempotent sur les 7 cibles. Passer a `query off ok` ecraserait les
evenements systeme a chaque build.

## Remplacement d'objets a l'import

| Commande | Effet |
|---|---|
| `replace yesall` | remplace tout, sans dialogue **[verifie]** |
| `replace noall` | ne remplace rien, sans dialogue **[non teste]** |
| `replace query` | redemande, meme apres `yesall`/`noall` **[non teste]** |

## Fichier de messages

| Commande | Effet |
|---|---|
| `out open <msgfile>` | ouvre le fichier de messages ; les messages sont **ajoutes** **[verifie]** |
| `out close` | ferme le fichier **[verifie]** |
| `out clear` | vide le fichier courant **[non teste]** |
| `echo on` / `echo off` | affiche ou non les lignes de commande **[verifie]** |
| `echo <texte>` | affiche `<texte>` **[non teste]** |

`out open` **ajoute** au fichier existant : les scripts suppriment le log avant
de lancer CoDeSys, sinon les builds s'empilent et `findstr` lit un vieux
resultat.

## Menu File

| Commande | Effet |
|---|---|
| `file new` | nouveau projet **[non teste]** |
| `file open <projet>` | ouvre le projet **[verifie]** |
| `file open <projet> /readpwd:<mdp>` | mot de passe lecture **[non teste]** |
| `file open <projet> /writepwd:<mdp>` | mot de passe ecriture **[non teste]** |
| `file close` | ferme le projet **[non teste]** |
| `file save` | enregistre **[verifie]** |
| `file saveas <fichier> [<type><version>]` | `internallib`, `externallib`, `pro` + `15\|20\|21\|22` **[non teste]** |
| `file printersetup <f>.dfr` | cadre de document **[non teste]** |
| `file archive <f>.zip` | archive le projet **[non teste]** |
| `file quit` | quitte CoDeSys **[verifie]** |

## Menu Project

| Commande | Effet |
|---|---|
| `project build` | compilation incrementale **[non teste]** |
| `project rebuild` (= `project compile`) | compilation complete **[verifie]** |
| `project clean` | efface les infos de compilation **[non teste]** |
| `project check` | verification **[non teste]** |
| `project import <f1> ... <fN>` | importe ; **jokers acceptes** **[verifie]** |
| `project export <expfile>` | exporte tout le projet dans un seul fichier **[non teste]** |
| `project expmul` | un fichier par objet, nomme d'apres l'objet **[verifie]** |
| `project documentation` | impression **[non teste]** |

### `project expmul` accepte un dossier, contrairement a l'aide **[verifie]**

L'aide ne documente **aucun parametre** pour `expmul`. En pratique
`project expmul <dossier>` ecrit bien un fichier par objet dans `<dossier>`.
C'est la forme utilisee par `tools\export.cmd`.

Deux pieges :

1. Les fichiers produits sont nommes en **MAJUSCULES** (`PLC_PRG.EXP`), et
   certains contiennent des espaces et des points
   (`ALARM CONFIGURATION.EXP`, `STANDARD.LIB 2.12.10 14_48_34.EXP`).
   En `.cmd`, `find /c ".exp"` renvoie donc **0** : `find` est sensible a la
   casse, il faut `find /c /i ".exp"`.
2. Le Library Manager est exporte comme un objet par bibliotheque, avec
   l'horodatage dans le nom. Le nom est normalise au premier import
   (`<lib>.LIB_<date>` devient `<lib>.LIB <date>`).

### `project import` accepte les jokers **[verifie]**

`project import "<dossier>\*.exp"` importe tous les `.exp` du dossier et
compile sans erreur. `tools\build.cmd` genere malgre tout **une ligne par
fichier** : le log indique alors precisement quel objet a ete importe, ce qui
est utile quand un import echoue.

## Bibliotheques, objets, repertoires

| Commande | Effet |
|---|---|
| `library add <lib1> ... <libN>` | ajoute des bibliotheques (chemin relatif = relatif au repertoire de libs du projet) **[non teste]** |
| `library delete <lib>` | retire des bibliotheques **[non teste]** |
| `object copy <projet source> <chemin source> <chemin cible>` | copie des objets **[non teste]** |
| `object setreadonly <TRUE\|FALSE> <type> [<nom>]` | types : `pou`, `dut`, `gvl`, `vis`, `cnc`, `liblist`, `targetsettings`, `customplconfig`, `projectinfo`, `taskconfig`, `trace`, `watchentrylist`, `alarmconfig`, `toolinstanceobject`, `toolmanagerobject` **[non teste]** |
| `dir lib <rep>` | repertoire des bibliotheques **[non teste]** |
| `dir compile <rep>` | repertoire de compilation **[non teste]** |
| `dir config <rep>` | repertoire de configuration **[non teste]** |
| `dir upload <rep>` | repertoire d'upload **[non teste]** |

Plusieurs repertoires : separes par `;` + espace, le tout entre guillemets.

> `dir lib` n'est pas utilise ici : les `.pro` resolvent leurs bibliotheques via
> le repertoire relatif `..\Additionnal\` enregistre dans les options du projet.
> C'est pour cela qu'ils doivent rester a la racine de `Wago_4.0\`.

## Cible, mots de passe, etat

| Commande | Effet |
|---|---|
| `target <Id>` | change la cible **[non teste]** |
| `user level <groupe>` / `user password <mdp>` | a placer **avant** `file open` **[non teste]** |
| `state offline` / `state online` | renvoie `S_OK` selon l'etat **[non teste]** |

## Commandes volontairement non utilisees

`online login`, `online logout`, `online run`, `online stop`,
`online bootproject`, `online sourcecodedownload`, `online sim`,
`gateway local`, `gateway tcpip`, `device guid`, `device instance`,
`device parameter`, `watch list ...`, `eni ...`.

Les commandes `online ...` et `gateway`/`device` touchent a l'automate :
**interdites dans ce depot**.
