<#
 wago-debug.ps1 - runbook de debug automate : flash, reset, etat de reference,
 stimulus sur une sortie, relevé de la chaine interne, verdict, restauration.
 Tout est journalise.

 La chaine parcourue, pour la sortie <n> :
   netout   ce que le serveur a ecrit dans netOutStandard (vu par le programme)
   outstate la table dégradée OutArrState
   written  la valeur reellement passee a WRITE_OUTPUT_WORD au dernier cycle
   readback READ_OUTPUT_WORD relu par le programme
   qw       l'image de sortie physique, lue en Modbus, hors programme
 Le premier maillon qui ne porte pas la valeur attendue nomme le defaut.

 Usage :
   .\wago-debug.ps1 -Ip 192.168.30.124 -Output 15 -AllowWrite
   .\wago-debug.ps1 -Ip 192.168.30.123 -Output 27 -Flash ..\pro\wago_889 -AllowWrite
   .\wago-debug.ps1 -Ip 192.168.30.123 -Output 27 -Flash ..\pro\wago_889 -Restore ..\..\Wago_3.0\wago_889 -AllowWrite
   .\wago-debug.ps1 -Ip 192.168.30.123 -Output 27 -Capture 120

 -Flash / -Restore prennent le chemin SANS extension : .PRG et .CHK sont deduits.
 -Capture N : n'affiche que les changements pendant N secondes (bascule manuelle).

 -Mode choisit la branche a mettre a l'epreuve, calaos_server etant arrete :
   auto       (defaut) on prend la branche que l'automate annonce
   server     on tient le mode serveur en envoyant le heartbeat, stimulus par coil
   standalone on laisse le timer de 30 s expirer, stimulus par WAGO_SET_OUTPUT
 C'est la branche serveur qui etait morte avec une 647 : -Mode server est le test
 de T-13, et il faut que calaos_server soit arrete pour qu'il ne reecrive pas la coil.
#>
param(
  [Parameter(Mandatory)][string]$Ip,
  [int]$Output = -1,
  [string]$Flash,
  [string]$Restore,
  [int]$Capture = 0,
  [ValidateSet('auto','server','standalone')][string]$Mode = 'auto',
  [switch]$AllowWrite,
  [string]$LogDir,
  [int]$TimeoutMs = 2000
)
. "$PSScriptRoot\WagoNet.ps1"

if (-not $LogDir) { $LogDir = $PSScriptRoot }
$log = Join-Path $LogDir ("wago-debug_{0}_{1}.log" -f ($Ip -replace '\.', '-'), (Get-Date -Format 'yyyyMMdd-HHmmss'))
$lines = New-Object System.Collections.Generic.List[string]
function Say([string]$s) { $lines.Add($s); Write-Host $s; [IO.File]::WriteAllLines($log, $lines, (New-Object Text.UTF8Encoding($false))) }
function Stamp([string]$s) { Say ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $s) }

function Udp([string]$c, [switch]$Write) { Invoke-WagoUdp -Ip $Ip -Command $c -TimeoutMs $TimeoutMs -AllowWrite:$Write }

# --- identite et concordance du binaire ---------------------------------------

function Get-PrgProject([string]$prg) {
  # Le nom du projet est en clair dans les derniers octets du boot project.
  $b = [IO.File]::ReadAllBytes($prg)
  $tail = [Text.Encoding]::ASCII.GetString($b, [Math]::Max(0, $b.Length - 64), [Math]::Min(64, $b.Length))
  if ($tail -match '(wago_\d+)\.pro') { return $Matches[1] }
  return $null
}

function Assert-Model([string]$base) {
  $id = Get-WagoIdentity -Ip $Ip
  $expected = "wago_$($id.Item)"
  $proj = Get-PrgProject "$base.PRG"
  if ($null -eq $proj) { throw "impossible de lire le nom de projet dans $base.PRG" }
  if ($proj -ne $expected) { throw "REFUS : $base.PRG est un '$proj', l'automate est un 750-$($id.Item) (attendu '$expected')" }
  Say ("  binaire $proj concorde avec le 750-{0}" -f $id.Item)
}

function Invoke-Flash([string]$base) {
  Assert-Model $base
  foreach ($ext in 'CHK', 'PRG') {
    Stamp "envoi DEFAULT.$ext"
    & "$PSScriptRoot\wago-ftp.ps1" -Ip $Ip -Put "$base.$ext" -As "/PLC/DEFAULT.$ext" -AllowWrite -FlashWaitSec 900 | ForEach-Object { Say "  $_" }
    if ($LASTEXITCODE -ne 0) { throw "echec de l'envoi de DEFAULT.$ext" }
  }
  Stamp 'reset'
  Invoke-WagoSoftReset -Ip $Ip
  # Sondage espace : trop de connexions Modbus rapprochees saturent le coupleur.
  $t0 = Get-Date
  Start-Sleep -Seconds 10
  while (((Get-Date) - $t0).TotalSeconds -lt 90) {
    try { $null = Get-WagoIdentity -Ip $Ip; break } catch { Start-Sleep -Seconds 15 }
  }
  $v = $null
  $t0 = Get-Date
  while (((Get-Date) - $t0).TotalSeconds -lt 90 -and $null -eq $v) { $v = Udp 'WAGO_GET_VERSION'; if ($null -eq $v) { Start-Sleep -Seconds 5 } }
  if ($null -eq $v) { throw "le programme ne repond pas apres le reset" }
  Say "  $v"
  return $v
}

