@echo off
rem ============================================================
rem  export.cmd <cible>
rem  Exporte pro\wago_<cible>.pro en fichiers .exp (un par objet)
rem  dans build\export\<cible>\
rem ============================================================
setlocal enabledelayedexpansion
call "%~dp0config.cmd"
set "T=%~1"
if "%T%"=="" (
  echo usage: export.cmd ^<cible^>   ex: export.cmd 881
  exit /b 2
)

set "PRO=!PRO_DIR!\wago_%T%.pro"
if not exist "!PRO!" (
  echo [%T%] KO : !PRO! introuvable
  exit /b 1
)

set "OUT=!EXPORT_DIR!\%T%"
if exist "!OUT!" rd /s /q "!OUT!"
mkdir "!OUT!"
set "CDS=!CDS_DIR!\export_%T%.cds"
set "LOG=!LOG_DIR!\export_%T%.log"
del /q "!LOG!" 2>nul

rem --- Generation du fichier de commandes CoDeSys ---------------
(
  echo query off
  echo replace yesall
  echo out open "!LOG!"
  echo file open "!PRO!"
  echo project expmul "!OUT!"
  echo out close
  echo file quit
) > "!CDS!"

echo [%T%] export en cours...
cd /d "!ROOT!"
rem  PAS de /batch : cette build WAGO le refuse (voir README, "Si un script bloque").
start "" /wait "!CODESYS_EXE!" /cmd "!CDS!"

rem --- Repli si expmul n'a rien produit ---------------------------
rem  find /i obligatoire : CoDeSys ecrit les noms en MAJUSCULES (*.EXP).
set "N=0"
for /f %%n in ('dir /b "!OUT!\*.exp" 2^>nul ^| find /c /i ".exp"') do set "N=%%n"
if "!N!"=="0" (
  echo [%T%] expmul n'a rien produit, repli sur un export monofichier.
  (
    echo query off
    echo replace yesall
    echo out open "!LOG!"
    echo file open "!PRO!"
    echo project export "!OUT!\wago_%T%_all.exp"
    echo out close
    echo file quit
  ) > "!CDS!"
  start "" /wait "!CODESYS_EXE!" /cmd "!CDS!"
  for /f %%n in ('dir /b "!OUT!\*.exp" 2^>nul ^| find /c /i ".exp"') do set "N=%%n"
)

if "!N!"=="0" (
  echo [%T%] EXPORT KO - voir !LOG!
  echo        Rejouer la commande a la main pour voir le dialogue bloquant :
  echo        "!CODESYS_EXE!" /cmd "!CDS!"
  exit /b 1
)
echo [%T%] EXPORT OK - !N! fichier^(s^) dans !OUT!
exit /b 0
