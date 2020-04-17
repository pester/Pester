# $Script:PesterRoot = & $SafeCommands['Split-Path'] -Path $MyInvocation.MyCommand.Path
# "$PesterRoot\functions\*.ps1", "$PesterRoot\functions\Assertions\*.ps1" |
#     & $script:SafeCommands['Resolve-Path'] |
#     & $script:SafeCommands['Where-Object'] { -not ($_.ProviderPath.ToLower().Contains(".tests.")) } |
#     & $script:SafeCommands['ForEach-Object'] { . $_.ProviderPath }


# # sub-modules
# & $script:SafeCommands['Get-ChildItem'] "$PesterRoot\*.psm1" -Exclude "*Pester.psm1" |
#     & $script:SafeCommands['ForEach-Object'] { & $script:SafeCommands['Import-Module'] $_.FullName -DisableNameChecking }