# --- releve ------------------------------------------------------------------

function Get-Snapshot([int]$n) {
  $s = [pscustomobject]@{
    time = Get-Date -Format 'HH:mm:ss'
    cycle = $null; outloop = $null; branch = $null; hb = $null; hbEt = $null
    led = $null; errDig = $null; errDali = $null
    word = $null; bit = $null
    netout = $null; outstate = $null; written = $null; readback = $null; qw = $null
    coil = $null
  }
  $r = Udp 'WAGO_GET_STATE'
  if ($r) {
    $t = $r -split ' '
    if ($t.Count -ge 9) {
      $s.cycle = $t[1]; $s.outloop = $t[2]; $s.branch = [int]$t[3]; $s.hb = [int]$t[4]
      $s.hbEt = $t[5]; $s.led = $t[6]; $s.errDig = [int]$t[7]; $s.errDali = [int]$t[8]
    }
  }
  $r = Udp ("WAGO_GET_OUTPUT_CHAIN {0}" -f $n)
  if ($r) {
    $t = $r -split ' '
    if ($t.Count -ge 8) {
      $s.word = $t[2]; $s.bit = $t[3]
      $s.netout = $t[4]; $s.outstate = $t[5]; $s.written = $t[6]; $s.readback = $t[7]
    }
  }
  try { $s.coil = [int](Read-WagoCoils -Ip $Ip -Address (4096 + $n) -Count 1 -TimeoutMs $TimeoutMs)[0] } catch {}
  if ($null -ne $s.word -and $s.word -ne 'NA') {
    try { $s.qw = (Read-WagoRegisters -Ip $Ip -Address (0x0200 + [int]$s.word) -Count 1 -TimeoutMs $TimeoutMs)[0] } catch {}
  }
  return $s
}

function Get-Bit($wordValue, $bit) {
  if ($null -eq $wordValue -or $wordValue -eq 'NA') { return 'NA' }
  return (([int]$wordValue -shr [int]$bit) -band 1)
}

