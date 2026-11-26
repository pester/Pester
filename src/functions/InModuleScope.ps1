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
    BeforeAll {
        Import-Module MyModule
    }

    Describe 'Testing MyModule' {
        It 'Tests the Private function' {
            InModuleScope MyModule {
                PrivateFunction | Should -Be $true
            }
        }
    }
    ```

    Normally you would not be able to access "PrivateFunction" from
    the PowerShell session, because the module only exported
    "PublicFunction". Using InModuleScope allowed this call to
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
        ScriptBlock  = $ScriptBlock
        Parameters   = $Parameters
        ArgumentList = $ArgumentList
        SessionState = $sessionState
    }

    Write-ScriptBlockInvocationHint -Hint "InModuleScope" -ScriptBlock $ScriptBlock
    # Mark that we are executing inside this module so Mock / Should -Invoke calls made directly in
    # the scriptblock know to (intentionally) target the module instead of the test/script scope.
    Push-InModuleScopeModule -ModuleName $module.Name
    try {
        & $wrapper $splat
    }
    finally {
        Pop-InModuleScopeModule
    }
}

function Get-CompatibleModule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ModuleName
    )

    # Slash/backslash notation: RootModule/NestedModule[/DeeperNestedModule...]
    # Resolves the full nested path from left to right so deeply nested modules can be targeted.
    if ($ModuleName -match '[/\\]') {
        # Split on / or \ and trim whitespace from each segment.
        $modulePathSegments = @($ModuleName -split '[/\\]')
        $modulePathSegments = @($modulePathSegments | & $SafeCommands['ForEach-Object'] { $_.Trim() })
        $hasEmptySegment = @($modulePathSegments | & $SafeCommands['Where-Object'] { [string]::IsNullOrEmpty($_) }).Count -gt 0

        # Require at least two non-empty segments (root + one nested level).
        if ($modulePathSegments.Count -lt 2 -or $hasEmptySegment) {
            throw "Invalid ModuleName format '$ModuleName'. Expected format: 'RootModuleName/NestedModuleName[/DeeperNestedModuleName...]'."
        }

        # Seed the search with all copies of the root module (Get-Module -All covers reimports).
        $rootModuleName = $modulePathSegments[0]
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Runtime "Nested path notation detected in ModuleName '$ModuleName'. Resolving from root module '$rootModuleName'."
        }

        $currentModules = @(& $SafeCommands['Get-Module'] -Name $rootModuleName -All -ErrorAction SilentlyContinue)
        if ($currentModules.Count -eq 0) {
            throw "No modules named '$rootModuleName' are currently loaded."
        }

        # Walk each path segment after the root, narrowing $currentModules to the matched nested module at each level.
        $resolvedPath = $rootModuleName
        for ($index = 1; $index -lt $modulePathSegments.Count; $index++) {
            $nestedModuleName = $modulePathSegments[$index]
            $nextModules = [System.Collections.Generic.List[object]]@()      # matches for this segment
            $availableNested = [System.Collections.Generic.List[string]]@()  # all sibling names, for error messages

            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Runtime "Resolving nested module segment '$nestedModuleName' under '$resolvedPath'."
            }

            # Scan NestedModules of every candidate at the current level.
            foreach ($parentModule in $currentModules) {
                foreach ($nestedModule in @($parentModule.NestedModules)) {
                    # Collect unique sibling names so the error message can list available options.
                    if (-not [string]::IsNullOrEmpty($nestedModule.Name) -and -not $availableNested.Contains($nestedModule.Name)) {
                        $availableNested.Add($nestedModule.Name)
                    }

                    if ($nestedModule.Name -eq $nestedModuleName) {
                        $nextModules.Add($nestedModule)
                    }
                }
            }

            # No match: segment name is wrong or the nested module is not loaded.
            if ($nextModules.Count -eq 0) {
                $availableList = if ($availableNested.Count -gt 0) { $availableNested -join ', ' } else { '(none)' }
                throw "No nested module named '$nestedModuleName' was found under '$resolvedPath'. Available nested modules: $availableList."
            }

            # More than one match: ambiguous — multiple loaded copies of the same module exist.
            if ($nextModules.Count -gt 1) {
                throw "Multiple nested modules named '$nestedModuleName' were found under '$resolvedPath' across loaded module copies. Make sure to remove any extra copies of the module from your session before testing."
            }

            $resolvedNested = $nextModules[0]
            # Only Script/Manifest modules expose a usable session state for InModuleScope.
            if ($resolvedNested.ModuleType -notin 'Script', 'Manifest') {
                throw "Nested module '$nestedModuleName' in path '$resolvedPath/$nestedModuleName' is not a Script or Manifest module. Detected module type: '$($resolvedNested.ModuleType)'."
            }

            # Narrow to the single resolved module and advance the path tracker for the next iteration.
            $currentModules = @($resolvedNested)
            $resolvedPath = "$resolvedPath/$nestedModuleName"
        }

        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Runtime "Found nested module $($currentModules[0].Name) version $($currentModules[0].Version) in path $resolvedPath."
        }

        return $currentModules[0]
    }

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
