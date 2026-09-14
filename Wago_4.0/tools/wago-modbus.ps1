<#
 wago-modbus.ps1 - lit l'automate en Modbus TCP, independamment du programme.

 Presets (lecture seule) :
   -Preset Identity   serie, reference, firmware              (registres 0x2011..0x2014)
   -Preset Modules    les modules du rack, decodes            (registres 0x2030..0x2032)
   -Preset NetOut     ce que calaos_server a ecrit, 256 coils (coils 4096..4351 = netOutStandard)
   -Preset OutWords   image de sortie physique, N mots        (registres 0x0200.., %QW0..)
   -Preset InWords    image d'entree physique, N mots         (registres 0x0000.., %IW0..)

 Brut :
   -Function 3 -Address 8241 -Count 64        (FC1..FC4)
   -WriteCoil 4096 -Value 1 -AllowWrite       (FC5, automate de test seulement)

 Usage :
   .\wago-modbus.ps1 -Ip 193.168.30.124 -Preset Modules
   .\wago-modbus.ps1 -Ip 193.168.30.124 -Preset OutWords -Count 32
#>
param(
  [Parameter(Mandatory)][string]$Ip,
  [ValidateSet('Identity','Modules','NetOut','OutWords','InWords')][string]$Preset,
  [ValidateSet(1,2,3,4)][int]$Function,
  [int]$Address,
  [int]$Count = 16,
  [int]$WriteCoil = -1,
  [int]$Value,
  [switch]$AllowWrite,
  [int]$TimeoutMs = 2000
)
. "$PSScriptRoot\WagoNet.ps1"

function Show-Words([int[]]$w, [int]$base) {
  for ($i = 0; $i -lt $w.Count; $i++) {
    $bits = [Convert]::ToString($w[$i], 2).PadLeft(16, '0')
    "  mot {0,4}  0x{1:X4}  {2,5}  {3}" -f ($base + $i), $w[$i], $w[$i], ($bits -replace '(.{8})(.{8})', '$1 $2')
  }
}

if ($WriteCoil -ge 0) {
  if (-not $AllowWrite) { throw "Ecriture refusee sans -AllowWrite" }
  Write-WagoCoil -Ip $Ip -Address $WriteCoil -Value ($Value -ne 0) -TimeoutMs $TimeoutMs
  "coil $WriteCoil <- $Value  ($Ip)"
  exit 0
}

switch ($Preset) {
  'Identity' {
    $id = Get-WagoIdentity -Ip $Ip
    "{0} : {1}-{2}, firmware {3}.{4}" -f $Ip, $id.Series, $id.Item, $id.FwMajor, $id.FwMinor
  }
  'Modules' {
    $mods = Get-WagoModules -Ip $Ip
    "{0} : {1} module(s)" -f $Ip, $mods.Count
    foreach ($m in $mods) {
      if ($m.Kind -eq 'digital') { "  slot {0,2}  {1}  digital  {2,-5} {3,2} voies" -f $m.Slot, $m.Raw, $m.Type, $m.Channels }
      else                       { "  slot {0,2}  {1}  complexe {2}" -f $m.Slot, $m.Raw, $m.Type }
    }
  }
  'NetOut' {
    $bits = Read-WagoCoils -Ip $Ip -Address 4096 -Count 256 -TimeoutMs $TimeoutMs
    $on = @(); for ($i = 0; $i -lt 256; $i++) { if ($bits[$i]) { $on += $i } }
    "{0} : netOutStandard (coils 4096..4351) - sorties serveur a 1 : {1}" -f $Ip, $(if ($on.Count) { $on -join ' ' } else { 'aucune' })
  }
  'OutWords' {
    $w = Read-WagoRegisters -Ip $Ip -Address 0x0200 -Count $Count -Function 3 -TimeoutMs $TimeoutMs
    "{0} : image de sortie physique, %QW0..{1}" -f $Ip, ($Count - 1)
    Show-Words $w 0
  }
  'InWords' {
    $w = Read-WagoRegisters -Ip $Ip -Address 0x0000 -Count $Count -Function 3 -TimeoutMs $TimeoutMs
    "{0} : image d'entree physique, %IW0..{1}" -f $Ip, ($Count - 1)
    Show-Words $w 0
  }
  default {
    if (-not $Function) { throw "Donner -Preset, ou -Function avec -Address" }
    if ($Function -le 2) {
      $bits = Read-WagoCoils -Ip $Ip -Address $Address -Count $Count -Function $Function -TimeoutMs $TimeoutMs
      "{0} : FC{1} @ {2}, {3} bit(s)" -f $Ip, $Function, $Address, $Count
      $on = @(); for ($i = 0; $i -lt $Count; $i++) { if ($bits[$i]) { $on += ($Address + $i) } }
      "  a 1 : " + $(if ($on.Count) { $on -join ' ' } else { 'aucun' })
    } else {
      $w = Read-WagoRegisters -Ip $Ip -Address $Address -Count $Count -Function $Function -TimeoutMs $TimeoutMs
      "{0} : FC{1} @ {2}, {3} mot(s)" -f $Ip, $Function, $Address, $Count
      Show-Words $w $Address
    }
  }
}
