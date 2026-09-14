# Banc — la 753-647 n'importe où, et sans elle

Protocole des essais E2, E3, E4 du §8 de [WAGO_750-647.md](WAGO_750-647.md). Prérequis : T-10, T-11
et T-12 en place, `WAGO_GET_VERSION` répondant `4.1`.

## Avant de commencer

- **Chaque changement de rack provoque un redémarrage automatique** : `Config_File_XML` compare le
  nombre de modules à `wModuleCount` (RETAIN) et fait un `FirmwareReset`. Attendre la fin du reboot
  avant d'interroger.
- Envoyer les commandes UDP sur le port 4646 de l'automate ; écouter les `WAGO INT` sur le port 4646
  de la machine dont l'adresse a été donnée par `WAGO_SET_SERVER_IP` (un `nc -u -l 4646` suffit).
- Ne pas enchaîner une commande de banc pendant une lecture `WAGO_DALI_GET` en vol : le serveur
  jette tout verbe `WAGO_*` inconnu dans cette fenêtre.
- **Jamais** de variable localisée pour instrumenter : elle recréerait la condition mesurée.

## Les racks

Nommage : `DI16` = 16 entrées digitales, `DO16` = 16 sorties, `AI4` = 4 entrées analogiques (4 mots
= 64 bits en entrée), `DO32` = 32 sorties. Adapter les valeurs attendues aux `sizePAE/sizePAA`
réellement lus par `WAGO_GET_INFO_MODULE`.

| Rack | Ordre physique | `start_addr_in` / `out` (bits) | `dali647_in` / `out` (mots) | Ce que ça prouve |
|---|---|---|---|---|
| **R0** | DI16 DI16 DO16 DO16 | 0 / 0 | NA | référence sans 647 ; base de **E4** |
| **R1** | **647** DI16 DI16 DO16 DO16 | 192 / 192 | 0 / 0 | la disposition 3.0 ; base de **E3** |
| **R2** | DI16 DO16 **647** DI16 DO16 | 192 / 192 | 0 / 0 | **l'hypothèse de regroupement** : la 647 est mappée en tête bien qu'au milieu, `scan_error = 0` |
| **R3** | AI4 **647** DI16 DO16 | 256 / 192 | 4 / 0 | entrée et sortie se décalent indépendamment |
| **R4** | DI16 DO16 AI4 | 64 / 0 | NA | le prérequis « analogiques après les digitaux » n'est plus nécessaire |
| **R5** | 647 DO32 DO16 | — / 192 | 0 / 0 | `nb_output_digital = 48` ; la 3.0 disait 16 : l'angle mort mesuré. `SCAN_ERR_DIGITAL_WIDE` (16) **est attendu** ici, c'est le DO32 |

## Pour chaque rack

1. `WAGO_GET_INFO` — noter les sept valeurs. Sur une armoire ordinaire elles doivent être identiques
   à celles de la 3.0.
2. `WAGO_GET_INFO_MODULE n` pour chaque `n` de `0` à `nb_module - 1` — noter `moduleType`,
   `physicalPos`, `sizePAE`, `sizePAA`, `posPAE`, `posPAA`, `channels`, `altFormat`. **C'est la
   première fois que `channels` et `altFormat` sont lus** : consigner leurs valeurs pour une 647, un
   641, un digital, un analogique, un mixte, dans [PROCESS-IMAGE.md](PROCESS-IMAGE.md).
3. `WAGO_GET_LAYOUT` — comparer au tableau.
4. **Sorties** : basculer la sortie 0 et la dernière, en mode serveur puis en dégradé (couper le
   heartbeat 30 s, puis `WAGO_SET_OUTPUT <n> 1`). Le relais attendu claque, **aucun autre**.
   `WAGO_GET_OUTPUT_WORD <start_addr_out / 16>` reflète chaque bascule.
5. **Entrées** : actionner l'entrée 0 et la dernière. `WAGO INT <n> 1` arrive avec le bon `n`.

