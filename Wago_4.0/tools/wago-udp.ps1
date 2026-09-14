<#
 wago-udp.ps1 - envoie une commande du protocole Calaos a un automate et affiche la reponse.

 Usage :
   .\wago-udp.ps1 -Ip 193.168.30.124 -Command 'WAGO_GET_INFO'
   .\wago-udp.ps1 -Ip 193.168.30.124 -Command 'WAGO_GET_INFO_MODULE 0'
   .\wago-udp.ps1 -Ip 193.168.30.124 -Command 'WAGO_SET_OUTPUT 0 1' -AllowWrite

 Sans -AllowWrite, seuls les verbes de lecture sont envoyes. Les verbes de 4.0
 (WAGO_GET_LAYOUT, WAGO_GET_OUTPUT_WORD) restent sans reponse sur un 3.0.
#>
param(
  [Parameter(Mandatory)][string]$Ip,
  [Parameter(Mandatory)][string]$Command,
  [int]$TimeoutMs = 2000,
  [switch]$AllowWrite
)
. "$PSScriptRoot\WagoNet.ps1"

$reply = Invoke-WagoUdp -Ip $Ip -Command $Command -TimeoutMs $TimeoutMs -AllowWrite:$AllowWrite
if ($null -eq $reply) {
  Write-Host ("{0} > {1}`n  (pas de reponse en {2} ms)" -f $Ip, $Command, $TimeoutMs)
  exit 1
}
Write-Host ("{0} > {1}`n  {2}" -f $Ip, $Command, $reply)
