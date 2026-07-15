function Assert-ValidAssertionName {
    param([string]$Name)
    if ($Name -notmatch '^\S+$') {
        throw "Assertion name '$name' is invalid, assertion name must be a single word."
    }
}

function Assert-ValidAssertionAlias {
    param([string[]]$Alias)
    if ($Alias -notmatch '^\S+$') {
        throw "Assertion alias '$string' is invalid, assertion alias must be a single word."
    }
}

function Add-ShouldOperator {
    <#
    .SYNOPSIS
    Register a Should Operator with Pester
    .DESCRIPTION
    This function allows you to create custom Should assertions.
    .PARAMETER Name
    The name of the assertion. This will become a Named Parameter of Should.
    .PARAMETER Test
    The test function. The function must return a PSObject with a [Bool]succeeded and a [string]failureMessage property.
    .PARAMETER Alias
    A list of aliases for the Named Parameter.
    .PARAMETER SupportsArrayInput
    Does the test function support the passing an array of values to test.
    .PARAMETER InternalName
    If -Name is different from the actual function name, record the actual function name here.
    Used by Get-ShouldOperator to pull function help.
    .EXAMPLE
    ```powershell
    function BeAwesome($ActualValue, [switch] $Negate) {
        [bool] $succeeded = $ActualValue -eq 'Awesome'
        if ($Negate) { $succeeded = -not $succeeded }

        if (-not $succeeded) {
            if ($Negate) {
                $failureMessage = "{$ActualValue} is Awesome"
            }
            else {
                $failureMessage = "{$ActualValue} is not Awesome"
            }
        }

        return [PSCustomObject]@{
            Succeeded      = $succeeded
            FailureMessage = $failureMessage
        }
    }

    Add-ShouldOperator -Name BeAwesome `
        -Test $function:BeAwesome `
        -Alias 'BA'

    PS C:\> "bad" | Should -BeAwesome
    {bad} is not Awesome
    ```

    Example of how to create a simple custom assertion that checks if the input string is 'Awesome'
    .LINK
    https://pester.dev/docs/commands/Add-ShouldOperator
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [scriptblock] $Test,

        [ValidateNotNullOrEmpty()]
        [AllowEmptyCollection()]
        [string[]] $Alias = @(),

        [Parameter()]
        [string] $InternalName,

        [switch] $SupportsArrayInput
    )

    Assert-BoundScriptBlockInput -ScriptBlock $Test

    $entry = [PSCustomObject]@{
        Test               = $Test
        SupportsArrayInput = [bool]$SupportsArrayInput
        Name               = $Name
        Alias              = $Alias
        InternalName       = If ($InternalName) { $InternalName } else { $Name }
    }
    if (Test-AssertionOperatorIsDuplicate -Operator $entry) {
        # This is an exact duplicate of an existing assertion operator.
        return
    }

    # https://github.com/pester/Pester/issues/1355 and https://github.com/PowerShell/PowerShell/issues/9372
    if ($script:AssertionOperators.Count -ge 32) {
        throw 'Max number of assertion operators (32) has already been reached. This limitation is due to maximum allowed parameter sets in PowerShell.'
    }

    $namesToCheck = @(
        $Name
        $Alias
    )

    Assert-AssertionOperatorNameIsUnique -Name $namesToCheck

    $script:AssertionOperators[$Name] = $entry

    foreach ($string in $Alias | & $SafeCommands['Where-Object'] { -not ([string]::IsNullOrWhiteSpace($_)) }) {
        Assert-ValidAssertionAlias -Alias $string
        $script:AssertionAliases[$string] = $Name
    }

    Add-AssertionDynamicParameterSet -AssertionEntry $entry
}

function Set-ShouldOperatorHelpMessage {
    <#
    .SYNOPSIS
    Sets the helpmessage for a Should-operator. Used in Should's online help for the switch-parameter.
    .PARAMETER OperatorName
    The name of the assertion/operator.
    .PARAMETER HelpMessage
    Help message for switch-parameter for the operator in Should.
    .NOTES
    Internal function as it's only useful for built-in Should operators/assertion atm. to improve online docs.
    Can be merged into Add-ShouldOperator later if we'd like to make it public and include value in Get-ShouldOperator

    https://github.com/pester/Pester/issues/2335
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $OperatorName,
        [Parameter(Mandatory = $true, Position = 1)]
        [string] $HelpMessage
    )

    end {
        $OperatorParam = $script:AssertionDynamicParams[$OperatorName]

        if ($null -eq $OperatorParam) {
            throw "Should operator '$OperatorName' is not registered"
        }

        foreach ($attr in $OperatorParam.Attributes) {
            if ($attr -is [System.Management.Automation.ParameterAttribute]) {
                $attr.HelpMessage = $HelpMessage
            }
        }
    }
}

function Test-AssertionOperatorIsDuplicate {
    param (
        [psobject] $Operator
    )

    $existing = $script:AssertionOperators[$Operator.Name]
    if (-not $existing) {
        return $false
    }

    return $Operator.SupportsArrayInput -eq $existing.SupportsArrayInput -and
    $Operator.Test.ToString() -eq $existing.Test.ToString() -and
    -not (& $SafeCommands['Compare-Object'] $Operator.Alias $existing.Alias)
}
function Assert-AssertionOperatorNameIsUnique {
    param (
        [string[]] $Name
    )

    foreach ($string in $name | & $SafeCommands['Where-Object'] { -not ([string]::IsNullOrWhiteSpace($_)) }) {
        Assert-ValidAssertionName -Name $string

        if ($script:AssertionOperators.ContainsKey($string)) {
            throw "Assertion operator name '$string' has been added multiple times."
        }

        if ($script:AssertionAliases.ContainsKey($string)) {
            throw "Assertion operator name '$string' already exists as an alias for operator '$($script:AssertionAliases[$key])'"
        }
    }
}

