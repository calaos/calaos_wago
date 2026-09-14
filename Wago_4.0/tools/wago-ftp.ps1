<#
 wago-ftp.ps1 - liste la flash de l'automate (FTP, compte par defaut admin/wago)
 et rapatrie un fichier pour le comparer au depot. Jamais d'envoi ni de suppression.

 Usage :
   .\wago-ftp.ps1 -Ip 192.168.30.124                       liste /PLC
   .\wago-ftp.ps1 -Ip 192.168.30.124 -Path /                liste la racine
   .\wago-ftp.ps1 -Ip 192.168.30.124 -Get /PLC/DEFAULT.CHK -To .\build
   .\wago-ftp.ps1 -Ip 192.168.30.124 -Get /PLC/DEFAULT.PRG -To .\build -Compare ..\pro\wago_841.PRG

 -Compare : apres -Get, compare octet a octet au fichier donne (le boot project du depot).
#>
param(
  [Parameter(Mandatory)][string]$Ip,
  [string]$Path = '/PLC',
  [string]$Get,
  [string]$To = '.',
  [string]$Compare,
  [string]$User = 'admin',
  [string]$Password = 'wago',
  [int]$TimeoutMs = 5000
)

# Client FTP minimal sur socket : FtpWebRequest garde un canal de commande en cache
# par processus, et le serveur du 750 le laisse desynchronise apres un transfert
# (« 150 » recu la ou .NET attend un 2xx). Une session neuve par commande evite ca.
function Read-Reply([IO.StreamReader]$r) {
  $line = $r.ReadLine()
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
  # Ouvre une session, execute $Command (LIST ou RETR) en passif, rend les octets recus.
  param([string]$Command, [string]$Cwd)
  $ctl = New-Object System.Net.Sockets.TcpClient
  $ctl.ReceiveTimeout = $TimeoutMs; $ctl.SendTimeout = $TimeoutMs
  $ctl.Connect($Ip, 21)
  $cs = $ctl.GetStream()
  $r = New-Object IO.StreamReader($cs, [Text.Encoding]::ASCII)
  $w = New-Object IO.StreamWriter($cs, [Text.Encoding]::ASCII)
  try {
    [void](Read-Reply $r)
    [void](Send-Cmd $w $r "USER $User")
    [void](Send-Cmd $w $r "PASS $Password")
    [void](Send-Cmd $w $r "TYPE I")
    if ($Cwd) { [void](Send-Cmd $w $r "CWD $Cwd") }
    $pasv = Send-Cmd $w $r "PASV"
    if ($pasv -notmatch '\((\d+),(\d+),(\d+),(\d+),(\d+),(\d+)\)') { throw "FTP : reponse PASV illisible : $pasv" }
    $port = [int]$Matches[5] * 256 + [int]$Matches[6]
    $data = New-Object System.Net.Sockets.TcpClient
    $data.ReceiveTimeout = $TimeoutMs
    $data.Connect($Ip, $port)
    [void](Send-Cmd $w $r $Command)
    $ms = New-Object IO.MemoryStream
    $ds = $data.GetStream()
    $buf = New-Object byte[] 65536
    while (($n = $ds.Read($buf, 0, $buf.Length)) -gt 0) { $ms.Write($buf, 0, $n) }
    $data.Close()
    [void](Read-Reply $r)
    $w.Write("QUIT`r`n"); $w.Flush()
    return ,$ms.ToArray()
  } finally { $ctl.Close() }
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
