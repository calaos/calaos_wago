# WagoNet.ps1 - fonctions partagees par wago-udp.ps1, wago-modbus.ps1, wago-diag.ps1.
# A charger par dot-sourcing : . "$PSScriptRoot\WagoNet.ps1"
# Tout est en lecture seule sauf ce qui exige -AllowWrite.

# --- UDP : le protocole du programme Calaos, port 4646 -------------------------

# Verbes qui ne modifient rien dans l'automate. Tout autre verbe exige -AllowWrite.
$script:WagoReadVerbs = @(
  'WAGO_GET_VERSION', 'WAGO_GET_INFO', 'WAGO_GET_INFO_MODULE', 'WAGO_GET_LAYOUT',
  'WAGO_GET_OUTPUT_WORD', 'WAGO_GET_OUTTYPE', 'WAGO_GET_OUTADDR', 'WAGO_INFO_VOLET_GET',
  'WAGO_DALI_GET'
)

function Test-WagoReadVerb([string]$Command) {
  $verb = ($Command -split ' ')[0]
  return ($script:WagoReadVerbs -contains $verb)
}

function Invoke-WagoUdp {
  # Envoie une commande et rend la premiere reponse, ou $null sur delai depasse.
  # Le port local est 4646 comme calaos_server : le programme repond a l'emetteur,
  # et un automate 3.0 comme 4.0 accepte la trame terminee par un octet nul.
  param(
    [Parameter(Mandatory)][string]$Ip,
    [Parameter(Mandatory)][string]$Command,
    [int]$Port = 4646,
    [int]$TimeoutMs = 2000,
    [switch]$AllowWrite
  )
  if (-not (Test-WagoReadVerb $Command) -and -not $AllowWrite) {
    throw "Commande d'ecriture refusee sans -AllowWrite : $Command"
  }
  $udp = $null
  try { $udp = New-Object System.Net.Sockets.UdpClient($Port) }
  catch { Write-Warning "port local $Port occupe, port ephemere utilise"; $udp = New-Object System.Net.Sockets.UdpClient }
  try {
    $udp.Client.ReceiveTimeout = $TimeoutMs
    $bytes = [Text.Encoding]::ASCII.GetBytes($Command + [char]0)
    [void]$udp.Send($bytes, $bytes.Length, $Ip, $Port)
    $from = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
    try {
      $reply = $udp.Receive([ref]$from)
      return ([Text.Encoding]::ASCII.GetString($reply)).TrimEnd([char]0, "`r", "`n")
    } catch [System.Net.Sockets.SocketException] {
      return $null
    }
  } finally { $udp.Close() }
}

# --- Modbus TCP, port 502 -----------------------------------------------------

$script:ModbusTransaction = 0

function Invoke-WagoModbus {
  # Une requete Modbus TCP, rend la PDU de reponse (octets) sans l'en-tete MBAP.
  # Leve une exception sur code d'exception Modbus.
  param(
    [Parameter(Mandatory)][string]$Ip,
    [Parameter(Mandatory)][byte[]]$Pdu,
    [int]$Port = 502,
    [byte]$UnitId = 1,
    [int]$TimeoutMs = 2000
  )
  $script:ModbusTransaction = ($script:ModbusTransaction + 1) -band 0xFFFF
  $tid = $script:ModbusTransaction
  $len = $Pdu.Length + 1
  $mbap = [byte[]]@(($tid -shr 8), ($tid -band 0xFF), 0, 0, ($len -shr 8), ($len -band 0xFF), $UnitId)
  $frame = $mbap + $Pdu
  $client = New-Object System.Net.Sockets.TcpClient
  try {
    $ar = $client.BeginConnect($Ip, $Port, $null, $null)
    if (-not $ar.AsyncWaitHandle.WaitOne($TimeoutMs)) { throw "Modbus : pas de connexion TCP vers $Ip`:$Port en $TimeoutMs ms" }
    $client.EndConnect($ar)
    $client.ReceiveTimeout = $TimeoutMs
    $s = $client.GetStream()
    $s.Write($frame, 0, $frame.Length)
    $head = New-Object byte[] 7
    $got = 0
    while ($got -lt 7) { $n = $s.Read($head, $got, 7 - $got); if ($n -le 0) { throw "Modbus : reponse tronquee" }; $got += $n }
    $plen = ($head[4] -shl 8) + $head[5] - 1
    $body = New-Object byte[] $plen
    $got = 0
    while ($got -lt $plen) { $n = $s.Read($body, $got, $plen - $got); if ($n -le 0) { throw "Modbus : reponse tronquee" }; $got += $n }
    if (($body[0] -band 0x80) -ne 0) {
      $codes = @{ 1='fonction illegale'; 2='adresse illegale'; 3='valeur illegale'; 4='defaut esclave' }
      $why = $codes[[int]$body[1]]; if (-not $why) { $why = "code $($body[1])" }
      throw ("Modbus : exception sur FC{0} - {1}" -f ($body[0] -band 0x7F), $why)
    }
    return $body
  } finally { $client.Close() }
}

function Read-WagoRegisters {
  # FC3 (holding) ou FC4 (input). Rend un tableau de WORD non signes.
  param([Parameter(Mandatory)][string]$Ip, [Parameter(Mandatory)][int]$Address, [int]$Count = 1, [ValidateSet(3,4)][int]$Function = 3, [int]$TimeoutMs = 2000)
  if ($Count -lt 1 -or $Count -gt 125) { throw "Count doit etre entre 1 et 125" }
  $pdu = [byte[]]@($Function, ($Address -shr 8), ($Address -band 0xFF), ($Count -shr 8), ($Count -band 0xFF))
  $r = Invoke-WagoModbus -Ip $Ip -Pdu $pdu -TimeoutMs $TimeoutMs
  $n = [int]$r[1] / 2
  $out = New-Object int[] $n
  # -shl sur un [byte] reste un byte en PS 5.1 : caster avant de decaler.
  for ($i = 0; $i -lt $n; $i++) { $out[$i] = ([int]$r[2 + 2*$i] -shl 8) + [int]$r[3 + 2*$i] }
  return $out
}

