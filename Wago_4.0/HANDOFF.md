# Contexte et mission

Tu prends la suite d'une session de mise en place. Lis d'abord `CLAUDE.md` et `README.md`
dans ce dossier, puis ce qui suit.

## Situation

- Dépôt : `C:\work\calaos_wago` (GitHub calaos/calaos_wago). Programme WAGO 750-xxx pour
  la domotique Calaos, en **CoDeSys 2.3** (WAGO-I/O-PRO), pas V3.
- `..\Wago_3.0\` = version de référence, 7 fichiers `wago_XXX.pro` (841 849 880 881 889
  891 893). Code quasi identique sur toutes les cibles (la 849 a un `PROGRAM KNX_Master`
  en plus ; 891/893 ont des versions de libs plus récentes).
- `Wago_4.0\` (ici) = nouvelle version à construire. Structure :
  - `wago_XXX.pro` à la racine (copiés de la 3.0, ils référencent `..\Additionnal\`
    comme répertoire de bibliothèques **relatif** — ne pas les déplacer).
  - `src\common\` et `src\targets\<cible>\` : le source texte `.exp`, **encore vide**.
  - `tools\*.cmd` + `tools\sort_exports.ps1` : scripts d'automatisation.
  - `build\` : logs, exports, fichiers `.cds` générés (gitignored).
- Le `.pro` est un binaire propriétaire non éditable. Tout le workflow repose sur :
  `.pro` → export texte `.exp` (un par objet) → édition → réimport dans le `.pro` →
  rebuild → lecture du log. Piloté par `Codesys.exe` en mode ligne de commande avec un
  fichier de commandes (`/cmd fichier.cds`, optionnellement `/batch`).

## Ce qui marche

`tools\check_env.cmd` → `ENV OK` (exe trouvé, 7 .pro de référence, `..\Additionnal`,
7 targets installées). `tools\bootstrap.cmd` copie bien les 7 `.pro` à la racine.

## Ce qui bloque (à débugger en priorité)

`tools\export.cmd <cible>` lance CoDeSys avec un `.cds` contenant :
```
echo on
query off
replace yesall
out open C:\work\calaos_wago\Wago_4.0\build\logs\export_881.log
file open C:\work\calaos_wago\Wago_4.0\wago_881.pro
project expmul C:\work\calaos_wago\Wago_4.0\build\export\881
out close
file quit
```
Résultat : **aucun `.exp` produit et aucun fichier log créé** — donc `out open` n'a
jamais été exécuté, ce qui signifie que le fichier de commandes n'est probablement pas
interprété du tout, ou que CoDeSys s'arrête avant sur quelque chose d'invisible.
Les 7 cibles échouent de la même façon, très vite.

Corrections déjà appliquées dans la dernière version des scripts (non retestées) :
suppression des guillemets autour des chemins dans le `.cds`, `start "" /wait` pour
attendre la fin de CoDeSys, ajout de `echo on`, et un `tools\diag.cmd` qui fait le même
test **sans `/batch`** (CoDeSys visible).

## Hypothèses à tester, dans cet ordre

1. Lancer `tools\diag.cmd 881` et observer : dialogue ? projet chargé ? fenêtre vide ?
2. Syntaxe de ligne de commande. Formes à essayer (fenêtre cmd, pas PowerShell,
   depuis `Wago_4.0\`) :
   - `Codesys.exe /cmd build\cds\diag.cds`
   - `Codesys.exe wago_881.pro /cmd build\cds\diag.cds` (projet en 1er argument)
   - `Codesys.exe /batch /cmd build\cds\diag.cds`
   - chemins relatifs vs absolus dans le `.cds`
   - avec et sans guillemets dans le `.cds`
3. Un `.cds` réduit au strict minimum pour isoler la commande fautive :
   `out open build\logs\t.log` + `file quit` seuls, puis ajouter `file open`, puis
   `project export build\diag\all.exp`, puis `project expmul build\diag`.
4. Encodage/fin de ligne du `.cds` (il est généré par `echo` cmd → ANSI + CRLF ; tester
   LF, tester UTF-8 sans BOM, tester une ligne vide finale).
5. La commande `expmul` elle-même : si `project export <fichier>` marche mais pas
   `expmul`, on se contente du monofichier et on écrira un découpeur par objet (les
   objets sont délimités par des en-têtes `(* @NESTEDCOMMENTS := ... *)`,
   `(* @PATH := ... *)`, `(* @OBJECTFLAGS := ... *)`, etc.).
6. Si CoDeSys affiche un dialogue non couvert par `query off` (target modifié, lib
   introuvable, mot de passe, "projet modifié, sauver ?"), noter le texte exact et
   trouver la commande cmdfile ou l'option projet qui le supprime.
7. Consulter l'aide de WAGO-I/O-PRO installée (fichier .chm / .pdf dans le dossier
   d'installation, chapitre « Command Line / Command File (cmdfile) Commands ») pour la
   syntaxe exacte de `out open`, `project export`, `project expmul`, `project import`,
   `file open`, `query`, `replace`. Ne pas te fier à ma mémoire : vérifie dans l'aide.
   Si tu trouves le fichier d'aide, extrais la liste complète des commandes dans
   `tools\CMDFILE_REFERENCE.md`.

## Objectif de cette session

1. Faire fonctionner `tools\export.cmd 881` : des `.exp` dans `build\export\881\` et un
   log dans `build\logs\`.
2. Puis `tools\export_all.cmd` sur les 7 cibles, puis `sort_exports.ps1` pour peupler
   `src\common\` et `src\targets\`, et lire `build\export_report.txt`.
3. Puis valider l'aller-retour à vide : `tools\build_all.cmd` doit donner 7 × BUILD OK
   sans avoir rien modifié dans `src\`. Vérifie que le critère de succès dans
   `build.cmd` (`findstr "0 Error(s)"`) correspond bien au texte réel du log — l'IDE
   peut être en français (`0 Erreur(s)`) ou formater autrement.
4. Corrige les scripts au fur et à mesure et documente chaque découverte sur la syntaxe
   cmdfile dans `README.md` (section « Si un script bloque ») pour ne pas la reperdre.
5. Commit à chaque étape franchie, messages en français, préfixe `Wago_4.0:`.

## Règles absolues

- Ne modifie **jamais** `..\Wago_3.0\`, `..\Additionnal\`, ni les `.pro` autrement que
  via les scripts.
- Aucune commande `online login`, `online run`, `online bootproject` ou téléchargement
  vers un automate. Jamais, même pour tester.
- Si CoDeSys reste ouvert avec un dialogue, dis-le-moi plutôt que de le forcer ; je
  peux regarder l'écran de la VM.
- Travaille par petites étapes vérifiables et montre-moi la sortie réelle des commandes
  à chaque hypothèse testée, pas un résumé.

Commence par `tools\diag.cmd 881` et raconte-moi ce que tu observes.