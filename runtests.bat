@PowerShell Set-ExecutionPolicy RemoteSigned
@PowerShell -NonInteractive -NoProfile -Command Import-Module .\Pester.psm1; Invoke-Pester 

@echo off
exit /B %errorlevel%
