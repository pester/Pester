function InModuleScope {
    <#
.SYNOPSIS
   Allows you to execute parts of a test script within the
   scope of a PowerShell script module.
.DESCRIPTION
   By injecting some test code into the scope of a PowerShell
   script module, you can use non-exported functions, aliases
   and variables inside that module, to perform unit tests on
   its internal implementation.

   InModuleScope may be used anywhere inside a Pester script,
   either inside or outside a Describe block.
.PARAMETER ModuleName
   The name of the module into which the test code should be
   injected. This module must already be loaded into the current
   PowerShell session.
.PARAMETER ScriptBlock
   The code to be executed within the script module.
.EXAMPLE
    # The script module:
    function PublicFunction
    {
        # Does something
    }

    function PrivateFunction
    {
        return $true
    }

    Export-ModuleMember -Function PublicFunction

    # The test script:

    Import-Module MyModule

    InModuleScope MyModule {
        Describe 'Testing MyModule' {
            It 'Tests the Private function' {
                PrivateFunction | Should -Be $true
            }
        }
    }

    Normally you would not be able to access "PrivateFunction" from
    the PowerShell session, because the module only exported
    "PublicFunction".  Using InModuleScope allowed this call to
    "PrivateFunction" to work successfully.
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ModuleName,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock
    )

    if ($null -eq (& $SafeCommands['Get-Variable'] -Name Pester -ValueOnly -ErrorAction $script:IgnoreErrorPreference)) {
        # User has executed a test script directly instead of calling Invoke-Pester
        $sessionState = Set-SessionStateHint -PassThru -Hint "Caller - Captured in InModuleScope" -SessionState $PSCmdlet.SessionState
        $Pester = New-PesterState -Path (& $SafeCommands['Resolve-Path'] .) -TestNameFilter $null -TagFilter @() -ExcludeTagFilter @() -SessionState $sessionState
        $script:mockTable = @{}
    }

    $module = Get-ScriptModule -ModuleName $ModuleName -ErrorAction Stop

    $originalState = $Pester.SessionState
    $originalScriptBlockScope = Get-ScriptBlockScope -ScriptBlock $ScriptBlock

    try {
        $sessionState = Set-SessionStateHint -PassThru -Hint "Module - $($module.Name)" -SessionState $module.SessionState
        $Pester.SessionState = $sessionState
        Set-ScriptBlockScope -ScriptBlock $ScriptBlock -SessionState $sessionState

        do {
            Write-ScriptBlockInvocationHint -Hint "InModuleScope" -ScriptBlock $ScriptBlock
            & $ScriptBlock
        } until ($true)
    }
    finally {
        $Pester.SessionState = $originalState
        Set-ScriptBlockScope -ScriptBlock $ScriptBlock -SessionStateInternal $originalScriptBlockScope
    }
}

function Get-ScriptModule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ModuleName
    )

    try {
        $modules = @(& $SafeCommands['Get-Module'] -Name $ModuleName -All -ErrorAction Stop)
    }
    catch {
        throw "No module named '$ModuleName' is currently loaded."
    }

    $scriptModules = @($modules | & $SafeCommands['Where-Object'] { $_.ModuleType -eq 'Script' })

    if ($modules.Count -eq 0) {
        throw "No module named '$ModuleName' is currently loaded."
    }

    if ($scriptModules.Count -gt 1) {
        throw "Multiple Script modules named '$ModuleName' are currently loaded.  Make sure to remove any extra copies of the module from your session before testing."
    }

    if ($scriptModules.Count -eq 0) {
        $actualTypes = @(
            $modules |
                & $SafeCommands['Where-Object'] { $_.ModuleType -ne 'Script' } |
                & $SafeCommands['Select-Object'] -ExpandProperty ModuleType -Unique
        )

        $actualTypes = $actualTypes -join ', '

        throw "Module '$ModuleName' is not a Script module.  Detected modules of the following types: '$actualTypes'"
    }

    return $scriptModules[0]
}
