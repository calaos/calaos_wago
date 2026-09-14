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
- **T-4** : la question « le serveur écrit-il au-delà de la coil 4335 ? » reste ouverte, faute de
  `calaos_base`. Le correctif est juste dans les deux cas ; la réponse décide de son intérêt, pas
  de sa justesse. Effet de bord assumé : une sortie au-delà de la 240e suit désormais le serveur
  en mode serveur, au lieu de conserver sa dernière valeur dégradée.

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
