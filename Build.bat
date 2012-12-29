@echo off

if '%1'=='/?' goto help
if '%1'=='-help' goto help
if '%1'=='help' goto help
if '%1'=='-h' goto help

%~dp0vendor\tools\nuget.exe Install %~dp0vendor\packages.config -o %~dp0vendor\packages
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$psakeDir = ([array](dir %~dp0Vendor\packages\psake.*))[-1]; .$psakeDir\tools\psake.ps1 build.psake.ps1 %* -ScriptPath $psakeDir\tools ; if ($psake.build_success -eq $false) { exit 1 } else { exit 0 }"
goto :eof

:help
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$psakeDir = ([array](dir %~dp0Vendor\packages\psake.*))[-1]; .$psakeDir\tools\psake.ps1 build.psake.ps1 -docs -ScriptPath $psakeDir\tools"
