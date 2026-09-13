@echo off
rem ============================================================
rem  Configuration commune a tous les scripts Wago_4.0
rem  Appele par : call "%~dp0config.cmd"
rem ============================================================

rem --- Executable WAGO-I/O-PRO (CoDeSys 2.3) -------------------
set "CODESYS_EXE=C:\Program Files (x86)\WAGO Software\CODESYS V2.3\Codesys.exe"
if not exist "%CODESYS_EXE%" set "CODESYS_EXE=C:\Program Files (x86)\3S Software\CoDeSys V2.3\Codesys.exe"
if not exist "%CODESYS_EXE%" set "CODESYS_EXE=C:\Program Files\WAGO Software\CODESYS V2.3\Codesys.exe"

rem --- Liste des cibles (nom = suffixe des fichiers wago_XXX.pro)
set "TARGETS=841 849 880 881 889 891 893"

rem --- Arborescence (calculee depuis le dossier tools\) ----------
for %%i in ("%~dp0..") do set "ROOT=%%~fi"
for %%i in ("%ROOT%\..") do set "REPO=%%~fi"
set "REF_DIR=%REPO%\Wago_3.0"
rem Les .pro restent a la racine de Wago_4.0 : ils referencent ..\Additionnal\
rem (repertoire de bibliotheques relatif, comme dans Wago_3.0).
set "PRO_DIR=%ROOT%"
set "LIB_DIR=%REPO%\Additionnal"
set "SRC_DIR=%ROOT%\src"
set "BUILD_DIR=%ROOT%\build"
set "CDS_DIR=%BUILD_DIR%\cds"
set "EXPORT_DIR=%BUILD_DIR%\export"
set "LOG_DIR=%BUILD_DIR%\logs"

for %%d in ("%CDS_DIR%" "%EXPORT_DIR%" "%LOG_DIR%") do if not exist %%d mkdir %%d
