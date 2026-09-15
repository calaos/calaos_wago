<#
 wago-ftp.ps1 - liste la flash de l'automate (FTP, compte par defaut admin/wago)
 et rapatrie un fichier pour le comparer au depot. Jamais d'envoi ni de suppression.

 Usage :
   .\wago-ftp.ps1 -Ip 192.168.30.124                       liste /PLC
   .\wago-ftp.ps1 -Ip 192.168.30.124 -Path /                liste la racine
   .\wago-ftp.ps1 -Ip 192.168.30.124 -Get /PLC/DEFAULT.CHK -To .\build
   .\wago-ftp.ps1 -Ip 192.168.30.124 -Get /PLC/DEFAULT.PRG -To .\build -Compare ..\pro\wago_841.PRG

 -Compare : apres -Get, compare octet a octet au fichier donne (le boot project du depot).

 Ecriture, sous -AllowWrite seulement, sur un automate de test :
   .\wago-ftp.ps1 -Ip 192.168.30.124 -Put ..\pro\wago_841.PRG -As /PLC/DEFAULT.PRG -AllowWrite
   .\wago-ftp.ps1 -Ip 192.168.30.124 -Delete /PLC/test.txt -AllowWrite
 -Put envoie en binaire puis relit le fichier et le compare : un boot project qui
 ne boote pas alors que la relecture est IDENTIQUE n'est pas un probleme de transfert.
#>
param(
  [Parameter(Mandatory)][string]$Ip,
  [string]$Path = '/PLC',
  [string]$Get,
  [string]$To = '.',
  [string]$Compare,
  [string]$Put,
  [string]$As,
  [string]$Delete,
  [switch]$AllowWrite,
  [int]$FlashWaitSec = 300,
  [string]$User = 'admin',
  [string]$Password = 'wago',
  [int]$TimeoutMs = 5000
)

# Client FTP minimal sur socket : FtpWebRequest garde un canal de commande en cache
# par processus, et le serveur du 750 le laisse desynchronise apres un transfert
# (« 150 » recu la ou .NET attend un 2xx). Une session neuve par commande evite ca.
$ErrorActionPreference = 'Stop'

function Read-Reply([IO.StreamReader]$r) {
  try { $line = $r.ReadLine() } catch { throw "FTP : pas de reponse du serveur ($($_.Exception.InnerException.Message))" }
  if ($null -eq $line) { throw "FTP : connexion fermee" }
  if ($line.Length -ge 4 -and $line[3] -eq '-') {
    $code = $line.Substring(0, 3)
    while ($true) { $l = $r.ReadLine(); if ($null -eq $l) { break }; if ($l.StartsWith("$code ")) { break } }
  }
  return $line
}

function Send-Cmd([IO.StreamWriter]$w, [IO.StreamReader]$r, [string]$cmd) {
  $w.Write("$cmd`r`n"); $w.Flush()
  $reply = Read-Reply $r
  if ($reply[0] -eq '4' -or $reply[0] -eq '5') { throw "FTP : $cmd -> $reply" }
  return $reply
}