## E3 — la 647 par `read_word` / `write_word`

Racks R1, puis R2, puis R3.

- `feedback_last = 0` sur **5 minutes** de `WAGO_GET_LAYOUT` toutes les 5 s. Un handshake qui
  décroche se voit dans la durée, pas au premier tour.
- `WAGO_DALI_SET 0 0 <adr> 100 1` allume un ballast ; `WAGO_DALI_GET 0 <adr> 0` rend `1 <niveau>`.
- Un capteur de présence déclaré dans `calaos_dali_master.csv` produit `WAGO INT <6656 + …>`.
- Au démarrage, noter le temps que `rActualLevel` met à quitter 255 (`MASK`) — référence, pas
  critère.

**Échec** : `feedback_last ≠ 0` stable, ou capteurs muets, ou ballasts sourds ⇒ le protocole MBX2 ne
tolère pas la copie par mots. C'est le seul résultat qui invalide la piste. La bibliothèque 641, qui
fait la même chose, le rend improbable ; s'il survient, mesurer si l'ordre lecture → FB → écriture
dans le même cycle suffit, sinon il ne reste que deux builds.

## E4 — le même binaire, sans la borne

Rack R0.

- `WAGO_LAYOUT 0 0 0 NA NA NA`.
- Les sorties 0..15 et la dernière basculent en serveur et en dégradé ; `WAGO_GET_OUTPUT_WORD 0`
  reflète chaque bascule.
- `WAGO_DALI_GET 0 1 0` répond « éteint, niveau 0 » depuis des tableaux jamais alimentés
  ([PROTOCOL-4.0.md](PROTOCOL-4.0.md), « ce qui n'a pas encore de forme d'erreur ») : à relever,
  ce n'est **pas** un critère de E4.

**Succès** = les 16 premières sorties sont utilisables. C'est précisément ce que la 3.0 sans borne ne
sait pas faire. Le fichier-marqueur de la 3.0 peut alors être retiré — dans `Wago_3.0`, en lecture
seule depuis ce dépôt : à faire à la main.

**Échec** ⇒ le conflit n'est pas la déclaration. Retour à E1/E2.

## E2 — si un résultat est ambigu

Rack R0, avec le binaire **3.0** (variables localisées), en dégradé : `WAGO_SET_OUTPUT 0 1`, puis
`WAGO_GET_OUTPUT_WORD 0` dix fois à 1 s.

| lecture | cause | remède |
|---|---|---|
| figée à 0 malgré nos écritures | écrasement au rafraîchissement d'image — la déclaration | T-11 |
| change sans nous | quelqu'un d'autre écrit — la bibliothèque | il ne reste que deux builds |
| `1` stable et relais mort | écrasement au transfert K-Bus, après notre lecture — la déclaration | T-11, et noter **où** dans le cycle |

## Ce qu'un écart implique

- **R2 donne `start_addr_out = 32`** ⇒ le K-Bus mappe dans l'ordre physique, l'hypothèse de
  regroupement tombe. La boucle dégradée de `PLC_PRG` (`FOR i := start_addr_out / 16 TO 255`)
  écrirait par-dessus la 647 : la borner à `(start_addr_out + nb_output_digital - 1) / 16`,
  nouvelle fiche. Le reste tient.
- **`SCAN_ERR_OUT_GAP` sur R2** ⇒ complexe intercalé dans le bloc digital : les scalaires ne
  suffisent plus, c'est le seul résultat qui rouvre la table d'indirection.
- **`SCAN_ERR_DALI647_ALIGN` sur R3** ⇒ l'AI4 n'est pas aligné mot, `AddrDali647In` en mots est
  faux d'un octet. Revenir aux octets et lire par demi-mots — à décider à ce moment-là.
- **`channels = 0` pour la 647** ⇒ le garde `OR moduleType = 647` de T-10 était nécessaire ;
  chercher un autre discriminant (bit 15 de `moduleType` ?) pour le cas général.
