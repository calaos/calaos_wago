@echo off
rem  Exporte toutes les cibles (voir tools\config.cmd pour la liste)
setlocal
call "%~dp0config.cmd"
set FAIL=0
for %%t in (%TARGETS%) do (
  call "%~dp0export.cmd" %%t || set FAIL=1
)
if %FAIL%==1 (echo EXPORT_ALL : au moins une cible en echec & exit /b 1)
echo EXPORT_ALL OK
exit /b 0
