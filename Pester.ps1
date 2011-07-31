$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Resolve-Path $here\Functions\*.ps1 | 
    ? { -not ($_.ProviderPath.Contains(".Tests.")) } |
    % { . $_.ProviderPath }
 
