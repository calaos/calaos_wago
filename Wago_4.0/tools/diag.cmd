@echo off
rem ============================================================
rem  diag.cmd <cible>
rem  Diagnostic du pilotage de CoDeSys en ligne de commande.
rem  Lance CoDeSys SANS /batch (fenetre visible) sur un .cds
rem  minimal, puis liste ce qui a ete produit.
rem ============================================================
setlocal enabledelayedexpansion
call "%~dp0config.cmd"
set "T=%~1"
if "%T%"=="" set "T=881"

set "PRO=!PRO_DIR!\wago_%T%.pro"
set "OUT=!EXPORT_DIR!\diag_%T%"
set "CDS=!CDS_DIR!\diag_%T%.cds"
set "LOG=!LOG_DIR!\diag_%T%.log"

echo === diag.cmd %T% ===
echo CODESYS_EXE = !CODESYS_EXE!
if not exist "!CODESYS_EXE!" (
  echo KO : executable introuvable
  exit /b 1
)
echo PRO         = !PRO!
if not exist "!PRO!" (
  echo KO : projet introuvable
  exit /b 1
)

if exist "!OUT!" rd /s /q "!OUT!"
mkdir "!OUT!"
del /q "!LOG!" 2>nul

rem --- .cds minimal, sans guillemets ---------------------------
(
  echo echo on
  echo query off
  echo replace yesall
  echo out open !LOG!
  echo file open !PRO!
  echo project expmul !OUT!
  echo out close
  echo file quit
) > "!CDS!"

echo.
echo ---------------- !CDS! ----------------
type "!CDS!"
echo ---------------------------------------
echo.
echo Commande : "!CODESYS_EXE!" /cmd "!CDS!"
echo (sans /batch : la fenetre CoDeSys doit apparaitre)
echo.

cd /d "!ROOT!"
start "" /wait "!CODESYS_EXE!" /cmd "!CDS!"
echo CoDeSys a rendu la main (errorlevel=!errorlevel!^)
echo.

echo ---------------- resultat ----------------
if exist "!LOG!" (
  echo LOG present : !LOG!
  type "!LOG!"
) else (
  echo LOG ABSENT : !LOG!
)
echo.
set "N=0"
for /f %%n in ('dir /b "!OUT!\*.exp" 2^>nul ^| find /c /i ".exp"') do set "N=%%n"
echo fichiers .exp dans !OUT! : !N!
if not "!N!"=="0" dir /b "!OUT!"
echo ------------------------------------------
exit /b 0
