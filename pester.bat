@echo off
SET DIR=%~dp0%

if '%1'=='/?' goto usage
if '%1'=='-?' goto usage
if '%1'=='?' goto usage
if '%1'=='/help' goto usage
if '%1'=='help' goto usage
if '%1'=='new-fixture' goto newfixture

call "%DIR%runtests.bat"

goto finish
:newfixture
SHIFT
@PowerShell -NonInteractive -NoProfile -ExecutionPolicy unrestricted -Command Import-Module '%DIR%Pester.psm1'; New-Fixture %* 

goto finish
:usage
echo To run pester for tests, just call pester or runtests with no arguments
echo Example: pester
echo To create an auomated test, call pester new-fixture with path and name
echo Example: pester new-fixture [-Path relativePath] -Name nameOfTestFile


:finish
exit /B %errorlevel%