function Read-WagoCoils {
  # FC1 (coils) ou FC2 (discrete inputs). Rend un tableau de BOOL, index 0 = premiere adresse.
  param([Parameter(Mandatory)][string]$Ip, [Parameter(Mandatory)][int]$Address, [int]$Count = 1, [ValidateSet(1,2)][int]$Function = 1, [int]$TimeoutMs = 2000)
  if ($Count -lt 1 -or $Count -gt 2000) { throw "Count doit etre entre 1 et 2000" }
  $pdu = [byte[]]@($Function, ($Address -shr 8), ($Address -band 0xFF), ($Count -shr 8), ($Count -band 0xFF))
  $r = Invoke-WagoModbus -Ip $Ip -Pdu $pdu -TimeoutMs $TimeoutMs
  $out = New-Object bool[] $Count
  for ($i = 0; $i -lt $Count; $i++) { $out[$i] = (($r[2 + [int][Math]::Floor($i / 8)] -shr ($i % 8)) -band 1) -eq 1 }
  return $out
}

function Write-WagoCoil {
  # FC5. Ecriture : n'agit que sur ce que l'automate publie en sortie. A n'utiliser
  # que sur un automate de test, avec -AllowWrite explicite cote appelant.
  param([Parameter(Mandatory)][string]$Ip, [Parameter(Mandatory)][int]$Address, [Parameter(Mandatory)][bool]$Value, [int]$TimeoutMs = 2000)
  $v = 0; if ($Value) { $v = 0xFF }
  $pdu = [byte[]]@(5, ($Address -shr 8), ($Address -band 0xFF), $v, 0)
  [void](Invoke-WagoModbus -Ip $Ip -Pdu $pdu -TimeoutMs $TimeoutMs)
}

function Write-WagoRegister {
  # FC6. Meme reserve que Write-WagoCoil.
  param([Parameter(Mandatory)][string]$Ip, [Parameter(Mandatory)][int]$Address, [Parameter(Mandatory)][int]$Value, [int]$TimeoutMs = 2000)
  $pdu = [byte[]]@(6, ($Address -shr 8), ($Address -band 0xFF), ($Value -shr 8), ($Value -band 0xFF))
  [void](Invoke-WagoModbus -Ip $Ip -Pdu $pdu -TimeoutMs $TimeoutMs)
}

function Invoke-WagoSoftReset {
  # Redemarrage logiciel du coupleur : 0x55AA puis 0xAA55 dans 0x2040. L'automate
  # coupe la connexion aussitot ; le second write peut donc rester sans reponse.
  # Ne jamais generaliser a 0x2041..0x2043 (formatage flash, reglages usine).
  param([Parameter(Mandatory)][string]$Ip)
  Write-WagoRegister -Ip $Ip -Address 0x2040 -Value 0x55AA
  try { Write-WagoRegister -Ip $Ip -Address 0x2040 -Value 0xAA55 } catch {}
}

# --- Cartographie WAGO 750-8xx, registres de description -----------------------
# 0x2011 serie (750), 0x2012 reference (841, 881...), 0x2013/0x2014 firmware.
# 0x2030..0x2032 : trois blocs de 64 mots, un par module du rack.
#   module complexe  : sa reference (647, 641, 455...)
#   module digital   : bit 15 a 1, bit 0 = entree, bit 1 = sortie, bits 8..14 = voies

function Get-WagoIdentity {
  param([Parameter(Mandatory)][string]$Ip)
  # Le firmware refuse une lecture groupee de ces registres : un par requete.
  $r = foreach ($a in 0x2011, 0x2012, 0x2013, 0x2014) { (Read-WagoRegisters -Ip $Ip -Address $a -Count 1)[0] }
  return [pscustomobject]@{ Series = $r[0]; Item = $r[1]; FwMajor = $r[2]; FwMinor = $r[3] }
}

function ConvertFrom-WagoModuleWord([int]$w) {
  if ($w -eq 0) { return $null }
  if (($w -band 0x8000) -ne 0) {
    $ch = ($w -shr 8) -band 0x7F
    $kind = @()
    if (($w -band 1) -ne 0) { $kind += 'DI' }
    if (($w -band 2) -ne 0) { $kind += 'DO' }
    return [pscustomobject]@{ Raw = ('0x{0:X4}' -f $w); Kind = 'digital'; Type = ($kind -join '/'); Channels = $ch; Item = $null }
  }
  return [pscustomobject]@{ Raw = ('0x{0:X4}' -f $w); Kind = 'complexe'; Type = ('750-{0}' -f $w); Channels = $null; Item = $w }
}

function Get-WagoModules {
  param([Parameter(Mandatory)][string]$Ip)
  $words = @()
  foreach ($base in 0x2030, 0x2031, 0x2032) {
    try { $words += Read-WagoRegisters -Ip $Ip -Address $base -Count 64 } catch { break }
  }
  $list = @()
  $pos = 0
  foreach ($w in $words) {
    if ($w -eq 0) { break }
    $m = ConvertFrom-WagoModuleWord $w
    $m | Add-Member -NotePropertyName Slot -NotePropertyValue $pos
    $list += $m
    $pos++
  }
  return $list
}
