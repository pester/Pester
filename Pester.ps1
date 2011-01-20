$pwd = Split-Path -Parent $MyInvocation.MyCommand.Path

Resolve-Path $pwd\Functions\*.ps1 | 
    ? { -not ($_.ProviderPath.Contains(".Tests.")) } |
    % { . $_.ProviderPath }
 