function Add-AssertionDynamicParameterSet {
    param (
        [object] $AssertionEntry
    )

    ${function:__AssertionTest__} = $AssertionEntry.Test
    $commandInfo = & $SafeCommands['Get-Command'] __AssertionTest__ -CommandType Function
    $metadata = [System.Management.Automation.CommandMetadata]$commandInfo

    $attribute = [Management.Automation.ParameterAttribute]::new()
    $attribute.ParameterSetName = $AssertionEntry.Name


    $attributeCollection = [Collections.ObjectModel.Collection[Attribute]]::new()
    $null = $attributeCollection.Add($attribute)
    if (-not ([string]::IsNullOrWhiteSpace($AssertionEntry.Alias))) {
        Assert-ValidAssertionAlias -Alias $AssertionEntry.Alias
        $attribute = [System.Management.Automation.AliasAttribute]::new($AssertionEntry.Alias)
        $attributeCollection.Add($attribute)
    }

    # Register assertion
    $dynamic = [System.Management.Automation.RuntimeDefinedParameter]::new($AssertionEntry.Name, [switch], $attributeCollection)
    $null = $script:AssertionDynamicParams.Add($AssertionEntry.Name, $dynamic)

    # Register -Not in the assertion's parameter set. Create parameter if not already present (first assertion).
    if ($script:AssertionDynamicParams.ContainsKey('Not')) {
        $dynamic = $script:AssertionDynamicParams['Not']
    }
    else {
        $dynamic = [System.Management.Automation.RuntimeDefinedParameter]::new('Not', [switch], ([System.Collections.ObjectModel.Collection[Attribute]]::new()))
        $null = $script:AssertionDynamicParams.Add('Not', $dynamic)
    }

    $attribute = [System.Management.Automation.ParameterAttribute]::new()
    $attribute.ParameterSetName = $AssertionEntry.Name
    $attribute.Mandatory = $false
    $attribute.HelpMessage = 'Reverse the assertion'
    $null = $dynamic.Attributes.Add($attribute)

    # Register required parameters in the assertion's parameter set. Create parameter if not already present.
    $i = 1
    foreach ($parameter in $metadata.Parameters.Values) {
        # common parameters that are already defined
        if ($parameter.Name -eq 'ActualValue' -or $parameter.Name -eq 'Not' -or $parameter.Name -eq 'Negate') {
            continue
        }


        if ($script:AssertionOperators.ContainsKey($parameter.Name) -or $script:AssertionAliases.ContainsKey($parameter.Name)) {
            throw "Test block for assertion operator $($AssertionEntry.Name) contains a parameter named $($parameter.Name), which conflicts with another assertion operator's name or alias."
        }

        foreach ($alias in $parameter.Aliases) {
            if ($script:AssertionOperators.ContainsKey($alias) -or $script:AssertionAliases.ContainsKey($alias)) {
                throw "Test block for assertion operator $($AssertionEntry.Name) contains a parameter named $($parameter.Name) with alias $alias, which conflicts with another assertion operator's name or alias."
            }
        }

        if ($script:AssertionDynamicParams.ContainsKey($parameter.Name)) {
            $dynamic = $script:AssertionDynamicParams[$parameter.Name]
        }
        else {
            # We deliberately use a type of [object] here to avoid conflicts between different assertion operators that may use the same parameter name.
            # We also don't bother to try to copy transformation / validation attributes here for the same reason.
            # Because we'll be passing these parameters on to the actual test function later, any errors will come out at that time.

            # few years later: using [object] causes problems with switch params (in my case -PassThru), because then we cannot use them without defining a value
            # so for switches we must prefer the conflicts over type
            if ([switch] -eq $parameter.ParameterType) {
                $type = [switch]
            }
            else {
                $type = [object]
            }

            $dynamic = [System.Management.Automation.RuntimeDefinedParameter]::new($parameter.Name, $type, ([System.Collections.ObjectModel.Collection[Attribute]]::new()))
            $null = $script:AssertionDynamicParams.Add($parameter.Name, $dynamic)
        }

        $attribute = [Management.Automation.ParameterAttribute]::new()
        $attribute.ParameterSetName = $AssertionEntry.Name
        $attribute.Mandatory = $false
        $attribute.Position = ($i++)
        # Only visible in command reference on https://pester.dev. Remove if/when migrated to external help (markdown as source).
        $attribute.HelpMessage = 'Depends on operator being used. See `Get-ShouldOperator -Name <Operator>` or https://pester.dev/docs/assertions/ for help.'

        $null = $dynamic.Attributes.Add($attribute)
    }
}

function Get-AssertionOperatorEntry([string] $Name) {
    return $script:AssertionOperators[$Name]
}

function Get-AssertionDynamicParams {
    return $script:AssertionDynamicParams
}

