# Wago_4.0

Reprise du programme Calaos pour WAGO 750-xxx (CoDeSys 2.3), avec un workflow
source-texte (`.exp`) + build en ligne de commande, pour travailler avec Git et
Claude Code.

## Mise en route (VM Windows avec WAGO-I/O-PRO)

1. `Wago_4.0\` doit etre au meme niveau que `Wago_3.0\` et `Additionnal\` :
   les `.pro` resolvent leurs bibliotheques via `..\Additionnal\` (relatif).
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

## Si un script bloque
CoDeSys attend un dialogue que `query off` ne couvre pas. Relancer a la main la
commande affichee par le script, ou `tools\open.cmd <c>`.
Causes habituelles : bibliotheque WAGO systeme absente de l'installation, target
non installe, mot de passe projet.

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
