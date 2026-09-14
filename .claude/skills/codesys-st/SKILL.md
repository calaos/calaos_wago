---
name: codesys-st
description: Expertise automate CoDeSys 2.3 / WAGO-I/O-PRO pour ce depot - langage ST (IEC 61131-3 ancienne generation), format d'export .exp, workflow export/build en ligne de commande, specificites des cibles WAGO 750-xxx. A charger avant toute lecture ou modification de src\common\*.exp, src\targets\<cible>\*.exp, des scripts tools\*.cmd, ou de tout code Structured Text du projet Calaos WAGO.
---

# CoDeSys 2.3 / WAGO-I/O-PRO — programme Calaos

Tout le travail se fait dans `Wago_4.0\`. Lis `Wago_4.0\CLAUDE.md` et
`Wago_4.0\README.md` avant d'agir ; ce document ne les remplace pas, il donne
le savoir-faire CoDeSys que ces fichiers supposent acquis.

## Regles absolues

- **CoDeSys 2.3, pas V3.** Pas de `METHOD`, pas d'`INTERFACE`, pas de
  namespaces, pas de `{IF defined}`, pas d'heritage, pas de generiques.
- **Ne jamais editer les `.pro`** (`Wago_4.0\pro\wago_XXX.pro`) : binaires
  proprietaires, regeneres par `tools\build.cmd`.
- **Ne jamais toucher** `..\Wago_3.0\` (reference en lecture seule) ni
  `..\Additionnal\` (bibliotheques).
- **Aucune commande `online ...`** (`online login`, `online run`,
  `online bootproject`, `online sourcecodedownload`), aucun telechargement vers
  un automate. Jamais, meme pour tester.
- Adresses physiques `%IX/%QX/%IW/%QW` : uniquement dans la config automate ou
  une GVL de mapping, jamais dans le code metier.

## Les 7 cibles

`841 849 880 881 889 891 893` (WAGO 750-xxx). Meme code partout, sauf :

- **849** : `PROGRAM KNX_Master` en plus (controleur KNX/IP, lib
  `KNX_IP_750_849_01`). 88 objets au lieu de 87.
- **891 / 893** : bibliotheques WAGO plus recentes, meme API. Leurs entrees de
  Library Manager portent un nom different des 5 autres.

Classement du source :

- `src\common\` : objet identique sur les 7 cibles.
- `src\targets\<cible>\` : objet absent ailleurs, ou different d'une cible a
  l'autre.

`build\export_report.txt` dit qui est ou et pourquoi. Actuellement 79 communs
et 11 specifiques ; les objets specifiques sont notamment `CONFIG`,
`MANAGEOUTPUT`, `PLC_PRG`, `UDPSERVER`, `VARIABLES_GLOBALES`,
`TASK CONFIGURATION` et `KNX_MASTER` (849 seule).

Un objet present dans plusieurs `targets/<x>/` avec un contenu identique est un
candidat a remonter dans `common/` : **le proposer, ne pas le faire d'office.**

## Format `.exp`

Un fichier par objet. Exemple d'en-tete :

```
(* @NESTEDCOMMENTS := 'Yes' *)
(* @PATH := '' *)
(* @OBJECTFLAGS := '0, 8' *)
(* @SYMFILEFLAGS := '0' *)
PROGRAM UDPServer
VAR
	...
END_VAR
```

- **Encodage ANSI (Windows-1252), pas UTF-8.** Conserver l'encodage, surtout
  pour les accents des commentaires. Un fichier reecrit en UTF-8 fait apparaitre
  des `Ã©` dans l'IDE.
- **Fins de ligne CRLF**, indentation par **tabulations**.
- **Ne jamais modifier les en-tetes `(* @... *)`.**
- Les noms de fichiers exportes sont en **MAJUSCULES** (`UDPSERVER.EXP`), et
  certains contiennent espaces et points (`ALARM CONFIGURATION.EXP`,
  `STANDARD.LIB 2.12.10 14_48_34.EXP`).
- Les POU en **ST** sont directement editables. Les POU en **FBD/LD/CFC/SFC**
  ont un format texte fragile : **les signaler, ne pas les editer.**
- Le Library Manager est exporte comme un objet par bibliotheque, horodatage
  dans le nom. Ne pas "nettoyer" ces fichiers.

### Commentaires

- Commenter le **pourquoi** et les pièges qui ne se déduisent pas du code.
- Ne pas écrire : ce que le code fait, des numéros de ticket, des phases, des
  jalons, des emojis, l'historique du débug, ou « on a trouvé que ».
- Max ~8 lignes pour un bloc vraiment non évident. Sinon 1 à 3 lignes.
- Les décisions d'architecture vont dans `docs/`, pas dans le code.
- Ne pas « documenter pour le prochain LLM ». Écrire pour un humain qui relira
  le diff.
- S'aligner sur les fichiers déjà propres ; ne pas amplifier le style verbeux
  existant.

### Modification minimale

Editer un `.exp` = changer les lignes concernees et rien d'autre. Pas de
reindentation, pas de reformatage, pas de reecriture des commentaires : le
diff doit se lire en une seconde et l'aller-retour vers le `.pro` doit rester
neutre.

## Langage ST — ce qui mord ici

### Chaines

- `STRING` sans taille = **80 caracteres**. Au-dela il faut declarer
  `STRING(255)` explicitement (c'est le cas de `cmd: STRING(255)` dans
  `UDPServer`).
- **`CONCAT` renvoie un `STRING(80)`** dans la lib Standard : enchainer des
  `CONCAT` sur une chaine longue **tronque silencieusement**. Sur les reponses
  du protocole Calaos, verifier la longueur totale attendue.
- Fonctions Standard.lib : `CONCAT`, `LEN`, `LEFT`, `RIGHT`, `MID`, `FIND`,
  `INSERT`, `DELETE`, `REPLACE`.
- Helpers maison du projet : `ITOA` (int -> chaine), `Strncmp` (comparaison de
  prefixe, renvoie `BOOL`), `GET_PARAM_DINT` (n-ieme parametre d'une commande),
  `WORD_TO_STRB`.
- Litteraux chaine en **apostrophes simples** : `'WAGO_GET_VERSION '`.

### Types et conversions

- Conversions explicites obligatoires : `WORD_TO_INT`, `DINT_TO_UINT`,
  `INT_TO_STRING`... Pas de promotion implicite.
- `:=` affecte, `=` compare. Pas de `==`.
- Pointeurs via `ADR()` et `POINTER TO`. Pas de verification de limites :
  un depassement sur `ARRAY[1..1500] OF BYTE` corrompt la memoire sans
  diagnostic.

### Structure

- Blocs : `IF ... THEN ... ELSIF ... ELSE ... END_IF`, `CASE ... OF ... END_CASE`,
  `FOR ... TO ... BY ... DO ... END_FOR`, `WHILE`, `REPEAT ... UNTIL`.
- Pas de `break`/`continue` ; `EXIT` sort d'une boucle, `RETURN` d'un POU.
- Un bloc fonctionnel s'**instancie** en `VAR` puis s'appelle :
  `HEARTBEAT_TIMER(IN := x, PT := T#1s);` puis on lit `HEARTBEAT_TIMER.Q`.
- Commentaires `(* ... *)`, imbricables (`@NESTEDCOMMENTS := 'Yes'`).

### Temps de cycle

`PLC_PRG` s'execute a chaque cycle. Aucune boucle bloquante, aucune attente
active : tout ce qui dure s'ecrit en machine a etats avec un `TON`/`TOF`.

## Pas de preprocesseur : comment gerer une difference par cible

Il n'existe **ni `#ifdef` ni constante de compilation**. Les seules facons
propres de differencier une cible :

1. Mettre l'objet entier dans `src\targets\<cible>\` (c'est le cas de
   `UDPSERVER.EXP`, `PLC_PRG.EXP`, `CONFIG.EXP`...).