function Invoke-Pester {
    <#
    .SYNOPSIS
    Runs Pester tests

    .DESCRIPTION
    The Invoke-Pester function runs Pester tests, including *.Tests.ps1 files and
    Pester tests in PowerShell scripts.

    You can run scripts that include Pester tests just as you would any other
    PowerShell script, including typing the full path at the command line
    and running in a script editing program. Typically, you use Invoke-Pester to run
    all Pester tests in a directory, or to use its many helpful parameters,
    including parameters that generate custom objects or test result files.

    By default, Invoke-Pester runs all *.Tests.ps1 files in the current directory
    and all subdirectories recursively. You can use its parameters to select tests
    by file name, test name, or tag.

    To run parameterized tests, or to mix files and script blocks, use
    New-PesterContainer or the Configuration parameter.

    By default, Pester tests write test results to the console host, much like
    Write-Host does, but you can use the Output parameter with value None to suppress
    host messages, use the PassThru parameter to generate a [Pester.Run] object that
    contains the test results, or use the Configuration parameter to write test results
    or code coverage output to files.

    For build systems, use the CI parameter to enable test result output and fail the
    process when tests fail.

    Invoke-Pester, and the Pester module that exports it, are products of an
    open-source project hosted on GitHub. To view, comment, or contribute to the
    repository, see https://github.com/Pester.

    .PARAMETER CI
    Enable Test Results and Exit after Run.

    Equivalent to setting:
        TestResult.Enabled = $true
        Run.Exit = $true

    To also enable CodeCoverage use this configuration option:
        CodeCoverage.Enabled = $true

    .PARAMETER Configuration
    [PesterConfiguration] object for Advanced Configuration created using `New-PesterConfiguration`.
    For help on each option see about_PesterConfiguration or inspect the object.

    .PARAMETER Container
    Specifies one or more ContainerInfo-objects that define containers with tests.
    ContainerInfo-objects are generated using New-PesterContainer. Useful for
    scenarios where data-driven test are generated, e.g. parametrized test files.

    .PARAMETER ExcludePath
    Specifies one or more paths to exclude from the test run.
    Equivalent to ConfigurationProperty Run.ExcludePath.

    .PARAMETER ExcludeTagFilter
    Specifies tags to exclude from the test run.
    Equivalent to ConfigurationProperty Filter.ExcludeTag.

    .PARAMETER FullNameFilter
    Specifies test full names (including Describe/Context/It path) to run.
    Equivalent to ConfigurationProperty Filter.FullName.

    .PARAMETER Output
    Specifies the verbosity of the test output.
    Supports Diagnostic, Detailed, Normal, Minimal, None.
    Equivalent to ConfigurationProperty Output.Verbosity.

    Default value is: Normal

    .PARAMETER PassThru
    Returns a [Pester.Run] object that contains the test results.
    By default, Invoke-Pester writes to the host program, not to the output stream (stdout).
    If you try to save the result in a variable, the variable is empty unless you
    use the PassThru parameter.
    Equivalent to ConfigurationProperty Run.PassThru.
    To suppress the host output, use the Output parameter with value None.

    .PARAMETER Path
    Specifies one or more paths to files containing tests. The value is a path\file
    name or name pattern. Wildcards are permitted.

    .PARAMETER TagFilter
    Specifies tags to include in the test run. Only tests with matching tags will run.
    Equivalent to ConfigurationProperty Filter.Tag.

    .EXAMPLE
    Invoke-Pester

    This command runs all *.Tests.ps1 files in the current directory and its subdirectories.

    .EXAMPLE
    Invoke-Pester -Path .\Util*

    This commands runs all *.Tests.ps1 files in subdirectories with names that begin
    with 'Util' and their subdirectories.

    .EXAMPLE
    ```powershell
    $config = [PesterConfiguration]@{
        Should = @{ # <- Should configuration.
            ErrorAction = 'Continue' # <- Always run all Should-assertions in a test
        }
    }

    Invoke-Pester -Configuration $config
    ```

    This example runs all *.Tests.ps1 files in the current directory and its subdirectories.
    It shows how advanced configuration can be used by casting a hashtable to override
    default settings, in this case to make Pester run all Should-assertions in a test
    even if the first fails.

    .EXAMPLE
    $config = New-PesterConfiguration
    $config.TestResult.Enabled = $true
    Invoke-Pester -Configuration $config

    This example runs all *.Tests.ps1 files in the current directory and its subdirectories.
    It uses advanced configuration to enable testresult-output to file. Access $config.TestResult
    to see other testresult options like  output path and format and their default values.

    .LINK
    https://pester.dev/docs/commands/Invoke-Pester

    .LINK
    https://pester.dev/docs/quick-start
    #>

    # Currently doesn't work. $IgnoreUnsafeCommands filter used in rule as workaround
    # [Diagnostics.CodeAnalysis.SuppressMessageAttribute('Pester.BuildAnalyzerRules\Measure-SafeCommands', 'Remove-Variable', Justification = 'Remove-Variable can't remove "optimized variables" when using "alias" for Remove-Variable.')]
    [CmdletBinding(DefaultParameterSetName = 'Simple')]
    [OutputType([Pester.Run])]
    param(
        [Parameter(Position = 0, Mandatory = 0, ParameterSetName = "Simple")]
        [String[]] $Path = '.',
        [Parameter(ParameterSetName = "Simple")]
        [String[]] $ExcludePath = @(),

        [Parameter(ParameterSetName = "Simple")]
        [string[]] $TagFilter,

        [Parameter(ParameterSetName = "Simple")]
        [string[]] $ExcludeTagFilter,

        [Parameter(ParameterSetName = "Simple")]
        [string[]] $FullNameFilter,

        [Parameter(ParameterSetName = "Simple")]
        [Switch] $CI,

        [Parameter(ParameterSetName = "Simple")]
        [ValidateSet("Diagnostic", "Detailed", "Normal", "Minimal", "None")]
        [String] $Output = "Normal",

        [Parameter(ParameterSetName = "Simple")]
        [Switch] $PassThru,

        [Parameter(ParameterSetName = "Simple")]
        [Pester.ContainerInfo[]] $Container,

        [Parameter(ParameterSetName = "Advanced")]
        [PesterConfiguration] $Configuration
    )
    begin {
        # Prevent $WhatIfPreference from leaking into Pester internals (#2585).
        # When the caller sets $WhatIfPreference = $true, it propagates to child
        # scopes and breaks commands that Pester relies on (New-Item, Remove-Item, etc.).
        $WhatIfPreference = $false
        $start = [DateTime]::Now
        # this will inherit to child scopes and allow Describe / Context to run directly from a file or command line
        $invokedViaInvokePester = $true

        # global mock hook state carried from begin to the finally in the end block (nested runs only)
        $runningPesterInPester = $false
        $savedGlobalMockState = $null

        # Give this run a unique identity used to isolate global mocks between (possibly nested) runs. A
        # mock's bootstrap records the run that created it; a leaked bootstrap whose id does not match the
        # currently executing run defers to the original command instead of applying (see Invoke-Mock).
        # The previous id is restored when this run ends so nested runs each get their own identity.
        $pesterRunId = [Guid]::NewGuid().Guid
        $previousPesterRunId = [Pester.GlobalMockHook]::SetCurrentRun($pesterRunId)

        if ($null -eq $state) {
            # Cleanup any leftover mocks from previous runs, but only if we are not running in a nested Pester-run
            # todo: move mock cleanup to BeforeAllBlockContainer when there is any?
            Remove-MockFunctionsAndAliases -SessionState $PSCmdlet.SessionState
            # The global mock hook is runspace-wide state that a normal mock cleanup does not touch, so an
            # interrupted previous run (e.g. Ctrl+C during a global mock) can leave it armed. Reset it here
            # so a fresh top-level run always starts with no global mocks and no lookup handler installed.
            Reset-GlobalMockHook
        }
        else {
            # this will inherit to child scopes and affect behavior of ex. TestDrive/TestRegistry
            $runningPesterInPester = $true
            # This is a nested run. The global mock hook is shared across the whole runspace, so give this
            # run its own clean slate and protect the outer run: snapshot the outer run's global mocks, then
            # clear the shared state. It is restored once this run ends (see the finally in the end block).
            $savedGlobalMockState = Get-GlobalMockHookState
            Reset-GlobalMockHook
        }

        # this will inherit to child scopes and allow Pester to run in Pester, not checking if this is
        # already defined because we want a clean state for this Invoke-Pester even if it runs inside another
        # testrun (which calls Invoke-Pester itself)
        $state = New-PesterState

        # store CWD so we can revert any changes at the end
        $initialPWD = $pwd.Path
    }

    end {
        try {
            # populate config from parameters and remove them (variables) so we
            # don't inherit them to child functions by accident
            if ('Simple' -eq $PSCmdlet.ParameterSetName) {
                # dot-sourcing the function to allow removing local variables
                $Configuration = . Convert-PesterSimpleParameterSet -BoundParameters $PSBoundParameters
            }

            # maybe -IgnorePesterPreference to avoid using $PesterPreference from the context

            $callerPreference = [PesterConfiguration] $PSCmdlet.SessionState.PSVariable.GetValue("PesterPreference")
            $hasCallerPreference = $null -ne $callerPreference

            # we never want to use and keep the pester preference directly,
            # because then the settings are modified on an object that outlives the
            # invoke-pester run and we leak changes from this run to the next
            # such as filters set in the first run will end up in the next run as well
            #
            # preference is inherited in all subsequent calls in this session state
            # but we still pass it explicitly where practical
            if (-not $hasCallerPreference) {
                if ($PSBoundParameters.ContainsKey('Configuration')) {
                    # Advanced configuration used, merging to get new reference
                    [PesterConfiguration] $PesterPreference = [PesterConfiguration]::Merge([PesterConfiguration]::Default, $Configuration)
                }
                else {
                    [PesterConfiguration] $PesterPreference = $Configuration
                }
            }
            elseif ($hasCallerPreference) {
                [PesterConfiguration] $PesterPreference = [PesterConfiguration]::Merge($callerPreference, $Configuration)
            }

            & $SafeCommands['Get-Variable'] 'Configuration' -Scope Local | Remove-Variable

            Resolve-AutoEnabledConfiguration -PesterPreference $PesterPreference

            # $sessionState = Set-SessionStateHint -PassThru  -Hint "Caller - Captured in Invoke-Pester" -SessionState $PSCmdlet.SessionState
            $sessionState = $PSCmdlet.SessionState

            $pluginConfiguration = @{}
            $pluginData = @{}
            $plugins = [System.Collections.Generic.List[object]]@()

            # Processing Output-configuration before any use of Write-PesterStart and Write-PesterDebugMessage.
            # Write-PesterDebugMessage is used regardless of WriteScreenPlugin.
            Resolve-OutputConfiguration -PesterPreference $PesterPreference

            if ('None' -ne $PesterPreference.Output.Verbosity.Value) {
                $plugins.Add((Get-WriteScreenPlugin -Verbosity $PesterPreference.Output.Verbosity.Value))
            }

            $plugins.Add((
                    # decorator plugin needs to be added after output
                    # because on teardown they will run in opposite order
                    # and that way output can consume the fixed object that decorator
                    # decorated, not nice but works
                    Get-RSpecObjectDecoratorPlugin
                ))

            if ($PesterPreference.TestDrive.Enabled.Value) {
                $plugins.Add((Get-TestDrivePlugin))
            }

            if ($PesterPreference.TestRegistry.Enabled.Value -and "Windows" -eq (GetPesterOs)) {
                $plugins.Add((Get-TestRegistryPlugin))
            }

            $plugins.Add((Get-MockPlugin))
            $plugins.Add((Get-SkipRemainingOnFailurePlugin))

            if ($PesterPreference.CodeCoverage.Enabled.Value) {
                $plugins.Add((Get-CoveragePlugin))
            }

            if ($PesterPreference.TestResult.Enabled.Value) {
                $plugins.Add((Get-TestResultPlugin))
            }

            # this is here to support Pester test runner in VSCode. Don't use it unless you are prepared to get broken in the future. And if you decide to use it, let us know in https://github.com/pester/Pester/issues/2021 so we can warn you about removing this.
            if (defined additionalPlugins) { $plugins.AddRange(@($script:additionalPlugins)) }

            $filter = New-FilterObject `
                -Tag $PesterPreference.Filter.Tag.Value `
                -ExcludeTag $PesterPreference.Filter.ExcludeTag.Value `
                -Line $PesterPreference.Filter.Line.Value `
                -ExcludeLine $PesterPreference.Filter.ExcludeLine.Value `
                -FullName $PesterPreference.Filter.FullName.Value

            $containers = @()
            if (any $PesterPreference.Run.ScriptBlock.Value) {
                $containers += @( $PesterPreference.Run.ScriptBlock.Value | & $SafeCommands['ForEach-Object'] { New-BlockContainerObject -ScriptBlock $_ })
            }

            foreach ($c in $PesterPreference.Run.Container.Value) {
                # Running through New-BlockContainerObject again to avoid modifying original container and it's Data during runtime
                $containers += (New-BlockContainerObject -Container $c -Data $c.Data)
            }

            if ((any $PesterPreference.Run.Path.Value)) {
                if (((none $PesterPreference.Run.ScriptBlock.Value) -and (none $PesterPreference.Run.Container.Value)) -or ('.' -ne $PesterPreference.Run.Path.Value[0])) {
                    #TODO: Skipping the invocation when scriptblock is provided and the default path, later keep path in the default parameter set and remove scriptblock from it, so get-help still shows . as the default value and we can still provide script blocks via an advanced settings parameter
                    # TODO: pass the startup options as context to Start instead of just paths

                    $exclusions = combineNonNull @($PesterPreference.Run.ExcludePath.Value, ($PesterPreference.Run.Container.Value | & $SafeCommands['Where-Object'] { "File" -eq $_.Type } | & $SafeCommands['ForEach-Object'] { $_.Item.FullName }))
                    $containers += @(Find-File -Path $PesterPreference.Run.Path.Value -ExcludePath $exclusions -Extension $PesterPreference.Run.TestExtension.Value | & $SafeCommands['ForEach-Object'] { New-BlockContainerObject -File $_ })
                }
            }

            $steps = $Plugins.Start
            if ($null -ne $steps -and 0 -lt @($steps).Count) {
                Invoke-PluginStep -Plugins $Plugins -Step Start -Context @{
                    Containers               = $containers
                    Configuration            = $pluginConfiguration
                    GlobalPluginData         = $pluginData
                    WriteDebugMessages       = $PesterPreference.Debug.WriteDebugMessages.Value
                    Write_PesterDebugMessage = if ($PesterPreference.Debug.WriteDebugMessages.Value) { $script:SafeCommands['Write-PesterDebugMessage'] }
                } -ThrowOnFailure
            }

            if ((none $containers)) {
                throw "No test files were found and no scriptblocks were provided. Please ensure that you provided at least one path to a *$($PesterPreference.Run.TestExtension.Value) file, or a directory that contains such file.$(if ($null -ne $PesterPreference.Run.ExcludePath.Value -and 0 -lt @($PesterPreference.Run.ExcludePath.Value).Length) {" And that there is at least one file not excluded by ExcludeFile filter '$($PesterPreference.Run.ExcludePath.Value -join "', '")'."}) Or that you provided a ScriptBlock test container."
                return
            }

            # Parallel mode runs each file in its own runspace and merges the executed
            # containers back. It only applies to file-based runs on PowerShell 7+; other cases fall
            # back to the normal sequential path with a warning. CodeCoverage is supported: each
            # worker measures its own file with breakpoints and the parent merges the results (see
            # the parallel branch below).
            $useParallel = $PesterPreference.Run.Parallel.Value
            $parallelSupported = $PSVersionTable.PSVersion.Major -ge 7
            $allFileContainers = 0 -eq @($containers | & $SafeCommands['Where-Object'] { 'File' -ne $_.Type }).Count
            $coverageEnabled = $PesterPreference.CodeCoverage.Enabled.Value
            # Run.SkipRemainingOnFailure = 'Run' stops the whole run after the first failed
            # test by carrying a flag from one container to the next. That flag lives on the
            # per-run configuration, which workers do not share, so it cannot span runspaces -
            # fall back to sequential so the 'stop on first failure' intent is honored. The
            # 'Block'/'Container' scopes only skip within a single file, so they are unaffected.
            $skipRemainingRunScope = 'Run' -eq $PesterPreference.Run.SkipRemainingOnFailure.Value

            # Partition files by the #pester:no-parallel directive. Files that opt out run in this
            # (non-isolated) session via the normal interleaved path, exactly like a sequential run
            # - so files that depend on shared session state (declaration order, global setup,
            # cross-file mocks) keep working and produce live output. The rest run concurrently,
            # each in its own runspace.
            # NOTE: avoid the variable names $Container and $CI here - they are parameters of
            # Invoke-Pester ([Pester.ContainerInfo[]] $Container and [Switch] $CI), and reusing
            # them inherits those type constraints, which silently corrupts the loop variable.
            $parallelContainers = [System.Collections.Generic.List[object]]@()
            $nonParallelContainers = [System.Collections.Generic.List[object]]@()
            if ($useParallel -and $parallelSupported -and $allFileContainers -and -not $skipRemainingRunScope) {
                foreach ($fileContainer in $containers) {
                    if (Test-PesterFileIsNonParallel -Path $fileContainer.Item.FullName) {
                        $nonParallelContainers.Add($fileContainer)
                    }
                    else {
                        $parallelContainers.Add($fileContainer)
                    }
                }
            }

            if ($useParallel -and -not $parallelSupported) {
                & $SafeCommands['Write-Warning'] "Run.Parallel requires PowerShell 7 or later for 'ForEach-Object -Parallel'. Running the tests sequentially instead."
            }
            elseif ($useParallel -and -not $allFileContainers) {
                & $SafeCommands['Write-Warning'] "Run.Parallel currently parallelizes only file-based runs (Run.Path). The provided ScriptBlock/Container test(s) will run sequentially instead."
            }
            elseif ($useParallel -and $skipRemainingRunScope) {
                & $SafeCommands['Write-Warning'] "Run.Parallel does not support Run.SkipRemainingOnFailure = 'Run' because skipping after the first failure cannot span the isolated worker runspaces. Running the tests sequentially instead."
            }

            # Resolve the BeforeContainer initialization once for the whole run. It is the same for
            # every file (from the repo-root Pester.BeforeContainer.ps1 convention file) and
            # runs before each container in both the parallel and sequential paths below.
            $beforeContainerInit = Resolve-PesterBeforeContainer -Configuration $PesterPreference

            # Engage the parallel path only when at least one file can actually run in parallel.
            # If every file opted out with #pester:no-parallel, the run is effectively sequential,
            # so fall through to the sequential path - which fires the framework's own global
            # plugin steps at the correct interleaved points.
            $ranInParallel = $useParallel -and $parallelSupported -and $allFileContainers -and -not $skipRemainingRunScope -and 0 -lt $parallelContainers.Count
            if ($ranInParallel) {
                $foldedContainers = [System.Collections.Generic.List[object]]@()
                $hasNonParallel = 0 -lt $nonParallelContainers.Count

                # CodeCoverage in a parallel run: every worker measures the same locations with
                # breakpoints and returns its per-location hits (the default profiler/tracer keeps its
                # state in a process-global static and is not concurrency-safe). The parent collects
                # those, adds the coverage of any #pester:no-parallel files it runs in-session, merges
                # them, and lets the Coverage plugin's End step emit the single report and output file.
                # Force breakpoint mode on the captured plugin configuration so the End step (and the
                # in-session non-parallel measurement) does not try to use the tracer's Measure.
                $collectCoverageInParallel = $coverageEnabled
                $parallelCoverage = [System.Collections.Generic.List[object]]@()
                $coveragePlugins = [System.Collections.Generic.List[object]]@()
                if ($collectCoverageInParallel) {
                    $pluginConfiguration['Coverage'].UseBreakpoints = $true
                    foreach ($pl in $plugins) {
                        if ('Coverage' -eq $pl.Name) { $coveragePlugins.Add($pl) }
                    }
                }

                # The parent owns ALL framing for a parallel run. It fires the global and
                # per-container/per-test plugin steps to a REPORTING-only plugin subset (screen
                # output + IDE adapters) so the emitted events match a sequential run, while the
                # execution-critical plugins (Mock/TestDrive/TestRegistry/Coverage) already ran
                # inside the workers. WriteScreen and the additional (e.g. VSCode) plugins are the
                # only ones replayed; TestResult is produced once from the merged tree by the End step.
                $reportingPlugins = [System.Collections.Generic.List[object]]@()
                foreach ($pl in $plugins) {
                    if ('WriteScreen' -eq $pl.Name) { $reportingPlugins.Add($pl) }
                }
                if (defined additionalPlugins) { $reportingPlugins.AddRange(@($script:additionalPlugins)) }

                # Replays one segment of a worker's recorded event tape to the reporting plugins.
                # The recorded context carries the worker's PluginConfiguration; swap in the parent's
                # so any plugin that reads $Context.Configuration sees this run's configuration.
                $replaySegment = {
                    param($entries)
                    foreach ($entry in $entries) {
                        # Host/debug output captured in the worker carries no Step - replay it to the
                        # real host now, in tape order, so it lands interleaved with the per-test output
                        # it belongs to instead of appearing up front, detached from its test (#2825).
                        if ($null -eq $entry.Step) {
                            $hostArgs = $entry.Host
                            Write-PesterHostMessage @hostArgs
                            continue
                        }
                        if ($entry.Context -is [System.Collections.IDictionary] -and $entry.Context.Contains('Configuration')) {
                            $entry.Context['Configuration'] = $pluginConfiguration
                        }
                        $null = Invoke-PluginStep -Plugins $reportingPlugins -Step $entry.Step -Context $entry.Context
                    }
                }

                # Global DiscoveryStart once, up front, for the whole run (drives the banner).
                # Parallel = $true tells WriteScreen to mark the banner as a parallel run.
                Invoke-PluginStep -Plugins $reportingPlugins -Step DiscoveryStart -Context @{
                    BlockContainers = $containers
                    Configuration   = $pluginConfiguration
                    Parallel        = $true
                } -ThrowOnFailure

                $runStartFired = $false
                $discoveryEndFired = $false
                $totalDiscoveryWatch = [System.Diagnostics.Stopwatch]::StartNew()

                # Parallel files: each worker runs a full (silent) Invoke-Pester on its single file
                # and returns the executed containers plus the recorded event tape. Replay each
                # file's discovery segment then run segment, in discovery order, firing the global
                # RunStart/DiscoveryEnd steps at the interleaved points a sequential run would.
                if (0 -lt $parallelContainers.Count) {
                    $parallelResults = @(Invoke-TestInParallel -BlockContainer $parallelContainers -Configuration $PesterPreference)
                    for ($pri = 0; $pri -lt $parallelResults.Count; $pri++) {
                        $parallelResult = $parallelResults[$pri]
                        $segments = Split-PesterEventTape -Tape $parallelResult.Tape

                        & $replaySegment $segments.Discovery

                        # Worker containers come from a full Invoke-Pester run, so they are already
                        # RSpec-folded - collect them straight away (do not re-fold).
                        foreach ($c in $parallelResult.Containers) { $foldedContainers.Add($c) }

                        # Gather this worker's measured coverage (already projected to a light shape).
                        if ($collectCoverageInParallel -and $null -ne $parallelResult.Coverage) {
                            foreach ($cc in $parallelResult.Coverage) { $parallelCoverage.Add($cc) }
                        }

                        # All-parallel: the last file just finished discovery, so global discovery
                        # is complete - fire DiscoveryEnd before replaying that file's run segment,
                        # exactly as the interleaved sequential path does.
                        if ((-not $hasNonParallel) -and (-not $discoveryEndFired) -and ($pri -eq ($parallelResults.Count - 1))) {
                            Invoke-PluginStep -Plugins $reportingPlugins -Step DiscoveryEnd -Context @{
                                BlockContainers = $foldedContainers
                                Duration        = $totalDiscoveryWatch.Elapsed
                                Configuration   = $pluginConfiguration
                                Filter          = $filter
                            } -ThrowOnFailure
                            $discoveryEndFired = $true
                        }

                        if (-not $runStartFired) {
                            Invoke-PluginStep -Plugins $reportingPlugins -Step RunStart -Context @{
                                Blocks                   = $foldedContainers
                                Configuration            = $pluginConfiguration
                                Data                     = $pluginData
                                WriteDebugMessages       = $PesterPreference.Debug.WriteDebugMessages.Value
                                Write_PesterDebugMessage = if ($PesterPreference.Debug.WriteDebugMessages.Value) { $script:SafeCommands['Write-PesterDebugMessage'] }
                            } -ThrowOnFailure
                            $runStartFired = $true
                        }

                        & $replaySegment $segments.Run
                    }
                }

                # Non-parallel files: run in this session via the normal interleaved path so they
                # behave exactly like a sequential run (shared session, live output, full plugin
                # events to every plugin). The parent owns the global framing, so suppress this
                # call's global steps (-SkipFrameworkGlobalSteps) to keep one banner/summary.
                if ($hasNonParallel) {
                    if (-not $runStartFired) {
                        Invoke-PluginStep -Plugins $reportingPlugins -Step RunStart -Context @{
                            Blocks                   = $foldedContainers
                            Configuration            = $pluginConfiguration
                            Data                     = $pluginData
                            WriteDebugMessages       = $PesterPreference.Debug.WriteDebugMessages.Value
                            Write_PesterDebugMessage = if ($PesterPreference.Debug.WriteDebugMessages.Value) { $script:SafeCommands['Write-PesterDebugMessage'] }
                        } -ThrowOnFailure
                        $runStartFired = $true
                    }

                    # Measure coverage for the in-session (#pester:no-parallel) files. Their
                    # Invoke-Test call runs with -SkipFrameworkGlobalSteps, which suppresses the
                    # Coverage plugin's own RunStart/RunEnd, so fire them here to set up and tear down
                    # breakpoints around this batch. UseBreakpoints was forced above, so this measures
                    # with breakpoints too and merges cleanly with the workers' hits.
                    if ($collectCoverageInParallel) {
                        Invoke-PluginStep -Plugins $coveragePlugins -Step RunStart -Context @{
                            Blocks                   = $foldedContainers
                            Configuration            = $pluginConfiguration
                            Data                     = $pluginData
                            WriteDebugMessages       = $PesterPreference.Debug.WriteDebugMessages.Value
                            Write_PesterDebugMessage = if ($PesterPreference.Debug.WriteDebugMessages.Value) { $script:SafeCommands['Write-PesterDebugMessage'] }
                        } -ThrowOnFailure
                    }

                    $r = Invoke-Test -BlockContainer $nonParallelContainers -Plugin $plugins -PluginConfiguration $pluginConfiguration -PluginData $pluginData -SessionState $sessionState -Filter $filter -Configuration $PesterPreference -BeforeContainerInit $beforeContainerInit -SkipFrameworkGlobalSteps

                    if ($collectCoverageInParallel) {
                        Invoke-PluginStep -Plugins $coveragePlugins -Step RunEnd -Context @{
                            Blocks                   = $foldedContainers
                            Configuration            = $pluginConfiguration
                            Data                     = $pluginData
                            WriteDebugMessages       = $PesterPreference.Debug.WriteDebugMessages.Value
                            Write_PesterDebugMessage = if ($PesterPreference.Debug.WriteDebugMessages.Value) { $script:SafeCommands['Write-PesterDebugMessage'] }
                        } -ThrowOnFailure

                        if ($pluginData.ContainsKey('Coverage') -and $null -ne $pluginData.Coverage) {
                            foreach ($cc in (Convert-CommandCoverageToProjection -CommandCoverage @($pluginData.Coverage.CommandCoverage))) {
                                $parallelCoverage.Add($cc)
                            }
                        }
                    }

                    $rspecResult = Split-RSpecResult -Result $r
                    if (0 -lt $rspecResult.StrayOutput.Count) {
                        $strayDescription = @(foreach ($strayItem in $rspecResult.StrayOutput) { "'$strayItem'" }) -join ', '
                        & $SafeCommands['Write-Warning'] "Pester received unexpected output while running tests and ignored it: $strayDescription. This is usually caused by a native command writing to the success stream in a setup block such as BeforeAll. Redirect the output to `$null, for example: `$null = my-command 2>`&1."
                    }

                    foreach ($c in $rspecResult.Containers) {
                        Fold-Container -Container $c  -OnTest { param($t) Add-RSpecTestObjectProperties $t }
                        $foldedContainers.Add($c)
                    }
                }

                # Global DiscoveryEnd (if not already fired), RunStart (defensive), then RunEnd -
                # once each, at the very end.
                if (-not $discoveryEndFired) {
                    Invoke-PluginStep -Plugins $reportingPlugins -Step DiscoveryEnd -Context @{
                        BlockContainers = $foldedContainers
                        Duration        = $totalDiscoveryWatch.Elapsed
                        Configuration   = $pluginConfiguration
                        Filter          = $filter
                    } -ThrowOnFailure
                    $discoveryEndFired = $true
                }

                if (-not $runStartFired) {
                    Invoke-PluginStep -Plugins $reportingPlugins -Step RunStart -Context @{
                        Blocks                   = $foldedContainers
                        Configuration            = $pluginConfiguration
                        Data                     = $pluginData
                        WriteDebugMessages       = $PesterPreference.Debug.WriteDebugMessages.Value
                        Write_PesterDebugMessage = if ($PesterPreference.Debug.WriteDebugMessages.Value) { $script:SafeCommands['Write-PesterDebugMessage'] }
                    } -ThrowOnFailure
                    $runStartFired = $true
                }

                Invoke-PluginStep -Plugins $reportingPlugins -Step RunEnd -Context @{
                    Blocks                   = $foldedContainers
                    Configuration            = $pluginConfiguration
                    Data                     = $pluginData
                    WriteDebugMessages       = $PesterPreference.Debug.WriteDebugMessages.Value
                    Write_PesterDebugMessage = if ($PesterPreference.Debug.WriteDebugMessages.Value) { $script:SafeCommands['Write-PesterDebugMessage'] }
                } -ThrowOnFailure

                # Restore the original discovery order across both batches so the merged run is
                # deterministic regardless of which files ran where or which worker finished first.
                $order = @{}
                for ($i = 0; $i -lt $containers.Count; $i++) {
                    $order[$containers[$i].Item.FullName] = $i
                }
                $rspecContainers = @($foldedContainers | & $SafeCommands['Sort-Object'] -Property @{ Expression = {
                            $key = if ($_.Item -is [System.IO.FileInfo]) { $_.Item.FullName } else { [string]$_.Item }
                            if ($order.ContainsKey($key)) { $order[$key] } else { [int]::MaxValue }
                        }
                    })

                # Merge every batch's measured locations into one CommandCoverage list and hand it to
                # the plugin data, so the Coverage plugin's End step (fired once below) produces the
                # single merged report and writes the output file. A location counts as covered when
                # any file hit it; hit counts are summed across files.
                if ($collectCoverageInParallel) {
                    $mergedCoverage = @(Merge-CoverageFromParallel -CommandCoverage $parallelCoverage.ToArray())
                    $pluginData['Coverage'] = @{
                        CommandCoverage = $mergedCoverage
                        Tracer          = $null
                        Patched         = $false
                        CoverageReport  = $null
                    }
                }
            }
            else {
                $r = Invoke-Test -BlockContainer $containers -Plugin $plugins -PluginConfiguration $pluginConfiguration -PluginData $pluginData -SessionState $sessionState -Filter $filter -Configuration $PesterPreference -BeforeContainerInit $beforeContainerInit

                # Invoke-Test should only return [Pester.Container] objects, but stray output produced during the
                # run - most often a native command writing to the success stream in a setup block (e.g. BeforeAll)
                # without being redirected to $null - can leak into the pipeline. Adding it to the strongly-typed
                # Run.Containers list throws an opaque "Cannot find an overload for Add" error that fails the whole
                # run. Separate it out and warn instead of crashing. (#2655)
                $rspecResult = Split-RSpecResult -Result $r
                $rspecContainers = $rspecResult.Containers
                if (0 -lt $rspecResult.StrayOutput.Count) {
                    $strayDescription = @(foreach ($strayItem in $rspecResult.StrayOutput) { "'$strayItem'" }) -join ', '
                    & $SafeCommands['Write-Warning'] "Pester received unexpected output while running tests and ignored it: $strayDescription. This is usually caused by a native command writing to the success stream in a setup block such as BeforeAll. Redirect the output to `$null, for example: `$null = my-command 2>`&1."
                }

                foreach ($c in $rspecContainers) {
                    Fold-Container -Container $c  -OnTest { param($t) Add-RSpecTestObjectProperties $t }
                }
            }

            # Wall-clock end of test execution, captured before building and post-processing the
            # run object. For parallel runs this is used as Run.Duration, because summing the
            # overlapping container durations would overstate the actual elapsed time. (#2794)
            $end = [DateTime]::Now

            $run = [Pester.Run]::Create()
            $run.Executed = $true
            $run.ExecutedAt = $start
            $run.PSBoundParameters = $PSBoundParameters
            $run.PluginConfiguration = $pluginConfiguration
            $run.Plugins = $Plugins
            $run.PluginData = $pluginData
            $run.Configuration = $PesterPreference
            $m = $ExecutionContext.SessionState.Module
            $run.Version = if ($m.PrivateData -and $m.PrivateData.PSData -and $m.PrivateData.PSData.PreRelease) {
                "$($m.Version)-$($m.PrivateData.PSData.PreRelease)"
            }
            else {
                $m.Version
            }

            $run.PSVersion = $PSVersionTable.PSVersion
            foreach ($i in $rspecContainers) {
                $run.Containers.Add($i)
            }

            PostProcess-RSpecTestRun -TestRun $run -Parallel:$ranInParallel -RunDuration ($end - $start)

            $steps = $Plugins.End
            if ($null -ne $steps -and 0 -lt @($steps).Count) {
                Invoke-PluginStep -Plugins $Plugins -Step End -Context @{
                    TestRun          = $run
                    Configuration    = $pluginConfiguration
                    GlobalPluginData = $pluginData
                } -ThrowOnFailure
            }

            if (-not $PesterPreference.Debug.ReturnRawResultObject.Value) {
                Remove-RSPecNonPublicProperties $run
            }

            $failedCount = $run.FailedCount + $run.FailedBlocksCount + $run.FailedContainersCount
            if ($PesterPreference.Run.PassThru.Value -and -not ($PesterPreference.Run.Exit.Value -and 0 -ne $failedCount)) {
                $run
            }

        }
        catch {
            $formatErrorParams = @{
                Err                 = $_
                StackTraceVerbosity = $PesterPreference.Output.StackTraceVerbosity.Value
            }

            if ($PesterPreference.Output.CIFormat.Value -in 'AzureDevops', 'GithubActions') {
                $errorMessage = (Format-ErrorMessage @formatErrorParams) -split [Environment]::NewLine
                Write-CIErrorToScreen -CIFormat $PesterPreference.Output.CIFormat.Value -CILogLevel $PesterPreference.Output.CILogLevel.Value -Header $errorMessage[0] -Message $errorMessage[1..($errorMessage.Count - 1)]
            }
            else {
                Write-ErrorToScreen @formatErrorParams -Throw:$PesterPreference.Run.Throw.Value
            }

            if ($PesterPreference.Run.Exit.Value) {
                exit -1
            }
        }
        finally {
            # If this was a nested run, restore the outer run's global mocks that we snapshotted and
            # cleared in the begin block. Runs on success and on failure so a nested run can never leave
            # the outer run's global mock hook clobbered or detached.
            if ($runningPesterInPester) {
                Restore-GlobalMockHookState -State $savedGlobalMockState
            }
            # Restore the run id that was active before this run (null for a top-level run) so the nonce
            # used to isolate global mocks is correct for whatever run resumes.
            $null = [Pester.GlobalMockHook]::SetCurrentRun($previousPesterRunId)
        }

        # go back to original CWD
        if ($null -ne $initialPWD) { & $SafeCommands['Set-Location'] -Path $initialPWD }

        # always set exit code. This both to:
        # - avoid inheriting a previous commands non-zero exit code
        # - setting the exit code when there were some failed tests, blocks, or containers
        $failedCount = $run.FailedCount + $run.FailedBlocksCount + $run.FailedContainersCount
        $global:LASTEXITCODE = $failedCount

        if ($PesterPreference.Run.Throw.Value -and 0 -ne $failedCount) {
            $messages = combineNonNull @(
                $(if (0 -lt $run.FailedCount) { "$($run.FailedCount) test$(if (1 -lt $run.FailedCount) { "s" }) failed" })
                $(if (0 -lt $run.FailedBlocksCount) { "$($run.FailedBlocksCount) block$(if (1 -lt $run.FailedBlocksCount) { "s" }) failed" })
                $(if (0 -lt $run.FailedContainersCount) { "$($run.FailedContainersCount) container$(if (1 -lt $run.FailedContainersCount) { "s" }) failed" })
            )
            throw "Pester run failed, because $(Join-And $messages)"
        }

        if ($PesterPreference.Run.Exit.Value -and 0 -ne $failedCount) {
            # exit with the number of failed tests when there are any
            # and the exit preference is set. This will fail the run in CI
            # when any tests failed.
            exit $failedCount
        }
    }
}

