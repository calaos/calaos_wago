@echo off
rem ============================================================
rem  bootstrap.cmd  -  A lancer UNE FOIS pour initialiser Wago_4.0
rem   1. copie les .pro de Wago_3.0 vers Wago_4.0\ (racine, pour ..\Additionnal)
rem   2. exporte chaque cible en .exp
rem   3. classe les .exp dans src\common et src\targets\<cible>
rem ============================================================
setlocal enabledelayedexpansion
call "%~dp0config.cmd"

call "%~dp0check_env.cmd" || (echo Corriger l'environnement puis relancer. & exit /b 1)

echo.
echo === 1/3 Copie des .pro de reference ===
for %%t in (%TARGETS%) do (
  copy /y "!REF_DIR!\wago_%%t.pro" "!PRO_DIR!\wago_%%t.pro" >nul && echo    wago_%%t.pro
)

echo.
echo === 2/3 Export de toutes les cibles ===
call "%~dp0export_all.cmd" || exit /b 1

echo.
echo === 3/3 Classement common / targets ===
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sort_exports.ps1" -Clean || exit /b 1

echo.
echo BOOTSTRAP OK.
echo Prochaine etape : git add *.pro src tools CLAUDE.md ^&^& git commit
echo Puis valider le cycle complet sans modification :  tools\build_all.cmd
exit /b 0
