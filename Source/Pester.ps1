$pwd = Split-Path -Parent $MyInvocation.MyCommand.Path

Resolve-Path $pwd\Functions\*.ps1 | % { . $_.ProviderPath }
 
