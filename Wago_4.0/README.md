# Wago_4.0

Reprise du programme Calaos pour WAGO 750-xxx (CoDeSys 2.3), avec un workflow
source-texte (`.exp`) + build en ligne de commande, pour travailler avec Git et
Claude Code.

## Mise en route (VM Windows avec WAGO-I/O-PRO)

1. `Wago_4.0\` doit etre au meme niveau que `Wago_3.0\` et `Additionnal\` :
   les `.pro` vivent dans `Wago_4.0\pro\` et resolvent leurs bibliotheques via
   le chemin relatif `..\..\Additionnal`.
2. Adapter `tools\config.cmd` si Codesys.exe n'est pas au chemin par defaut.
3. `tools\check_env.cmd` doit afficher `ENV OK`.
4. `tools\bootstrap.cmd` : copie les `.pro` de `Wago_3.0`, exporte les 7 cibles,
   classe les `.exp` dans `src\common` et `src\targets\<cible>`.
5. `git add . && git commit -m "Wago_4.0: bootstrap depuis 3.0"`
6. `tools\build_all.cmd` sans rien modifier : 7 x `BUILD OK` attendus.
7. Ouvrir Claude Code dans `Wago_4.0\`.

## Scripts

| Script | Role |
|---|---|
| `tools\check_env.cmd` | verifie exe, .pro de reference, `..\Additionnal`, targets |
| `tools\bootstrap.cmd` | initialisation unique 3.0 -> 4.0 |
| `tools\export.cmd <c>` | `.pro` -> `build\export\<c>\*.exp` (un par objet) |
| `tools\export_all.cmd` | idem pour toutes les cibles |
| `tools\sort_exports.ps1` | classe les exports en common / targets, ecrit `build\export_report.txt` |
| `tools\build.cmd <c>` | `.exp` -> import dans `.pro` -> rebuild -> `build\logs\build_<c>.log` |
| `tools\build_all.cmd` | toutes les cibles (`--keep-going` pour ne pas s'arreter) |
| `tools\open.cmd <c>` | ouvre le `.pro` dans l'IDE pour debloquer / verifier |
| `tools\diag.cmd <c>` | export minimal instrumente : affiche le `.cds`, la commande et le log |

## Ce qui a ete valide
- `tools\export_all.cmd` : 7/7 `EXPORT OK` (87 objets, 88 pour la 849).
- `tools\build_all.cmd` : 7/7 `BUILD OK`, `0 Error(s), 0 Warning(s).`
- Aller-retour `.exp` -> `.pro` -> `.exp` **idempotent** : apres un build_all
  puis un export_all, les 610 objets re-exportes sont identiques octet pour
  octet a `src\`.

Deux effets a connaitre :
- **Le premier import normalise le source.** CoDeSys supprime les lignes vides
  en fin de corps de POU et renomme les entrees du Library Manager
  (`<lib>.LIB_<date>` -> `<lib>.LIB <date>`). C'est fait une fois pour toutes,
  c'est deja integre dans `src\`, et les cycles suivants sont stables.
- **Le `.pro` n'est pas reproductible octet pour octet.** Il embarque les
  informations de compilation : il apparait donc modifie par git apres chaque
  build, meme a source identique. C'est normal ; ce qui fait foi, c'est que le
  re-export redonne exactement `src\`.

## Si un script bloque
CoDeSys attend un dialogue que `query off` ne couvre pas. Relancer a la main la
commande affichee par le script, ou `tools\open.cmd <c>`.
Causes habituelles : bibliotheque WAGO systeme absente de l'installation, target
non installe, mot de passe projet.

**Bibliotheques introuvables** : verifier le repertoire de bibliotheques du
projet (options du projet, categorie Repertoires). Les `.pro` etant dans
`pro\`, il doit valoir `..\..\Additionnal`. Un `.pro` recopie depuis `Wago_3.0`
porte `..\Additionnal`, qui etait correct quand les `.pro` etaient a la racine
mais ne l'est plus.

`tools\diag.cmd <c>` refait un export minimal en affichant le `.cds` genere, la
ligne de commande exacte et le log obtenu : c'est le point de depart de tout
diagnostic.

## Syntaxe cmdfile CoDeSys 2.3 — ce qui a ete verifie sur cette installation

Reference complete des commandes : `tools\CMDFILE_REFERENCE.md`.

### `/batch` est inutilisable — ne pas l'ajouter
C'est **la** cause du blocage initial (aucun `.exp`, aucun log). Teste sur
`wago_881.pro` avec cette build WAGO-I/O-PRO :

| guillemets dans le `.cds` | `/batch` | log produit | objets exportes |
|---|---|---|---|
| oui | oui | non | 0 |
| non | oui | non | 0 |
| oui | **non** | oui | **87** |

Avec `/batch`, CoDeSys rend la main immediatement, code de sortie
`-2147204861`, sans meme executer le `out open` — donc sans laisser la moindre
trace. Idem avec le projet passe en premier argument
(`Codesys.exe wago_881.pro /batch /cmd ...`). La forme qui marche est :

```
Codesys.exe /cmd <fichier.cds>
```

La fenetre CoDeSys s'affiche pendant l'operation : c'est normal et sans
consequence, `query off` repond seul aux dialogues (dont
« The version of at least one library has changed since the project was last
opened! », qui apparait a chaque ouverture des `.pro`). Les scripts utilisent
`start "" /wait` pour attendre reellement la fin du processus.

### `query off` : garder la forme nue, ne pas la "corriger"
L'aide ne documente que `query off ok|no|cancel`. La forme nue `query off`
utilisee par les scripts fonctionne et prend le **bouton par defaut de chaque
dialogue**, ce qui n'est pas equivalent : sur
« Taskconfig import: Do you want to overwrite the system events? »,
`query off` repond `No` (les evenements systeme du `.pro` sont preserves) la ou
`query off ok` repond `Yes` (ils sont ecrases a chaque build). C'est avec
`query off` que l'aller-retour a ete verifie idempotent.

### Les guillemets ne posent pas de probleme
Les chemins absolus entre guillemets dans le `.cds` sont acceptes, y compris
avec des espaces. Le `.cds` genere par `echo` (ANSI + CRLF) est lu correctement.

### `project expmul` fonctionne
Pas besoin du repli monofichier + decoupage : `expmul <dossier>` ecrit bien un
fichier par objet. **Attention, les noms sont ecrits en MAJUSCULES** (`PLC_PRG.EXP`,
`ALARM CONFIGURATION.EXP`, et certains contiennent des espaces et des points).
Consequence pour les scripts `.cmd` : `find /c ".exp"` renvoie **0** car `find`
est sensible a la casse — il faut `find /c /i ".exp"`. C'etait le second bug :
l'export reussissait deja mais `export.cmd` le declarait en echec.