function Invoke-FtpTransfer {
  # Ouvre une session, execute $Command en passif : LIST / RETR rendent les octets
  # recus, STOR envoie $Upload, DELE n'ouvre pas de canal de donnees.
  param([string]$Command, [string]$Cwd, [byte[]]$Upload)
  # Le 750 ne sert qu'une session FTP a la fois et garde la precedente ouverte
  # quelques dizaines de secondes : tant que la banniere ne vient pas, on reessaie.
  $deadline = (Get-Date).AddSeconds(90)
  while ($true) {
    $ctl = New-Object System.Net.Sockets.TcpClient
    $ctl.ReceiveTimeout = 3000; $ctl.SendTimeout = $TimeoutMs
    $ctl.Connect($Ip, 21)
    $cs = $ctl.GetStream()
    $r = New-Object IO.StreamReader($cs, [Text.Encoding]::ASCII)
    $w = New-Object IO.StreamWriter($cs, [Text.Encoding]::ASCII)
    try { [void](Read-Reply $r); break }
    catch {
      $ctl.Close()
      if ((Get-Date) -gt $deadline) { throw "FTP : serveur occupe, pas de banniere en 90 s" }
      Start-Sleep -Seconds 3
    }
  }
  $ctl.ReceiveTimeout = $TimeoutMs
  try {
    [void](Send-Cmd $w $r "USER $User")
    [void](Send-Cmd $w $r "PASS $Password")
    [void](Send-Cmd $w $r "TYPE I")
    if ($Cwd) { [void](Send-Cmd $w $r "CWD $Cwd") }
    if ($Command.StartsWith('DELE')) {
      # Comme STOR : la reponse ne vient qu'une fois la flash ecrite.
      $ctl.ReceiveTimeout = $FlashWaitSec * 1000
      [void](Send-Cmd $w $r $Command)
      [void](Send-Cmd $w $r 'QUIT')
      return ,[byte[]]@()
    }
    $pasv = Send-Cmd $w $r "PASV"
    if ($pasv -notmatch '\((\d+),(\d+),(\d+),(\d+),(\d+),(\d+)\)') { throw "FTP : reponse PASV illisible : $pasv" }
    $port = [int]$Matches[5] * 256 + [int]$Matches[6]
    $data = New-Object System.Net.Sockets.TcpClient
    $data.ReceiveTimeout = $TimeoutMs; $data.SendTimeout = $TimeoutMs
    $data.Connect($Ip, $port)
    [void](Send-Cmd $w $r $Command)
    $ds = $data.GetStream()
    $ms = New-Object IO.MemoryStream
    if ($Command.StartsWith('STOR')) {
      $ds.Write($Upload, 0, $Upload.Length); $ds.Flush()
      $data.Client.Shutdown([System.Net.Sockets.SocketShutdown]::Send)
      Start-Sleep -Milliseconds 200
      $ds.Close(); $data.Close()
      # Le 226 ne vient qu'une fois la flash ecrite, ce qui peut prendre des minutes.
      # Fermer la session avant, et le 750 jette le fichier. Mais le canal de
      # commande tombe parfois avant le 226 alors que le fichier est bien ecrit :
      # ce n'est pas un echec, c'est la relecture qui tranche.
      $t0 = Get-Date
      Write-Host ("  attente de l'ecriture flash (jusqu'a {0} s)..." -f $FlashWaitSec) -NoNewline
      $ctl.ReceiveTimeout = $FlashWaitSec * 1000
      try {
        [void](Read-Reply $r)
        Write-Host (" {0:N0} s" -f ((Get-Date) - $t0).TotalSeconds)
      } catch {
        Write-Host (" pas d'acquittement apres {0:N0} s, la relecture tranchera" -f ((Get-Date) - $t0).TotalSeconds)
      }
    } else {
      $buf = New-Object byte[] 65536
      while (($n = $ds.Read($buf, 0, $buf.Length)) -gt 0) { $ms.Write($buf, 0, $n) }
      $ds.Close(); $data.Close()
      [void](Read-Reply $r)
    }
    [void](Send-Cmd $w $r 'QUIT')
    return ,$ms.ToArray()
  } finally { $ctl.Close() }
}

if ($Put -or $Delete) {
  if (-not $AllowWrite) { throw "Ecriture sur la flash refusee sans -AllowWrite" }
}

if ($Delete) {
  [void](Invoke-FtpTransfer "DELE $Delete")
  $dir = Split-Path $Delete -Parent; $dir = $dir -replace '\\', '/'; if (-not $dir) { $dir = '/' }
  $listing = [Text.Encoding]::ASCII.GetString((Invoke-FtpTransfer -Command 'LIST' -Cwd $dir))
  if ($listing -match ('(?im)\s' + [regex]::Escape((Split-Path $Delete -Leaf)) + '\s*$')) { "ECHEC : ftp://$Ip$Delete est toujours la"; exit 1 }
  "supprime : ftp://$Ip$Delete"
  exit 0
}

if ($Put) {
  if (-not $As) { throw "-Put exige -As <chemin sur l'automate>, ex. /PLC/DEFAULT.PRG" }
  $src = [IO.File]::ReadAllBytes($Put)
  [void](Invoke-FtpTransfer -Command "STOR $As" -Upload $src)
  $back = Invoke-FtpTransfer "RETR $As"
  "{0} -> ftp://{1}{2} ({3} octets envoyes, {4} relus)" -f $Put, $Ip, $As, $src.Length, $back.Length
  if ($back.Length -ne $src.Length) { "DIFFERENT : la relecture n'a pas la bonne taille"; exit 1 }
  for ($i = 0; $i -lt $src.Length; $i++) { if ($back[$i] -ne $src[$i]) { "DIFFERENT : premier ecart a l'octet $i"; exit 1 } }
  "IDENTIQUE apres relecture"
  exit 0
}

if ($Get) {
  $bytes = Invoke-FtpTransfer "RETR $Get"
  $dest = Join-Path $To (Split-Path $Get -Leaf)
  [IO.File]::WriteAllBytes($dest, $bytes)
  "ftp://{0}{1} -> {2} ({3} octets)" -f $Ip, $Get, $dest, $bytes.Length
  if ($Compare) {
    $b = [IO.File]::ReadAllBytes($Compare)
    if ($bytes.Length -ne $b.Length) { "DIFFERENT : {0} octets sur l'automate, {1} dans {2}" -f $bytes.Length, $b.Length, $Compare; exit 1 }
    for ($i = 0; $i -lt $bytes.Length; $i++) { if ($bytes[$i] -ne $b[$i]) { "DIFFERENT : premier ecart a l'octet $i"; exit 1 } }
    "IDENTIQUE a $Compare"
  }
  exit 0
}

# « LIST / » rend une liste vide sur le 750 ; se placer dans le dossier d'abord.
$dir = $Path.TrimEnd('/'); if (-not $dir) { $dir = '/' }
$bytes = Invoke-FtpTransfer -Command 'LIST' -Cwd $dir
"--- ftp://$Ip$dir ---"
[Text.Encoding]::ASCII.GetString($bytes).TrimEnd()