function Show-Snapshot($s, [string]$tag) {
  Say ("  {0,-10} cycle={1} outloop={2} branch={3} hb={4} errdig={5} errdali={6}" -f $tag, $s.cycle, $s.outloop, $s.branch, $s.hb, $s.errDig, $s.errDali)
  Say ("             mot={0} bit={1} coil={2} | netout={3} outstate={4} written={5} readback={6} qw={7}" -f `
    $s.word, $s.bit, $s.coil, (Get-Bit $s.netout $s.bit), (Get-Bit $s.outstate $s.bit), (Get-Bit $s.written $s.bit), (Get-Bit $s.readback $s.bit), (Get-Bit $s.qw $s.bit))
}

function Test-Chain($s, [int]$expected) {
  # En mode serveur la chaine part de netOutStandard ; en degradé le programme
  # publie OutArrState et netout n'a pas a suivre.
  $links = @()
  if ($s.branch -eq 2) { $links += , @('netout', (Get-Bit $s.netout $s.bit)) }
  $links += , @('outstate', (Get-Bit $s.outstate $s.bit))
  $links += , @('written', (Get-Bit $s.written $s.bit))
  $links += , @('readback', (Get-Bit $s.readback $s.bit))
  $links += , @('qw', (Get-Bit $s.qw $s.bit))

  $ok = @()
  foreach ($l in $links) {
    if ($l[1] -eq 'NA') { Say ("  VERDICT : chaine OK jusqu'a [{0}], maillon suivant '{1}' indisponible (NA)" -f ($ok -join ' -> '), $l[0]); return }
    if ([int]$l[1] -ne $expected) {
      if ($ok.Count -eq 0) { Say ("  VERDICT : rompu des le premier maillon '{0}' (={1}, attendu {2})" -f $l[0], $l[1], $expected) }
      else { Say ("  VERDICT : chaine OK jusqu'a [{0}], ROMPUE a '{1}' (={2}, attendu {3})" -f ($ok -join ' -> '), $l[0], $l[1], $expected) }
      if ($s.errDig -eq 1) { Say "            write_word_out a leve ERROR : l'ecriture est refusee, pas ecrasee" }
      else { Say "            write_word_out n'a pas leve ERROR" }
      return
    }
    $ok += $l[0]
  }
  Say ("  VERDICT : chaine complete a {0} [{1}]" -f $expected, ($ok -join ' -> '))
}

# --- deroule ------------------------------------------------------------------

Stamp ("=== {0} ===" -f $Ip)

if ($Flash) {
  if (-not $AllowWrite) { throw "-Flash exige -AllowWrite" }
  [void](Invoke-Flash $Flash)
}

$ver = Udp 'WAGO_GET_VERSION'
if ($null -eq $ver) { Say "pas de reponse UDP : programme arrete ou IP fausse"; exit 1 }
Say "version : $ver"
$vt = $ver -split ' '
if ($vt.Count -lt 2 -or [int](($vt[1] -split '\.')[0]) -lt 4) { Say "ATTENTION : verbes de debug absents avant la 4.0, la suite ne donnera rien"; exit 1 }

$info = Udp 'WAGO_GET_INFO'
Say "info    : $info"
$nbOut = 0
if ($info) { $t = $info -split ' '; if ($t.Count -ge 6) { $nbOut = [int]$t[5] } }
Say ("layout  : {0}" -f (Udp 'WAGO_GET_LAYOUT'))

if ($Capture -gt 0) {
  if ($Output -lt 0) { throw "-Capture exige -Output" }
  Stamp ("capture {0} s sur la sortie {1}, seuls les changements sont affiches" -f $Capture, $Output)
  $prev = ''
  $t0 = Get-Date
  while (((Get-Date) - $t0).TotalSeconds -lt $Capture) {
    $s = Get-Snapshot $Output
    $cur = "{0}|{1}|{2}|{3}|{4}|{5}|{6}" -f $s.branch, $s.coil, (Get-Bit $s.netout $s.bit), (Get-Bit $s.outstate $s.bit), (Get-Bit $s.written $s.bit), (Get-Bit $s.readback $s.bit), (Get-Bit $s.qw $s.bit)
    if ($cur -ne $prev) { Show-Snapshot $s $s.time; $prev = $cur }
    Start-Sleep -Milliseconds 700
  }
  Stamp 'fin de capture'
  exit 0
}

if ($Output -lt 0) { Say "pas de -Output : rien a stimuler"; exit 0 }
if ($nbOut -gt 0 -and $Output -ge $nbOut) { throw "REFUS : sortie $Output hors du rack ($nbOut sorties digitales)" }

if ($Mode -ne 'auto') {
  if (-not $AllowWrite) { throw "-Mode $Mode exige -AllowWrite" }
  if ($Mode -eq 'server') {
    Stamp 'maintien du mode serveur (heartbeat emis par cet outil)'
    [void](Udp 'WAGO_HEARTBEAT' -Write)
    Start-Sleep -Milliseconds 600
  } else {
    Stamp 'attente de l''expiration du heartbeat (jusqu''a 35 s) pour passer en degradé'
    $t0 = Get-Date
    while (((Get-Date) - $t0).TotalSeconds -lt 35) {
      $s = Get-Snapshot $Output
      if ($s.branch -eq 1) { break }
      Start-Sleep -Seconds 2
    }
  }
}

Stamp "etat de reference"
$base = Get-Snapshot $Output
Show-Snapshot $base 'baseline'
if ($Mode -eq 'server' -and $base.branch -ne 2) { Say "ATTENTION : branche $($base.branch), le mode serveur n'a pas pris" }
if ($Mode -eq 'standalone' -and $base.branch -ne 1) { Say "ATTENTION : branche $($base.branch), calaos_server heartbeat encore ?" }

if (-not $AllowWrite) { Say "pas de -AllowWrite : pas de stimulus, releve seul"; exit 0 }

foreach ($val in 1, 0) {
  Stamp ("stimulus sortie {0} -> {1}" -f $Output, $val)
  if ($Mode -eq 'server') { [void](Udp 'WAGO_HEARTBEAT' -Write) }
  if ($base.branch -eq 1) {
    Say "  mode degradé : WAGO_SET_OUTPUT"
    [void](Udp ("WAGO_SET_OUTPUT {0} {1}" -f $Output, $val) -Write)
  } else {
    Say "  mode serveur : coil Modbus $(4096 + $Output)"
    Write-WagoCoil -Ip $Ip -Address (4096 + $Output) -Value ($val -eq 1) -TimeoutMs $TimeoutMs
  }
  Start-Sleep -Milliseconds 600
  if ($Mode -eq 'server') { [void](Udp 'WAGO_HEARTBEAT' -Write) }
  $s = Get-Snapshot $Output
  Show-Snapshot $s ("apres->{0}" -f $val)
  # La coil relue en FC1 ne reflete pas ce que FC5 y a ecrit : c'est `netout`, la
  # vue du programme sur netOutStandard, qui dit si l'ecriture est arrivee. Un
  # ecart la signale un autre ecrivain (calaos_server relance ?).
  if ($s.branch -eq 2 -and (Get-Bit $s.netout $s.bit) -ne $val) {
    Say "  NOTE : netOutStandard ne porte pas la valeur ecrite - un autre ecrivain est actif ?"
  }
  Test-Chain $s $val
}

if ($Restore) {
  Stamp "restauration"
  [void](Invoke-Flash $Restore)
}

Stamp "fin"
Say "journal : $log"
