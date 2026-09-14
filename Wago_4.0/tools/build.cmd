@echo off
rem ============================================================
rem  build.cmd <cible>
rem  Reimporte src\common\*.exp + src\targets\<cible>\*.exp dans
rem  pro\wago_<cible>.pro, rebuild complet, sauvegarde, log.
rem  Code retour : 0 = OK, 1 = erreurs de compilation, 2 = usage
rem ============================================================
setlocal enabledelayedexpansion
call "%~dp0config.cmd"
set "T=%~1"
if "%T%"=="" (
  echo usage: build.cmd ^<cible^>   ex: build.cmd 881
  exit /b 2
)

set "PRO=!PRO_DIR!\wago_%T%.pro"
if not exist "!PRO!" (
  echo [%T%] KO : !PRO! introuvable
  exit /b 1
)
set "CDS=!CDS_DIR!\build_%T%.cds"
set "LOG=!LOG_DIR!\build_%T%.log"
del /q "!LOG!" 2>nul

rem --- Sauvegarde du .pro avant import ----------------------------
copy /y "!PRO!" "!BUILD_DIR!\wago_%T%.pro.bak" >nul

rem --- Menage : un .ASD reste apres une fermeture forcee de CoDeSys
rem     et provoque un dialogue de restauration bloquant au lancement.
del /q "!PRO_DIR!\wago_%T%.ASD" 2>nul

rem --- Boot project : supprime avant, pour qu'un build rate n'en laisse
rem     pas un perime a cote d'un .pro qui ne lui correspond plus.
del /q "!PRO_DIR!\wago_%T%.PRG" "!PRO_DIR!\wago_%T%.CHK" 2>nul

rem --- Generation du .cds : un "project import" par fichier ------
rem  onerror continue : sans lui, une erreur de compilation interrompt le
rem  fichier de commandes AVANT "file quit". CoDeSys reste alors ouvert et
rem  le "start /wait" du script ne rend jamais la main.
(
  echo onerror continue
  echo query off
  echo replace yesall
  echo out open "!LOG!"
  echo file open "!PRO!"
  for %%f in ("!SRC_DIR!\common\*.exp")     do echo project import "%%~ff"
  for %%f in ("!SRC_DIR!\targets\%T%\*.exp") do echo project import "%%~ff"
  echo project rebuild
  echo file save
  rem  "online bootproject" hors ligne ecrit wago_X.PRG + .CHK a cote du .pro,
  rem  sans aucun acces automate. Il demande "the code does not match the
  rem  last download, continue?" : query off repond No, query off ok repond
  rem  Yes. Pose ici seulement, apres l'import, pour garder le No sur le
  rem  dialogue Taskconfig.
  echo query off ok
  echo online bootproject
  echo out close
  echo file quit
) > "!CDS!"

echo [%T%] import + rebuild...
cd /d "!ROOT!"
rem  PAS de /batch : cette build WAGO le refuse (voir README, "Si un script bloque").
start "" /wait "!CODESYS_EXE!" /cmd "!CDS!"

rem --- Analyse du log ---------------------------------------------
if not exist "!LOG!" (
  echo [%T%] BUILD KO - aucun log produit. Dialogue bloquant ? Rejouer a la main :
  echo        "!CODESYS_EXE!" /cmd "!CDS!"
  exit /b 1
)
findstr /i /c:"0 Error(s)" /c:"0 Erreur(s)" /c:"0 Fehler" "!LOG!" >nul
if errorlevel 1 (
  echo [%T%] BUILD KO
  echo ---------------- !LOG! ----------------
  findstr /i /c:"Error" /c:"Erreur" /c:"Fehler" "!LOG!"
  echo ------------------------------------------------
  exit /b 1
)
set "SUMMARY="
for /f "tokens=*" %%l in ('findstr /i /c:"Warning(s)" /c:"Avertissement(s)" "!LOG!"') do set "SUMMARY=%%l"
if not exist "!PRO_DIR!\wago_%T%.PRG" (
  echo [%T%] BUILD OK mais BOOT KO - wago_%T%.PRG absent, voir !LOG!
  exit /b 1
)
if not exist "!PRO_DIR!\wago_%T%.CHK" (
  echo [%T%] BUILD OK mais BOOT KO - wago_%T%.CHK absent, voir !LOG!
  exit /b 1
)
echo [%T%] BUILD OK  - !SUMMARY! - boot project wago_%T%.PRG
exit /b 0
