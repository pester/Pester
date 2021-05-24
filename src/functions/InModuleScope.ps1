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
.PARAMETER Parameters
   A optional hashtable of parameters to be passed to the scriptblock.
.PARAMETER ArgumentList
   A optional list of arguments to be passed to the scriptblock.
.EXAMPLE
    ```powershell
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
    ```

    Normally you would not be able to access "PrivateFunction" from
    the PowerShell session, because the module only exported
    "PublicFunction".  Using InModuleScope allowed this call to
    "PrivateFunction" to work successfully.

.LINK
    https://pester.dev/docs/commands/InModuleScope
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ModuleName,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [HashTable]
        $Parameters = @{},

        $ArgumentList = @()
    )

    $module = Get-ScriptModule -ModuleName $ModuleName -ErrorAction Stop
    $sessionState = Set-SessionStateHint -PassThru -Hint "Module - $($module.Name)" -SessionState $module.SessionState

    $wrapper = {
        param ($private:______inmodule_parameters)

        # This script block is used to create variables for provided parameters that
        # the real scriptblock can inherit. Makes defining a param-block optional.

        foreach ($private:______current in $private:______inmodule_parameters.Parameters.GetEnumerator()) {
            $private:______inmodule_parameters.SessionState.PSVariable.Set($private:______current.Key, $private:______current.Value)
        }

        # Splatting expressions isn't allowed. Assigning to new private variable
        $private:______arguments = $private:______inmodule_parameters.ArgumentList
        $private:______parameters = $private:______inmodule_parameters.Parameters

        if ($private:______parameters.Count -gt 0) {
            & $private:______inmodule_parameters.ScriptBlock @private:______parameters @private:______arguments
        }
        else {
            # Not splatting parameters to avoid polluting args
            & $private:______inmodule_parameters.ScriptBlock @private:______arguments
        }
    }

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        $hasParams = 0 -lt $Parameters.Count
        $hasArgs = 0 -lt $ArgumentList.Count
        $arguments = $($(if ($hasArgs) { foreach ($a in $ArgumentList) { "'$($a)'" } }) -join ", ")
        $params = $(if ($hasParams) { foreach ($p in $Parameters.GetEnumerator()) { "$($p.Key) = $($p.Value)" } }) -join ", "
        Write-PesterDebugMessage -Scope Runtime -Message "Running scriptblock { $scriptBlock } in module $($ModuleName)$(if ($hasParams) { " with parameters: $params" })$(if ($hasArgs) { "$(if ($hasParams) { ' and' }) with arguments: $arguments" })."
    }

    Set-ScriptBlockScope -ScriptBlock $ScriptBlock -SessionState $sessionState
    Set-ScriptBlockScope -ScriptBlock $wrapper -SessionState $sessionState
    $splat = @{
        ScriptBlock    = $ScriptBlock
        Parameters     = $Parameters
        ArgumentList   = $ArgumentList
        SessionState   = $sessionState
    }

    Write-ScriptBlockInvocationHint -Hint "InModuleScope" -ScriptBlock $ScriptBlock
    & $wrapper $splat
}

function Get-ScriptModule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ModuleName
    )

    try {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Runtime "Searching for a module $ModuleName."
        }
        $modules = @(& $SafeCommands['Get-Module'] -Name $ModuleName -All -ErrorAction Stop)
    }
    catch {
        throw "No modules named '$ModuleName' are currently loaded."
    }

    if ($modules.Count -eq 0) {
        throw "No modules named '$ModuleName' are currently loaded."
    }

    $scriptModules = @($modules | & $SafeCommands['Where-Object'] { $_.ModuleType -eq 'Script' })
    if ($scriptModules.Count -gt 1) {
        throw "Multiple script modules named '$ModuleName' are currently loaded.  Make sure to remove any extra copies of the module from your session before testing."
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
    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Runtime "Found module $ModuleName version $($scriptModules[0].Version)."
    }
    return $scriptModules[0]
}
