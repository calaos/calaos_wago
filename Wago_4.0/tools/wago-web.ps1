<#
 wago-web.ps1 - affiche en texte une page du Web-Based Management de l'automate
 (compte par defaut admin/wago). Lecture seule : aucun formulaire n'est soumis.

 Pages : state (defaut), tcpip, port, snmp, watchdog, clock, security, ethernet,
         plccfg, addcnf, ea-config (l'XML brut de la configuration d'E/S).

 Usage :
   .\wago-web.ps1 -Ip 192.168.30.124
   .\wago-web.ps1 -Ip 192.168.30.124 -Page plccfg
   .\wago-web.ps1 -Ip 192.168.30.124 -Page state -Raw      HTML tel quel
#>
param(
  [Parameter(Mandatory)][string]$Ip,
  [ValidateSet('state','tcpip','port','snmp','watchdog','clock','security','ethernet','plccfg','addcnf','ea-config')]
  [string]$Page = 'state',
  [switch]$Raw,
  [string]$User = 'admin',
  [string]$Password = 'wago',
  [int]$TimeoutSec = 5
)

$auth = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${User}:${Password}"))
$path = if ($Page -eq 'ea-config') { '/etc/ea-config.xml' } else { "/webserv/cplcfg/$Page.ssi" }
$r = Invoke-WebRequest -Uri "http://$Ip$path" -Headers @{ Authorization = $auth } -UseBasicParsing -TimeoutSec $TimeoutSec

if ($Raw -or $Page -eq 'ea-config') { $r.Content; exit 0 }

# Les pages sont des tableaux HTML : un retour par ligne de tableau, les balises
# restantes ecrasees en espaces.
$t = $r.Content -replace '<script[\s\S]*?</script>', ''
$t = $t -replace '</tr>', "`n" -replace '<br\s*/?>', "`n" -replace '</h\d>', "`n" -replace '</p>', "`n"
$t = $t -replace '<[^>]+>', ' ' -replace '&nbsp;?', ' '
$t = [System.Net.WebUtility]::HtmlDecode($t)
"--- $Ip $path ---"
($t -split "`n" | ForEach-Object { ($_ -replace '\s+', ' ').Trim() } | Where-Object { $_ }) -join "`n"
