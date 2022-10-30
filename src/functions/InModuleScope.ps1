function InModuleScope {
    <#
    .SYNOPSIS
    Allows you to execute parts of a test script within the
    scope of a PowerShell script or manifest module.
    .DESCRIPTION
    By injecting some test code into the scope of a PowerShell
    script or manifest module, you can use non-exported functions, aliases
    and variables inside that module, to perform unit tests on
    its internal implementation.

    InModuleScope may be used anywhere inside a Pester script,
    either inside or outside a Describe block.
    .PARAMETER ModuleName
    The name of the module into which the test code should be
    injected. This module must already be loaded into the current
    PowerShell session.
    .PARAMETER ScriptBlock
    The code to be executed within the script or manifest module.
    .PARAMETER Parameters
    A optional hashtable of parameters to be passed to the scriptblock.
    Parameters are automatically made available as variables in the scriptblock.
    .PARAMETER ArgumentList
    A optional list of arguments to be passed to the scriptblock.

    .EXAMPLE
    ```powershell
    # The script module:
    function PublicFunction {
        # Does something
    }

    function PrivateFunction {
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

    .EXAMPLE
    ```powershell
    # The script module:
    function PublicFunction {
        # Does something
    }

    function PrivateFunction ($MyParam) {
        return $MyParam
    }

    Export-ModuleMember -Function PublicFunction

    # The test script:

    Describe 'Testing MyModule' {
        BeforeAll {
            Import-Module MyModule
        }

        It 'passing in parameter' {
            $SomeVar = 123
            InModuleScope 'MyModule' -Parameters @{ MyVar = $SomeVar } {
                $MyVar | Should -Be 123
            }
        }

        It 'accessing whole testcase in module scope' -TestCases @(
            @{ Name = 'Foo'; Bool = $true }
        ) {
            # Passes the whole testcase-dictionary available in $_ to InModuleScope
            InModuleScope 'MyModule' -Parameters $_ {
                $Name | Should -Be 'Foo'
                PrivateFunction -MyParam $Bool | Should -BeTrue
            }
        }
    }
    ```

    This example shows two ways of using `-Parameters` to pass variables created in a
    testfile into the module scope where the scriptblock provided to InModuleScope is executed.
    No variables from the outside are available inside the scriptblock without explicitly passing
    them in using `-Parameters` or `-ArgumentList`.

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

        [object[]]
        $ArgumentList = @()
    )

    $module = Get-CompatibleModule -ModuleName $ModuleName -ErrorAction Stop
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
            & $private:______inmodule_parameters.ScriptBlock @private:______arguments @private:______parameters
        }
        else {
            # Not splatting parameters to avoid polluting args
            & $private:______inmodule_parameters.ScriptBlock @private:______arguments
        }
    }

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        $hasParams = 0 -lt $Parameters.Count
        $hasArgs = 0 -lt $ArgumentList.Count
        $inmoduleArguments = $($(if ($hasArgs) { foreach ($a in $ArgumentList) { "'$($a)'" } }) -join ", ")
        $inmoduleParameters = $(if ($hasParams) { foreach ($p in $Parameters.GetEnumerator()) { "$($p.Key) = $($p.Value)" } }) -join ", "
        Write-PesterDebugMessage -Scope Runtime -Message "Running scriptblock { $scriptBlock } in module $($ModuleName)$(if ($hasParams) { " with parameters: $inmoduleParameters" })$(if ($hasArgs) { "$(if ($hasParams) { ' and' }) with arguments: $inmoduleArguments" })."
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

function Get-CompatibleModule {
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

    $compatibleModules = @($modules | & $SafeCommands['Where-Object'] { $_.ModuleType -in 'Script', 'Manifest' })
    if ($compatibleModules.Count -gt 1) {
        throw "Multiple script or manifest modules named '$ModuleName' are currently loaded. Make sure to remove any extra copies of the module from your session before testing."
    }

    if ($compatibleModules.Count -eq 0) {
        $actualTypes = @(
            $modules |
                & $SafeCommands['Where-Object'] { $_.ModuleType -notin 'Script', 'Manifest' } |
                & $SafeCommands['Select-Object'] -ExpandProperty ModuleType -Unique
        )

        $actualTypes = $actualTypes -join ', '

        throw "Module '$ModuleName' is not a Script or Manifest module. Detected modules of the following types: '$actualTypes'"
    }
    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Runtime "Found module $ModuleName version $($compatibleModules[0].Version)."
    }
    return $compatibleModules[0]
}
