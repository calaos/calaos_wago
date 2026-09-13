@echo off
rem  open.cmd <cible>  -  ouvre le .pro dans l'IDE (pas de batch), pour
rem  verifier a la main ou debloquer un dialogue.
setlocal enabledelayedexpansion
call "%~dp0config.cmd"
if "%~1"=="" (
  echo usage: open.cmd ^<cible^>
  exit /b 2
)
start "" "!CODESYS_EXE!" "!PRO_DIR!\wago_%~1.pro"
