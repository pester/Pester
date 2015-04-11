function InModuleScope
{
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
                PrivateFunction | Should Be $true
            }
        }
    }

    Normally you would not be able to access "PrivateFunction" from
    the powershell session, because the module only exported
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

    if ($null -eq (Get-Variable -Name Pester -ValueOnly -ErrorAction $script:IgnoreErrorPreference))
    {
        # User has executed a test script directly instead of calling Invoke-Pester
        $Pester = New-PesterState -Path (Resolve-Path .) -TestNameFilter $null -TagFilter @() -ExcludeTagFilter @() -SessionState $PSCmdlet.SessionState
        $script:mockTable = @{}
    }

    $module = Get-ScriptModule -ModuleName $ModuleName -ErrorAction Stop

    $originalState = $Pester.SessionState
    $originalScriptBlockScope = Get-ScriptBlockScope -ScriptBlock $ScriptBlock

    try
    {
        $Pester.SessionState = $module.SessionState

        Set-ScriptBlockScope -ScriptBlock $ScriptBlock -SessionState $module.SessionState

        do
        {
            & $ScriptBlock
        } until ($true)
    }
    finally
    {
        $Pester.SessionState = $originalState
        Set-ScriptBlockScope -ScriptBlock $ScriptBlock -SessionStateInternal $originalScriptBlockScope
    }
}

function Get-ScriptModule
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ModuleName
    )

    try
    {
        $modules = @(Get-Module -Name $ModuleName -All -ErrorAction Stop)
    }
    catch
    {
        throw "No module named '$ModuleName' is currently loaded."
    }

    $scriptModules = @($modules | Where-Object { $_.ModuleType -eq 'Script' })

    if ($scriptModules.Count -gt 1)
    {
        throw "Multiple Script modules named '$ModuleName' are currently loaded.  Make sure to remove any extra copies of the module from your session before testing."
    }

    if ($scriptModules.Count -eq 0)
    {
        $actualTypes = @(
            $modules |
            Where-Object { $_.ModuleType -ne 'Script' } |
            Select-Object -ExpandProperty ModuleType -Unique
        )

        $actualTypes = $actualTypes -join ', '

        throw "Module '$ModuleName' is not a Script module.  Detected modules of the following types: '$actualTypes'"
    }

    return $scriptModules[0]
}