2. Mettre une **constante dans une GVL ou un POU de config specifique a la
   cible**, et garder le code metier commun.

La solution 2 est preferable quand seule une valeur change : elle evite de
dupliquer des centaines de lignes pour un litteral, et elle reduit le risque
qu'une correction future soit appliquee a une cible et oubliee sur les six
autres.

## Boucle de travail obligatoire

Depuis `Wago_4.0\` :

1. Modifier les `.exp` dans `src\`.
2. `tools\build.cmd <cible>` ou `tools\build_all.cmd`.
3. Lire `build\logs\build_<cible>.log`. Corriger jusqu'a `BUILD OK`.
4. Une tache n'est terminee que si **toutes** les cibles impactees compilent :
   - modif dans `src\common\` -> `build_all.cmd` **obligatoire** ;
   - modif dans `src\targets\X\` -> `build.cmd X` suffit.
5. Committer `src\` **et** `pro\*.pro` ensemble apres un build vert.

`tools\build.cmd` fait : import des `.exp` -> `project rebuild` -> `file save`.
Il **reecrit donc le `.pro`**. Commiter avant d'experimenter.

## Pilotage de CoDeSys en ligne de commande

Reference complete verifiee : **`Wago_4.0\tools\CMDFILE_REFERENCE.md`**. A lire
avant de toucher a un script `tools\*.cmd`. Les trois pieges deja payes :

- **Ne jamais remettre `/batch`** : inoperant sur cette installation, CoDeSys
  rend la main en `0x80044103` sans executer la moindre commande, donc sans
  produire le moindre log. La forme qui marche est
  `Codesys.exe /cmd <fichier.cds>`, fenetre visible.
- **Garder `query off`** (forme nue, non documentee). `query off ok` repond
  `Yes` a « Taskconfig import: overwrite the system events? » et ecrase les
  evenements systeme a chaque build ; `query off` repond `No`.
- En `.cmd`, compter les exports avec **`find /c /i ".exp"`** : les fichiers
  produits sont en majuscules et `find` est sensible a la casse.

`out open` **ajoute** au fichier de messages : supprimer le log avant chaque
lancement, sinon on relit un vieux resultat.

## Ce que CoDeSys normalise a l'import — ne pas s'en alarmer

Au premier import, CoDeSys reecrit legerement le source :

- il supprime les lignes vides en fin de corps de POU, juste avant
  `END_PROGRAM` / `END_FUNCTION_BLOCK` ;
- il renomme les entrees de Library Manager (`<lib>.LIB_<date>` devient
  `<lib>.LIB <date>`).

C'est deja absorbe dans `src\`. Les cycles suivants sont idempotents : apres un
`build_all` puis un `export_all`, les 610 objets re-exportes sont identiques
octet pour octet a `src\`. **Si un re-export fait apparaitre d'autres
differences que celles qu'on vient d'ecrire, c'est un signal : enqueter.**

Le `.pro`, lui, n'est **pas** reproductible octet pour octet : il embarque les
informations de compilation et apparait modifie apres chaque build meme a
source identique. Ce qui fait foi, c'est que le re-export redonne `src\`.

## Verifier une modification

Apres un build vert, la verification qui compte est l'aller-retour :

```
tools\export.cmd <cible>
```

puis comparer `build\export\<cible>\*.EXP` a `src\` (encodage 1252). Seules les
lignes qu'on a voulu changer doivent differer. C'est ce qui detecte qu'un
import a silencieusement mange autre chose.
