@echo off
SET DIR=%~dp0%
@echo on

::@PowerShell Set-ExecutionPolicy RemoteSigned
@PowerShell -NonInteractive -NoProfile -ExecutionPolicy unrestricted -Command "& Import-Module '%DIR%Pester.psm1'; & { Invoke-Pester; exit $LastExitCode}"

@echo off
exit /B %errorlevel%