function Convert-PesterSimpleParameterSet ($BoundParameters) {
    $Configuration = [PesterConfiguration]::Default

    $migrations = @{
        'Path'             = {
            if ($null -ne $Path) {
                if (@($Path)[0] -is [System.Collections.IDictionary]) {
                    throw 'Passing hashtable configuration to -Path is currently not supported in Pester 5.0. Please provide just paths, as an array of strings.'
                }

                $Configuration.Run.Path = $Path
            }
        }

        'ExcludePath'      = {
            if ($null -ne $ExcludePath) {
                $Configuration.Run.ExcludePath = $ExcludePath
            }
        }

        'TagFilter'        = {
            if ($null -ne $TagFilter -and 0 -lt @($TagFilter).Count) {
                $Configuration.Filter.Tag = $TagFilter
            }
        }

        'ExcludeTagFilter' = {
            if ($null -ne $ExcludeTagFilter -and 0 -lt @($ExcludeTagFilter).Count) {
                $Configuration.Filter.ExcludeTag = $ExcludeTagFilter
            }
        }

        'FullNameFilter'   = {
            if ($null -ne $FullNameFilter -and 0 -lt @($FullNameFilter).Count) {
                $Configuration.Filter.FullName = $FullNameFilter
            }
        }

        'CI'               = {
            if ($CI) {
                $Configuration.Run.Exit = $true
                $Configuration.TestResult.Enabled = $true
            }
        }

        'Output'           = {
            if ($null -ne $Output) {
                $Configuration.Output.Verbosity = $Output
            }
        }

        'PassThru'         = {
            if ($null -ne $PassThru) {
                $Configuration.Run.PassThru = [bool] $PassThru
            }
        }

        'Container'        = {
            if ($null -ne $Container) {
                $Configuration.Run.Container = $Container
            }
        }
    }

    # Run all applicable migrations and remove variable to avoid leaking into child scopes
    foreach ($key in $migrations.Keys) {
        if ($BoundParameters.ContainsKey($key)) {
            . $migrations[$key]
            & $SafeCommands['Get-Variable'] -Name $key -Scope Local | Remove-Variable
        }
    }

    return $Configuration
}

