# calaos_wago — Wago_4.0 (CoDeSys 2.3 / WAGO-I/O-PRO)

Programme automate WAGO pilote par Calaos (domotique). La 4.0 est une reprise
du code de `../Wago_3.0`, retravaillee ici. Tout se passe dans ce dossier.

## Ce que tu peux et ne peux pas toucher
- Le **source** est `src/common/*.exp` (partage) et `src/targets/<cible>/*.exp`
  (specifique). C'est la seule chose que tu edites.
- **Jamais** les `pro\wago_XXX.pro` : binaire proprietaire, regenere par
  `tools\build.cmd`. Leur repertoire de bibliotheques est relatif au `.pro`
  lui-meme : depuis `pro\`, c'est `..\..\Additionnal`. Un `.pro` repris de la
  3.0 porte `..\Additionnal` et doit etre corrige, sinon les libs ne se
  resolvent plus.
- **Jamais** `../Wago_3.0/` : c'est la reference, en lecture seule.
- Pas de `online login`, pas de telechargement vers un automate. Jamais. Seule
  exception : `online bootproject`, que `build.cmd` emet **hors ligne** pour ecrire
  `pro\*.PRG` + `.CHK` a cote du `.pro` - aucune connexion, aucun envoi.

## Boucle de travail obligatoire
1. Modifier les `.exp`.
2. `tools\build.cmd <cible>` (une cible) ou `tools\build_all.cmd` (toutes).
3. Lire `build\logs\build_<cible>.log`. Corriger jusqu'a `BUILD OK`.
4. Une tache n'est terminee que si **toutes** les cibles impactees compilent.
   - modif dans `src/common/`  -> `build_all.cmd` obligatoire
   - modif dans `src/targets/X/` -> `build.cmd X` suffit
5. Committer `src/` **et** `pro/` ensemble apres un build vert - les `.pro` et les boot
   projects `.PRG` + `.CHK` que le build regenere (sinon ils divergent).

## Commentaires
- Commenter le **pourquoi** et les pieges qui ne se deduisent pas du code.
- Ne pas ecrire : ce que le code fait, des numeros de ticket, des phases, des
  jalons, des emojis, l'historique du debug, ou « on a trouve que ».
- Max ~8 lignes pour un bloc vraiment non evident. Sinon 1 a 3 lignes.
- Les decisions d'architecture vont dans `docs/`, pas dans le code.
- Ne pas « documenter pour le prochain LLM ». Ecrire pour un humain qui relira
  le diff.
- S'aligner sur les fichiers deja propres ; ne pas amplifier le style verbeux
  existant.

## Tickets
`docs/board.md` est le tableau de suivi : il porte la convention complete et l'etat
de chaque fiche. En bref : une fiche ouverte est dans `docs/todo/`, une fiche close
dans `docs/done/` (deplacee par `git mv`), et la ligne `**Statut**` en tete de fiche
fait foi. Un ticket n'est clos qu'apres 7 x `BUILD OK`, un aller-retour verifie, et
une relecture par l'agent `codesys-review`. Un commit separe par ticket.

## Cibles
`841 849 880 881 889 891 893` (WAGO 750-xxx). Meme code partout, sauf :
- **849** : `PROGRAM KNX_Master` en plus (controleur KNX/IP, lib `KNX_IP_750_849_01`).
- **891 / 893** : versions de bibliotheques WAGO plus recentes (meme API).
Le classement initial common/targets est dans `build/export_report.txt`.
Si un objet est present dans plusieurs `targets/<x>/` avec le meme contenu, c'est
un candidat a remonter dans `common/` — propose-le, ne le fais pas d'office.

## Contraintes CoDeSys 2.3 (pas V3 !)
- IEC 61131-3 ancienne generation : pas de METHOD, pas d'INTERFACE, pas de
  namespaces, pas de `{IF defined}`. Heritage inexistant.
- `STRING` = 80 caracteres par defaut. Pointeurs via `ADR()` / `POINTER TO`.
- Pas de preprocesseur : les differences par cible passent par des fichiers
  dans `targets/<x>/`, ou par des constantes dans une GVL specifique a la cible.
- Adresses physiques `%IX/%QX/%IW/%QW` : uniquement dans la config automate
  ou une GVL de mapping, jamais dans le code metier.

## Format `.exp`
- Un fichier par objet (POU, DUT, GVL, config). Texte ANSI (Windows-1252),
  **pas UTF-8** : conserver l'encodage, surtout pour les accents des commentaires.
- Chaque objet est precede d'en-tetes `(* @NESTEDCOMMENTS := ... *)`,
  `(* @PATH := ... *)`, `(* @OBJECTFLAGS := ... *)` etc. **Ne pas les modifier.**
- Les POU en ST sont directement editables. Les POU en FBD/LD/CFC/SFC ont un
  format texte fragile : signale-les, ne les edite pas.
- Le Library Manager exporte les chemins des libs et des horodatages ; ne pas les
  "nettoyer". La resolution reelle passe par le repertoire relatif `..\Additionnal\`
  defini dans les options du projet.

## Architecture heritee de la 3.0 (a confirmer en lisant le code)
POU : `PLC_PRG` (cycle principal), `UDPServer` / `EthernetServer_FB` /
`Ethernet_Client` (protocole Calaos), `SendInput` / `ManageOutput` (E/S),
`Config` / `Config_File_XML` (config), `DaliPrg647` / `DaliReadCsvFile` /
`DaliSendSensor` / FB `DaliSwitch` / `DaliDimValue` (DALI sur 753-647),
`DMX`, FB `LIGHT` / `VOLET` (volets : `VOLET_MODE`), `LedUsr`.
Libs projet dans `../Additionnal/` : DALI_02, DALI_647_*, DMXStageProfi, KNX_*.
La 3.0 exige un module DALI multi-master 753-647 (voir `../Wago_3.0/README.md`).

## Objectifs de la 4.0
(a completer par le mainteneur)
-
-

## Premiere tache attendue
Avant toute modification : lire `build/export_report.txt` puis tous les `.exp`,
produire un inventaire (POU + langage, DUT, GVL, libs, E/S utilisees) et une
liste des points a retravailler. Ne rien editer a cette etape.
