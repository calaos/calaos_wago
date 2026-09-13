@echo off
rem  Rebuild de toutes les cibles. S'arrete a la premiere qui echoue
rem  sauf si on passe --keep-going.
setlocal
call "%~dp0config.cmd"
set FAIL=0
for %%t in (%TARGETS%) do (
  call "%~dp0build.cmd" %%t
  if errorlevel 1 (
    set FAIL=1
    if not "%~1"=="--keep-going" (echo BUILD_ALL : arret sur la cible %%t & exit /b 1)
  )
)
if %FAIL%==1 (echo BUILD_ALL : au moins une cible en echec & exit /b 1)
echo BUILD_ALL OK - %TARGETS%
exit /b 0
