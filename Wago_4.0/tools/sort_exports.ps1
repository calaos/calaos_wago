<#
 sort_exports.ps1
 Classe les .exp exportes (build\export\<cible>\) vers src\ :
   - identique sur TOUTES les cibles  -> src\common\<obj>.exp
   - present sur une seule cible, ou different entre cibles
                                       -> src\targets\<cible>\<obj>.exp
 Produit build\export_report.txt

 Usage : powershell -ExecutionPolicy Bypass -File tools\sort_exports.ps1 [-Clean]
#>
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [string[]]$Targets = @("841","849","880","881","889","891","893"),
  [switch]$Clean
)

$ExportDir = Join-Path $Root "build\export"
$SrcDir    = Join-Path $Root "src"
$Common    = Join-Path $SrcDir "common"
$TgtRoot   = Join-Path $SrcDir "targets"
$Report    = Join-Path $Root "build\export_report.txt"

if ($Clean) {
  Get-ChildItem $Common -Filter *.exp -ErrorAction SilentlyContinue | Remove-Item
  foreach ($t in $Targets) { Get-ChildItem (Join-Path $TgtRoot $t) -Filter *.exp -ErrorAction SilentlyContinue | Remove-Item }
}
New-Item -ItemType Directory -Force -Path $Common | Out-Null
foreach ($t in $Targets) { New-Item -ItemType Directory -Force -Path (Join-Path $TgtRoot $t) | Out-Null }

# --- Normalisation pour la comparaison (CRLF/LF, espaces de fin) ---
function Get-NormHash([string]$path) {
  $txt = [IO.File]::ReadAllText($path, [Text.Encoding]::GetEncoding(1252))
  $txt = ($txt -replace "`r`n", "`n") -replace "[ \t]+`n", "`n"
  $sha = [Security.Cryptography.SHA256]::Create()
  [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($txt))) -replace "-",""
}

# --- Inventaire : nom de fichier -> { cible -> hash } ----------------
$index = @{}
foreach ($t in $Targets) {
  $dir = Join-Path $ExportDir $t
  if (-not (Test-Path $dir)) { Write-Warning "Pas d'export pour la cible $t ($dir)"; continue }
  foreach ($f in Get-ChildItem $dir -Filter *.exp) {
    if (-not $index.ContainsKey($f.Name)) { $index[$f.Name] = @{} }
    $index[$f.Name][$t] = Get-NormHash $f.FullName
  }
}

$lines = @()
$nCommon = 0; $nTarget = 0
foreach ($name in ($index.Keys | Sort-Object)) {
  $byTarget = $index[$name]
  $hashes = @($byTarget.Values | Select-Object -Unique)
  $onAll = ($byTarget.Count -eq $Targets.Count)

  if ($onAll -and $hashes.Count -eq 1) {
    $src = Join-Path (Join-Path $ExportDir $Targets[0]) $name
    Copy-Item $src (Join-Path $Common $name) -Force
    $lines += "COMMON   $name"
    $nCommon++
  } else {
    foreach ($t in $byTarget.Keys) {
      Copy-Item (Join-Path (Join-Path $ExportDir $t) $name) (Join-Path (Join-Path $TgtRoot $t) $name) -Force
    }
    $where = ($byTarget.Keys | Sort-Object) -join ","
    $why = if (-not $onAll) { "absent sur certaines cibles" } else { "$($hashes.Count) variantes" }
    $lines += "TARGET   $name  [$where]  ($why)"
    $nTarget++
  }
}

$header = @(
  "Rapport de classement des exports - $(Get-Date -Format 'yyyy-MM-dd HH:mm')",
  "Cibles : $($Targets -join ' ')",
  "Communs : $nCommon   Specifiques : $nTarget",
  "-------------------------------------------------------------"
)
($header + $lines) | Set-Content $Report -Encoding UTF8
$header + $lines | Write-Host
Write-Host "`nRapport : $Report"
