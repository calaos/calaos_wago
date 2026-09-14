<#
 wago-diag.ps1 - etat complet d'un automate en lecture seule : identite et rack par
 Modbus, puis ce que le programme Calaos en dit par UDP. Marche sur un 3.0 (les
 verbes de 4.0 sont simplement absents du rapport) comme sur un 4.0.

 Usage :
   .\wago-diag.ps1 -Ip 193.168.30.124
   .\wago-diag.ps1 -Ip 193.168.30.124 -OutFile rapport-124.txt
#>
param(
  [Parameter(Mandatory)][string]$Ip,
  [string]$OutFile,
  [int]$TimeoutMs = 2000
)
. "$PSScriptRoot\WagoNet.ps1"

$lines = New-Object System.Collections.Generic.List[string]
function Out([string]$s) { $lines.Add($s); Write-Host $s }
function Udp([string]$cmd) { Invoke-WagoUdp -Ip $Ip -Command $cmd -TimeoutMs $TimeoutMs }

Out ("=== {0}  {1} ===" -f $Ip, (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))

# --- Modbus : ce que l'automate est, sans le programme -----------------------
Out ""
Out "--- Modbus ---"
try {
  $id = Get-WagoIdentity -Ip $Ip
  Out ("automate      : {0}-{1}, firmware {2}.{3}" -f $id.Series, $id.Item, $id.FwMajor, $id.FwMinor)
  $mods = Get-WagoModules -Ip $Ip
  Out ("rack          : {0} module(s)" -f $mods.Count)
  foreach ($m in $mods) {
    if ($m.Kind -eq 'digital') { Out ("  slot {0,2}  {1}  digital  {2,-5} {3,2} voies" -f $m.Slot, $m.Raw, $m.Type, $m.Channels) }
    else                       { Out ("  slot {0,2}  {1}  complexe {2}" -f $m.Slot, $m.Raw, $m.Type) }
  }
  $bits = Read-WagoCoils -Ip $Ip -Address 4096 -Count 256 -TimeoutMs $TimeoutMs
  $on = @(); for ($i = 0; $i -lt 256; $i++) { if ($bits[$i]) { $on += $i } }
  Out ("netOutStandard: sorties serveur a 1 : {0}" -f $(if ($on.Count) { $on -join ' ' } else { 'aucune' }))
} catch { Out ("Modbus KO : {0}" -f $_.Exception.Message) }

# --- UDP : ce que le programme en dit -----------------------------------------
Out ""
Out "--- UDP 4646 ---"
$ver = Udp 'WAGO_GET_VERSION'
if ($null -eq $ver) { Out "WAGO_GET_VERSION : pas de reponse - programme arrete, IP fausse, ou port 4646 local occupe"; if ($OutFile) { $lines | Set-Content $OutFile -Encoding UTF8 }; exit 1 }
Out ("version       : {0}" -f $ver)
$vt = $ver -split ' '
$is40 = ($vt.Count -ge 2 -and ([int]($vt[1] -split '\.')[0]) -ge 4)

$info = Udp 'WAGO_GET_INFO'
Out ("WAGO_INFO     : {0}" -f $info)
$nbModule = 0
if ($info) {
  $t = $info -split ' '
  if ($t.Count -ge 8) {
    Out ("  nb_module={0} in={1} out={2} input_digital={3} output_digital={4} analog_in={5} analog_out={6}" -f $t[1],$t[2],$t[3],$t[4],$t[5],$t[6],$t[7])
    $nbModule = [int]$t[1]
  }
}

if ($is40) {
  $lay = Udp 'WAGO_GET_LAYOUT'
  Out ("WAGO_LAYOUT   : {0}" -f $lay)
  if ($lay) {
    $t = $lay -split ' '
    if ($t.Count -ge 7) {
      $se = [int]$t[3]
      $flags = @()
      if ($se -band 1)  { $flags += 'IN_GAP' }
      if ($se -band 2)  { $flags += 'OUT_GAP' }
      if ($se -band 4)  { $flags += 'OUT_ALIGN' }
      if ($se -band 8)  { $flags += 'DALI647_ALIGN' }
      if ($se -band 16) { $flags += 'DIGITAL_WIDE' }
      if ($se -band 32) { $flags += 'DALI647_ABOVE' }
      Out ("  start_addr_in={0} bits  start_addr_out={1} bits (mot {2})  scan_error={3} {4}" -f $t[1], $t[2], ([int]$t[2] / 16), $se, $(if ($flags.Count) { '[' + ($flags -join ' ') + ']' } else { '' }))
      Out ("  dali647_in={0}  dali647_out={1} (mots)  feedback_last={2}" -f $t[4], $t[5], $t[6])
    }
  }
}

for ($n = 0; $n -lt $nbModule; $n++) {
  $m = Udp ("WAGO_GET_INFO_MODULE {0}" -f $n)
  if ($null -eq $m) { Out ("WAGO_MODULE {0} : pas de reponse" -f $n); continue }
  $t = $m -split ' '
  if ($t.Count -ge 10) {
    Out ("WAGO_MODULE {0,2} : type={1,-6} pos={2,-3} sizePAE={3,-4} sizePAA={4,-4} posPAE={5,-5} posPAA={6,-5} channels={7,-3} altFormat={8}" -f $t[1],$t[2],$t[3],$t[4],$t[5],$t[6],$t[7],$t[8],$t[9])
  } elseif ($t.Count -ge 6) {
    Out ("WAGO_MODULE {0,2} : type={1,-6} pos={2,-3} sizePAE={3,-4} sizePAA={4}" -f $t[1],$t[2],$t[3],$t[4],$t[5])
  } else { Out ("WAGO_MODULE {0} : {1}" -f $n, $m) }
}

if ($OutFile) { $lines | Set-Content $OutFile -Encoding UTF8; Write-Host "`nrapport : $OutFile" }
