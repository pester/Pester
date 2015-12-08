@echo off

if '%1'=='/?' goto help
if '%1'=='-help' goto help
if '%1'=='help' goto help
if '%1'=='-h' goto help

"%~dp0vendor\tools\NuGet.exe" install "%~dp0vendor\packages.config" -o "%~dp0vendor\packages"
@SET cmd=$psakeDir = ([array](dir """%~dp0vendor\packages\psake.*"""))[-1]; ".$psakeDir\tools\psake.ps1" build.psake.ps1 %* -ScriptPath "$psakeDir\tools" ; if ($psake.build_success -eq $false) { exit 1 } else { exit 0 }
powershell -NoProfile -ExecutionPolicy Bypass -Command ^ "%cmd%"
goto :eof

:help
@SET cmd=$psakeDir = ([array](dir """%~dp0vendor\packages\psake.*"""))[-1]; ".$psakeDir\tools\psake.ps1 build.psake.ps1" -docs -ScriptPath "$psakeDir\tools"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^ "%cmd%"