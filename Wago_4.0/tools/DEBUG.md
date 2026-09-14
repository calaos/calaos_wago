# Outils de diagnostic en ligne (PowerShell)

Scripts pour interroger un automate **en marche** depuis le poste, sans CoDeSys et
sans rien telecharger. Ils n'utilisent que ce que l'automate publie : le protocole
Calaos en UDP (port 4646), Modbus TCP (port 502), FTP et le Web-Based Management
(compte par defaut `admin` / `wago`).

Tout est en lecture seule par defaut. Les deux seules ecritures possibles
(`wago-udp.ps1` avec un verbe `WAGO_SET_*` / `WAGO_DALI_SET` / `WAGO_HEARTBEAT`,
`wago-modbus.ps1 -WriteCoil`) exigent `-AllowWrite`, et ne sont a utiliser que sur
un automate de test. `wago-ftp.ps1` ne sait ni envoyer ni supprimer.

| Script | Sert a |
|---|---|
| `wago-diag.ps1 -Ip <ip>` | le rapport complet en une commande : identite et rack par Modbus, puis version, `WAGO_INFO`, `WAGO_LAYOUT` (4.0), `WAGO_MODULE n` pour chaque module. `-OutFile` pour l'archiver. |
| `wago-udp.ps1 -Ip <ip> -Command '<verbe>'` | une commande du protocole Calaos, sa reponse, ou « pas de reponse » apres 2 s. |
| `wago-modbus.ps1 -Ip <ip> -Preset <Identity\|Modules\|NetOut\|OutWords\|InWords>` | ce que l'automate est et ce qu'il a dans son image, independamment du programme. `-Function 1..4 -Address -Count` pour du brut. |
| `wago-ftp.ps1 -Ip <ip> [-Path /PLC] [-Get <fichier> -To <dir> [-Compare <fichier local>]]` | lister la flash, rapatrier `DEFAULT.PRG` / `.CHK` et les comparer au boot project du depot. |
| `wago-web.ps1 -Ip <ip> [-Page state\|plccfg\|...]` | la page d'etat du Web-Based Management en texte (firmware, hostname, code d'erreur, options PLC). |
| `WagoNet.ps1` | les fonctions communes (`Invoke-WagoUdp`, `Invoke-WagoModbus`, `Read-WagoRegisters`, `Read-WagoCoils`, `Get-WagoIdentity`, `Get-WagoModules`). A charger par `. .\WagoNet.ps1` pour un usage interactif. |

## Ce que Modbus donne que le programme ne donne pas

- **`-Preset Modules`** : le rack tel que le firmware le voit (registres `0x2030..`),
  meme si le programme est arrete. Un digital se lit `0x9002` = 16 voies, sortie ;
  un complexe donne sa reference (`0x0287` = 750-647).
- **`-Preset NetOut`** : `netOutStandard`, c'est-a-dire les 256 coils `4096..` que
  calaos_server ecrit. Si une sortie est a 1 ici mais pas dans `-Preset OutWords`,
  le probleme est dans le programme, pas dans le serveur ; si elle n'y est pas, le
  serveur n'a rien ecrit.
- **`-Preset OutWords` / `InWords`** : l'image physique (`%QW0..` / `%IW0..`) - la
  seule facon de voir les mots de la boite aux lettres 647 sans variable localisee.
- Registres `0x1022..0x1025` : nombre de bits analogiques out / in, digitaux out / in.

L'image est **groupee** : les modules complexes (647, 464...) sont en tete de
l'image quel que soit leur emplacement physique, les digitaux suivent. Mesure sur
l'automate de la maison (750-889, 647 en position 8 derriere les digitaux, mappee
aux mots 0..11, digitaux a partir du bit 192). C'est l'hypothese sur laquelle repose
`docs/PROCESS-IMAGE.md`.

## Pieges

- Le PC est sur `192.168.30.x` ; les automates repondent en `192.168.30.123`
  (maison, 3.0, **ne rien y ecrire**) et `192.168.30.124` (test, 4.0).
- Le port UDP local 4646 doit etre libre : si calaos_server tourne sur le poste, le
  script bascule sur un port ephemere et l'automate repond quand meme a l'emetteur.
- Sur un 3.0, `WAGO_GET_LAYOUT` et `WAGO_GET_OUTPUT_WORD` n'existent pas : pas de
  reponse. `WAGO_MODULE` y a 6 champs, 10 en 4.0 ; `wago-diag.ps1` accepte les deux.
- `WAGO_GET_INFO_MODULE n` avec `n >= nb_module` repond `0` partout : ce n'est pas
  une erreur, le tableau est simplement vide au-dela.
- Les registres `0x2011..0x2014` refusent une lecture groupee : un par requete.
- FTP : `wago-ftp.ps1` parle directement au port 21 plutot que par `FtpWebRequest`,
  dont le canal de commande mis en cache se desynchronise avec le serveur du 750
  (« 150 » recu la ou un 2xx est attendu) des la deuxieme requete du processus.
- La 647 declare `sizePAE = sizePAA = 152` bits au programme alors qu'elle occupe
  192 bits (24 octets) dans l'image : ne pas deduire une position d'une somme de
  tailles, seul `posPAE` / `posPAA` fait foi.
