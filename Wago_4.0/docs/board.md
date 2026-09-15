# Board — suivi des tickets Wago_4.0

Dernière mise à jour : 2026-09-14

## Convention

- Une fiche ouverte vit dans **`docs/todo/`**, une fiche close dans **`docs/done/`**.
  On la **déplace** (`git mv`), on ne la duplique pas : l'historique du fichier suit.
- La ligne de statut, en tête de fiche, est la source de vérité :

  ```
  **Statut** : 📋 · **Type** : fix
  **Statut** : ✅ clos le AAAA-MM-JJ · **Type** : fix · **Commits** : `sha`, `sha`
  ```

- Un ticket n'est clos que si **les trois** conditions sont réunies :
  1. `tools\build_all.cmd` donne **7 × `BUILD OK`** ;
  2. l'aller-retour est vérifié sur au moins une cible — les objets ré-exportés sont
     identiques octet pour octet à `src\` ;
  3. l'agent **`codesys-review`** (`.claude/agents/codesys-review.md`) rend
     `CONFORME` ou `CONFORME AVEC RESERVES`, les réserves étant tracées.
- Une clôture partielle se dit **dans la ligne de statut**, par un encart `⚠️` juste en dessous,
  avec le renvoi vers la fiche qui porte le reste. Un ticket à moitié fait ne va pas dans `done/`
  sans cet encart.
- Chaque correctif fait **un commit séparé**, préfixé `Wago_4.0:`, qui nomme le ticket.

## Tickets

| # | Sujet | Statut | Commits |
|---|---|---|---|
| [T-1](done/T-1.md) | `WAGO_GET_VERSION` annonçait `750-849` sur les 7 cibles | ✅ clos *(partiel)* | `40a9d25` |
| [T-2](done/T-2.md) | Le miroir serveur → dégradé écrivait à côté et éteignait les sorties | ✅ clos *(partiel)* | `6725cac` |
| [T-3](done/T-3.md) | La relecture DMX lisait son adresse dans le mauvais paramètre | ✅ clos | `684e347`, `c9cf37d`, `08ef59a` |
| [T-4](done/T-4.md) | 16 sorties Modbus (coils 4336..4351) ne sont jamais relues | ✅ clos *(partiel)* | `c081aa7` |
| [T-5](done/T-5.md) | `lights[]` trop court d'un octet pour la règle 512 | ✅ clos | `0fa011c` |
| [T-6](done/T-6.md) | Le drapeau groupe est ignoré sur un des deux chemins de relecture DALI | ✅ clos *(partiel)* | `25e8b9f` |
| [T-7](done/T-7.md) | Après une bascule, le premier appui relance un volet au lieu de l'arrêter | ✅ clos | `a857e72` |
| [T-8](done/T-8.md) | Une lecture DALI en attente peut être détournée ou privée de réponse | ✅ clos *(partiel)* | `0bb27c9` |
| [T-9](done/T-9.md) | La réponse d'erreur de T-6 est lue comme « allumée » par `calaos_server` | ✅ clos *(partiel)* | `7febc40`, `100455d` |
| [T-10](done/T-10.md) | Le balayage de modules ne classe pas tout et recalcule l'offset de la 647 à la main | ✅ clos *(partiel)* | `cef4d2c` |
| [T-11](done/T-11.md) | La 753-647 est clouée en tête du rack et condamne 24 octets sans elle | ✅ clos *(partiel)* | `2c743d1` |
| [T-12](done/T-12.md) | Rien ne permet d'observer le rack, les offsets ni la 647 de l'extérieur | ✅ clos *(partiel)* | `6461362` |
| [T-13](done/T-13.md) | En 4.0 avec une 647, les sorties digitales ne sont plus pilotées (régression T-11) | ✅ clos | `86b2363` |
| [T-14](todo/T-14.md) | Rien ne permet d'observer l'image interne pour automatiser le débug | 📋 ouvert *(livré, réserves)* | `81272a3`, `2fb79d5` |

## Clôtures partielles — ce qui reste

- **T-1** : le second volet du §3 (libeller « modèle annoncé » côté outil) concerne
  `calaos_server`, hors de ce dépôt.
- **T-2** : l'ensemencement ne couvre que `TELERUPTEUR`. Les volets sont hors de portée sans
  modifier l'interface du FB `VOLET` → **T-7**. Le §5.3 de la fiche était faux, il a été amendé
  sur place.
- **T-8** : défaut 1 corrigé, **défaut 2 non traité** — `DaliSend` reste un jeton unique. Ce n'est
  pas un report de confort : le POU n'a qu'un emplacement de réponse, et les trames ne portent ni
  adresse ni numéro, donc aucune file ni aucun refus n'est décidable côté automate seul. Voir le
  §6 bis de la fiche.
- **T-6** : repli du §4.1. La forme `-1 -1` livrée par ce ticket était **fausse** — `calaos_server`
  la lisait comme « allumé » — et a été remplacée par `ERR <raison>` dans **T-9**. Le §4.2 est
  inatteignable et était déjà faux (arité différente entre les deux chemins) ; le §5 reste non
  instruit.
- **T-9** : moitié automate faite. `calaos_server` doit apprendre `WAGO_DALI_GET ERR <raison>`,
  sinon rien ne change pour l'utilisateur. Contrat dans [PROTOCOL-4.0.md](PROTOCOL-4.0.md).
  Son critère ⭐ n'est pas atteint non plus : deux réponses encodent encore « je ne sais pas » dans
  le domaine des valeurs (adresse hors plage DMX, armoire sans module DALI).
- **T-10, T-11, T-12** : le code a **enfin tourné sur un rack** (750-889 + 647, 2026-09-14). Le
  balayage T-10 est juste (`scan_error=0`, `start_addr_out=192`, `AddrDali647Out=0`) et la 647 vit
  (`feedback_last` non nul). Les verbes T-12 remontent tout. **Mais** les sorties digitales ne sont
  plus pilotées — régression du chemin d'écriture ouverte en **T-13**. `channels` d'une 647 = 1 (et
  non 0, l'inconnue fermée par le `OR moduleType=647` était donc superflue mais inoffensive). Reste
  la vérification côté `calaos_base` : `WAGO_MODULE` est-il parsé par nombre de champs ? Sinon, repli
  `WAGO_GET_MODULE_DESC`.
- **T-13** : clos le 2026-09-15, **validé au banc** sur le 750-889 avec sa 647 — la sortie 27 est
  pilotée dans les deux branches, chaîne complète des cinq maillons. Reste non tranché, sans effet sur
  la fiabilité : `86b2363` applique deux changements à la fois (réordonnancement et instance dédiée),
  on ne sait pas lequel porte le correctif. Voir le §8 de la fiche.
- **T-14** : livré et validé au banc (`81272a3`, `2fb79d5`), mais **pas clos** : la relecture a laissé
  trois réserves mineures non traitées — `err_dali` répond `0` au lieu de `NA` quand il n'y a pas de
  647 ; `WAGO_GET_OUTSTATE_WORD` suppose `start_addr_out` aligné sur 16 (déjà signalé par
  `SCAN_ERR_OUT_ALIGN`) ; les gardes `wa <= 255` n'ont pas de borne basse. Aucune ne gêne l'usage.
  La réserve la plus sérieuse — `err_dig` structurellement à 1 en mode dégradé — a été **levée par la
  mesure** : `WRITE_OUTPUT_WORD` ne lève pas `ERROR` au-delà du rack peuplé.
- **T-4** : la question « le serveur écrit-il au-delà de la coil 4335 ? » reste ouverte, faute de
  `calaos_base`. Le correctif est juste dans les deux cas ; la réponse décide de son intérêt, pas
  de sa justesse. Effet de bord assumé : une sortie au-delà de la 240e suit désormais le serveur
  en mode serveur, au lieu de conserver sa dernière valeur dégradée.

## En production

Depuis le 2026-09-15, le **750-889 de la maison tourne la 4.0** (et non plus la 3.0), avec le
correctif T-13 et l'instrumentation T-14. Les **sorties digitales** sont validées de bout en bout
depuis `calaos_server`. Le **DALI ne l'est pas** : la 647 vit, mais aucun ballast n'a été commandé, et
deux changements de contrat 4.0 attendent encore côté serveur — la forme `WAGO_DALI_GET ERR <raison>`
(T-9) et `WAGO_MODULE` à 10 champs (T-12). C'est le premier endroit où regarder si une lumière DALI se
comporte mal.

## Ce qui bloque, et où est la réponse

Ces questions ne peuvent pas être tranchées depuis `calaos_wago` :

- **T-4** — `calaos_server` écrit-il réellement au-delà de la coil 4335 ? Si non, le défaut est
  latent. Réponse dans `calaos_base` (`Constants.h`, `WODigital.cpp`, `WagoCtrl.cpp`).
- **T-6** — `arActualValue[bShortAddress - 1]` suppose des adresses 1-basées ; la bibliothèque
  DALI est livrée compressée, son source n'est pas lisible.
- **T-8** — le protocole Calaos n'est pas documenté ici : on ignore si le serveur tolère une
  absence de réponse, ou s'il numérote ses requêtes.
- **T-3**, assumé et non vérifié : le canal DMX 1 est l'adresse 101, déduit du tableau
  `abDMX_Values: ARRAY [1..255]` et de `FirstChannel := 1`.

## Renvois morts

`T-2.md` et `T-3.md` citent `T3.156.md`, `T3.161.md` et `FINDINGS.md`, qui **n'ont jamais existé
dans ce dépôt** — ils viennent de la rédaction d'origine des fiches. Les liens sont laissés tels
quels pour ne pas réécrire l'historique des fiches, mais ils ne mènent nulle part ici.

`T3.161` désignait un défaut réel et non tracé : le miroir **retour** (dégradé → serveur) a disparu
en 1.8, si bien qu'une lumière basculée à la main pendant une coupure serveur est écrasée par
l'image serveur périmée au retour du serveur. À reprendre dans une fiche si le sujet revient.