function Split-RSpecResult {
    # Invoke-Test should only return [Pester.Container] objects. Stray output produced during the run - most
    # commonly a native command writing to the success stream in a setup block (e.g. BeforeAll) that was not
    # redirected to $null - can leak into the pipeline. Adding it to the strongly-typed Run.Containers list
    # throws an opaque "Cannot find an overload for Add" error and fails the whole run. Separate the containers
    # from any stray output so the caller can keep the results and warn instead of crashing. (#2655)
    param ($Result)

    $containers = [System.Collections.Generic.List[Pester.Container]]@()
    $strayOutput = [System.Collections.Generic.List[object]]@()

    foreach ($i in $Result) {
        if ($i -is [Pester.Container]) {
            $containers.Add($i)
        }
        elseif ($null -ne $i) {
            $strayOutput.Add($i)
        }
    }

    return [PSCustomObject]@{
        Containers  = $containers
        StrayOutput = $strayOutput
    }
}

function Resolve-AutoEnabledConfiguration {
    param ([PesterConfiguration] $PesterPreference)

    $PesterPreference.CodeCoverage.ResolveEnabled()
    $PesterPreference.TestResult.ResolveEnabled()
}

function ConvertTo-Pester4Result {
    <#
    .SYNOPSIS
    Converts a Pester 5 result-object to an Pester 4-compatible object

    .DESCRIPTION
    Pester 5 uses a new format for it's result-object compared to previous
    versions of Pester. This function is provided as a way to convert the
    result-object into an object using the previous format. This can be
    useful as a temporary measure to easier migrate to Pester 5 without
    having to redesign complex CI/CD-pipelines.

    .PARAMETER PesterResult
    Result object from a Pester 5-run. This can be retrieved using Invoke-Pester
    -Passthru or by using the Run.PassThru configuration-option.

    .EXAMPLE
    ```powershell
    $pester5Result = Invoke-Pester -Passthru
    $pester4Result = $pester5Result | ConvertTo-Pester4Result
    ```

    This example runs Pester using the Passthru option to retrieve a result-object
    in the Pester 5 format and converts it to a new Pester 4-compatible result-object.

    .LINK
    https://pester.dev/docs/commands/ConvertTo-Pester4Result

    .LINK
    https://pester.dev/docs/commands/Invoke-Pester
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        $PesterResult
    )
    process {
        $legacyResult = [PSCustomObject] @{
            Version           = "4.99.0"
            TagFilter         = $null
            ExcludeTagFilter  = $null
            TestNameFilter    = $null
            ScriptBlockFilter = $null
            TotalCount        = 0
            PassedCount       = 0
            FailedCount       = 0
            SkippedCount      = 0
            InconclusiveCount = 0
            Time              = [TimeSpan]::Zero
            TestResult        = [System.Collections.Generic.List[object]]@()
        }
        $filter = $PesterResult.Configuration.Filter
        $legacyResult.TagFilter = if (0 -ne $filter.Tag.Value.Count) { $filter.Tag.Value }
        $legacyResult.ExcludeTagFilter = if (0 -ne $filter.ExcludeTag.Value.Count) { $filter.ExcludeTag.Value }
        $legacyResult.TestNameFilter = if (0 -ne $filter.TestNameFilter.Value.Count) { $filter.TestNameFilter.Value }
        $legacyResult.ScriptBlockFilter = if (0 -ne $filter.ScriptBlockFilter.Value.Count) { $filter.ScriptBlockFilter.Value }

        $sb = {
            param($test)

            if ("NotRun" -eq $test.Result) {
                return
            }

            $result = [PSCustomObject] @{
                Passed                 = "Passed" -eq $test.Result
                Result                 = $test.Result
                Time                   = $test.Duration
                Name                   = $test.Name

                # in the legacy result the top block is considered to be a Describe and any blocks inside of it are
                # considered to be Context and joined by '\'
                Describe               = $test.Path[0]
                Context                = $(if ($test.Path.Count -gt 2) { $test.Path[1..($test.Path.Count - 2)] -join '\' })

                Show                   = $PesterResult.Configuration.Output.Verbosity.Value
                Parameters             = $test.Data
                ParameterizedSuiteName = $test.DisplayName

                FailureMessage         = $(if (any $test.ErrorRecord -and $null -ne $test.ErrorRecord[-1].Exception) { $test.ErrorRecord[-1].DisplayErrorMessage })
                ErrorRecord            = $(if (any $test.ErrorRecord) { $test.ErrorRecord[-1] })
                StackTrace             = $(if (any $test.ErrorRecord) { $test.ErrorRecord[1].DisplayStackTrace })
            }

            $null = $legacyResult.TestResult.Add($result)
        }


        Fold-Run $PesterResult -OnTest $sb -OnBlock {
            param($b)

            if (0 -ne $b.ErrorRecord.Count) {
                & $sb $b
            }
        }

        # the counts here include failed blocks as tests, that's we don't use
        # the normal properties on the result to count

        foreach ($r in $legacyResult.TestResult) {
            switch ($r.Result) {
                "Passed" {
                    $legacyResult.PassedCount++
                }
                "Failed" {
                    $legacyResult.FailedCount++
                }
                "Skipped" {
                    $legacyResult.SkippedCount++
                }
                "Inconclusive" {
                    $legacyResult.InconclusiveCount++
                }
            }
        }
        $legacyResult.TotalCount = $legacyResult.TestResult.Count
        $legacyResult.Time = $PesterResult.Duration

        $legacyResult
    }
}

function BeforeDiscovery {
    <#
    .SYNOPSIS
    Runs setup code that is used during Discovery phase.

    .DESCRIPTION
    Runs your code as is, in the place where this function is defined. This is a semantic block to allow you
    to be explicit about code that you need to run during Discovery, instead of just
    putting code directly inside of Describe / Context.

    .PARAMETER ScriptBlock
    The ScriptBlock to run.

    .EXAMPLE
    ```powershell
    BeforeDiscovery {
        $files = Get-ChildItem -Path $PSScriptRoot -Filter '*.ps1' -Recurse
    }

    Describe "File - <_>" -ForEach $files {
        Context "Whitespace" {
            It "There is no extra whitespace following a line" {
                # ...
            }

            It "File ends with an empty line" {
                # ...
            }
        }
    }
    ```

    BeforeDiscovery is used to gather a list of script-files during Discovery-phase to
    dynamically create a Describe-block and tests for each file found.

    .LINK
    https://pester.dev/docs/commands/BeforeDiscovery

    .LINK
    https://pester.dev/docs/usage/data-driven-tests
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ScriptBlock]$ScriptBlock
    )

    Assert-BoundScriptBlockInput -ScriptBlock $ScriptBlock

    if ($ExecutionContext.SessionState.PSVariable.Get('invokedViaInvokePester')) {
        if ($state.CurrentBlock.IsRoot -and -not $state.CurrentBlock.FrameworkData.MissingParametersProcessed) {
            # For undefined parameters in container, add parameter's default value to Data
            Add-MissingContainerParameters -RootBlock $state.CurrentBlock -Container $container -CallingFunction $PSCmdlet
        }

        . $ScriptBlock
    }
    else {
        Invoke-Interactively -CommandUsed 'BeforeDiscovery' -ScriptName $PSCmdlet.MyInvocation.ScriptName -SessionState $PSCmdlet.SessionState -BoundParameters $PSCmdlet.MyInvocation.BoundParameters
    }
}

# Adding Add-ShouldOperator because it used to be an alias in v4, and so when we now import it will take precedence over
# our internal function in v5, so we need a safe way to refer to it
$script:SafeCommands['Add-ShouldOperator'] = & $SafeCommands['Get-Command'] -CommandType Function -Name 'Add-ShouldOperator'
