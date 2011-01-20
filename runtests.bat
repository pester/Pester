@PowerShell Set-ExecutionPolicy Unrestricted
@PowerShell -NonInteractive -NoProfile -Command ".\Pester-Console.ps1" 

@echo off
exit /B %errorlevel%
