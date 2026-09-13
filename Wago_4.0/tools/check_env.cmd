@echo off
rem ============================================================
rem  Verifie que l'environnement est pret avant tout batch.
rem  NB : expansion retardee obligatoire, les chemins contiennent "(x86)"
rem ============================================================
setlocal enabledelayedexpansion
call "%~dp0config.cmd"
set ERR=0
set "PF86=%ProgramFiles(x86)%"

echo [1/4] Executable CoDeSys
if exist "!CODESYS_EXE!" (
  echo    OK  !CODESYS_EXE!
) else (
  echo    KO  Codesys.exe introuvable, editer tools\config.cmd
  set ERR=1
)

echo [2/4] Projets de reference Wago_3.0
for %%t in (%TARGETS%) do (
  if exist "!REF_DIR!\wago_%%t.pro" (
    echo    OK  wago_%%t.pro
  ) else (
    echo    KO  !REF_DIR!\wago_%%t.pro
    set ERR=1
  )
)

echo [3/4] Bibliotheques projet ^(..\Additionnal relatif au .pro^)
if exist "!LIB_DIR!\DALI_647_02_v2.3.lib" (
  echo    OK  !LIB_DIR!
) else (
  echo    KO  !LIB_DIR! introuvable. Wago_4.0 doit etre un sous-dossier direct
  echo        du depot, au meme niveau que Wago_3.0 et Additionnal.
  set ERR=1
)

echo [4/4] Cibles WAGO installees dans CoDeSys
for %%t in (%TARGETS%) do (
  set "FOUND="
  for /f "delims=" %%f in ('dir /b /s "!PF86!\WAGO Software\CODESYS V2.3\Targets\WAGO\*%%t*.trg" 2^>nul') do set "FOUND=%%f"
  if defined FOUND (
    echo    OK  target 750-%%t
  ) else (
    echo    ??  target 750-%%t non trouve - a verifier a la main dans Target Settings
  )
)

echo.
if !ERR!==0 (
  echo ENV OK
) else (
  echo ENV KO - corriger les points ci-dessus
)
exit /b !ERR!
