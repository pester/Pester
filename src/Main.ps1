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
    Can be merged into Add-ShouldOperator later if we'd like to make it pulic and include value in Get-ShouldOperator

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
    Windows PowerShell script, including typing the full path at the command line
    and running in a script editing program. Typically, you use Invoke-Pester to run
    all Pester tests in a directory, or to use its many helpful parameters,
    including parameters that generate custom objects or XML files.

    By default, Invoke-Pester runs all *.Tests.ps1 files in the current directory
    and all subdirectories recursively. You can use its parameters to select tests
    by file name, test name, or tag.

    To run Pester tests in scripts that take parameter values, use the Script
    parameter with a hash table value.

    Also, by default, Pester tests write test results to the console host, much like
    Write-Host does, but you can use the Show parameter set to None to suppress the host
    messages, use the PassThru parameter to generate a custom object
    (PSCustomObject) that contains the test results, use the OutputXml and
    OutputFormat parameters to write the test results to an XML file, and use the
    EnableExit parameter to return an exit code that contains the number of failed
    tests.

    You can also use the Strict parameter to fail all skipped tests.
    This feature is ideal for build systems and other processes that require success
    on every test.

    To help with test design, Invoke-Pester includes a CodeCoverage parameter that
    lists commands, classes, functions, and lines of code that did not run during test
    execution and returns the code that ran as a percentage of all tested code.

    Invoke-Pester, and the Pester module that exports it, are products of an
    open-source project hosted on GitHub. To view, comment, or contribute to the
    repository, see https://github.com/Pester.

    .PARAMETER CI
    (Introduced v5)
    Enable Test Results and Exit after Run.

    Replace with ConfigurationProperty
        TestResult.Enabled = $true
        Run.Exit = $true

    Since 5.2.0, this option no longer enables CodeCoverage.
    To also enable CodeCoverage use this configuration option:
        CodeCoverage.Enabled = $true

    .PARAMETER CodeCoverage
    (Deprecated v4)
    Replace with ConfigurationProperty CodeCoverage.Enabled = $true
    Adds a code coverage report to the Pester tests. Takes strings or hash table values.
    A code coverage report lists the lines of code that did and did not run during
    a Pester test. This report does not tell whether code was tested; only whether
    the code ran during the test.
    By default, the code coverage report is written to the host program
    (like Write-Host). When you use the PassThru parameter, the custom object
    that Invoke-Pester returns has an additional CodeCoverage property that contains
    a custom object with detailed results of the code coverage test, including lines
    hit, lines missed, and helpful statistics.
    However, NUnitXml and JUnitXml output (OutputXML, OutputFormat) do not include
    any code coverage information, because it's not supported by the schema.
    Enter the path to the files of code under test (not the test file).
    Wildcard characters are supported. If you omit the path, the default is local
    directory, not the directory specified by the Script parameter. Pester test files
    are by default excluded from code coverage when a directory is provided. When you
    provide a test file directly using string, code coverage will be measured. To include
    tests in code coverage of a directory, use the dictionary syntax and provide
    IncludeTests = $true option, as shown below.
    To run a code coverage test only on selected classes, functions or lines in a script,
    enter a hash table value with the following keys:
    -- Path (P)(mandatory) <string>: Enter one path to the files. Wildcard characters
    are supported, but only one string is permitted.
    -- IncludeTests <bool>: Includes code coverage for Pester test files (*.tests.ps1).
    Default is false.
    One of the following: Class/Function or StartLine/EndLine
    -- Class (C) <string>: Enter the class name. Wildcard characters are
    supported, but only one string is permitted. Default is *.
    -- Function (F) <string>: Enter the function name. Wildcard characters are
    supported, but only one string is permitted. Default is *.
    -or-
    -- StartLine (S): Performs code coverage analysis beginning with the specified
    line. Default is line 1.
    -- EndLine (E): Performs code coverage analysis ending with the specified line.
    Default is the last line of the script.

    .PARAMETER CodeCoverageOutputFile
    (Deprecated v4)
    Replace with ConfigurationProperty CodeCoverage.OutputPath
    The path where Invoke-Pester will save formatted code coverage results file.
    The path must include the location and name of the folder and file name with
    a required extension (usually the xml).
    If this path is not provided, no file will be generated.

    .PARAMETER CodeCoverageOutputFileEncoding
    (Deprecated v4)
    Replace with ConfigurationProperty CodeCoverage.OutputEncoding
    Sets the output encoding of CodeCoverageOutputFileFormat
    Default is utf8

    .PARAMETER CodeCoverageOutputFileFormat
    (Deprecated v4)
    Replace with ConfigurationProperty CodeCoverage.OutputFormat
    The name of a code coverage report file format.
    Default value is: JaCoCo.
    Currently supported formats are:
    - JaCoCo - this XML file format is compatible with Azure Devops, VSTS/TFS

    The ReportGenerator tool can be used to consolidate multiple reports and provide code coverage reporting.
    https://github.com/danielpalme/ReportGenerator

    .PARAMETER Configuration
    [PesterConfiguration] object for Advanced Configuration created using `New-PesterConfiguration`.
    For help on each option see about_PesterConfiguration or inspect the object.

    .PARAMETER Container
    Specifies one or more ContainerInfo-objects that define containers with tests.
    ContainerInfo-objects are generated using New-PesterContainer. Useful for
    scenarios where data-driven test are generated, e.g. parametrized test files.

    .PARAMETER EnableExit
    (Deprecated v4)
    Replace with ConfigurationProperty Run.Exit
    Will cause Invoke-Pester to exit with a exit code equal to the number of failed
    tests once all tests have been run. Use this to "fail" a build when any tests fail.

    .PARAMETER ExcludePath
    (Deprecated v4)
    Replace with ConfigurationProperty Run.ExcludePath

    .PARAMETER ExcludeTagFilter
    (Deprecated v4)
    Replace with ConfigurationProperty Filter.ExcludeTag

    .PARAMETER FullNameFilter
    (Deprecated v4)
    Replace with ConfigurationProperty Filter.FullName

    .PARAMETER Output
    (Deprecated v4)
    Replace with ConfigurationProperty Output.Verbosity
    Supports Diagnostic, Detailed, Normal, Minimal, None

    Default value is: Normal

    .PARAMETER OutputFile
    (Deprecated v4)
    Replace with ConfigurationProperty TestResult.OutputPath
    The path where Invoke-Pester will save formatted test results log file.
    The path must include the location and name of the folder and file name with
    the xml extension.
    If this path is not provided, no log will be generated.

    .PARAMETER OutputFormat
    (Deprecated v4)
    Replace with ConfigurationProperty TestResult.OutputFormat
    The format of output. Currently NUnitXml and JUnitXml is supported.

    .PARAMETER PassThru
    Replace with ConfigurationProperty Run.PassThru
    Returns a custom object (PSCustomObject) that contains the test results.
    By default, Invoke-Pester writes to the host program, not to the output stream (stdout).
    If you try to save the result in a variable, the variable is empty unless you
    use the PassThru parameter.
    To suppress the host output, use the Show parameter set to None.

    .PARAMETER Path
    Aliases Script
    Specifies one or more paths to files containing tests. The value is a path\file
    name or name pattern. Wildcards are permitted.

    .PARAMETER PesterOption
    (Deprecated v4)
    This parameter is ignored in v5, and is only present for backwards compatibility
    when migrating from v4.

    .PARAMETER Quiet
    (Deprecated v4)
    The parameter Quiet is deprecated since Pester v4.0 and will be deleted
    in the next major version of Pester. Please use the parameter Show
    with value 'None' instead.
    The parameter Quiet suppresses the output that Pester writes to the host program,
    including the result summary and CodeCoverage output.
    This parameter does not affect the PassThru custom object or the XML output that
    is written when you use the Output parameters.

    .PARAMETER Show
    (Deprecated v4)
    Replace with ConfigurationProperty Output.Verbosity
    Customizes the output Pester writes to the screen. Available options are None, Default,
    Passed, Failed, Skipped, Inconclusive, Describe, Context, Summary, Header, All, Fails.
    The options can be combined to define presets.
    ConfigurationProperty Output.Verbosity supports the following values:
    None
    Minimal
    Normal
    Detailed
    Diagnostic

    Show parameter supports the following parameter values:
    None - (None) to write no output to the screen.
    All - (Detailed) to write all available information (this is default option).
    Default - (Detailed)
    Detailed - (Detailed)
    Fails - (Normal) to write everything except Passed (but including Describes etc.).
    Diagnostic - (Diagnostic)
    Normal - (Normal)
    Minimal - (Minimal)

    A common setting is also Failed, Summary, to write only failed tests and test summary.
    This parameter does not affect the PassThru custom object or the XML output that
    is written when you use the Output parameters.

    .PARAMETER Strict
    (Deprecated v4)
    Makes Skipped tests to Failed tests. Useful for continuous
    integration where you need to make sure all tests passed.

    .PARAMETER TagFilter
    (Deprecated v4)
    Aliases Tag, Tags
    Replace with ConfigurationProperty Filter.Tag

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
        [Parameter(Position = 0, Mandatory = 0, ParameterSetName = "Legacy")]  # Legacy set for v4 compatibility during migration - deprecated
        [Alias("Script")] # Legacy set for v4 compatibility during migration - deprecated
        [String[]] $Path = '.',
        [Parameter(ParameterSetName = "Simple")]
        [String[]] $ExcludePath = @(),

        [Parameter(ParameterSetName = "Simple")]
        [Parameter(Position = 4, Mandatory = 0, ParameterSetName = "Legacy")]  # Legacy set for v4 compatibility during migration - deprecated
        [Alias("Tag")] # Legacy set for v4 compatibility during migration - deprecated
        [Alias("Tags")] # Legacy set for v4 compatibility during migration - deprecated
        [string[]] $TagFilter,

        [Parameter(ParameterSetName = "Simple")]
        [Parameter(ParameterSetName = "Legacy")] # Legacy set for v4 compatibility during migration - deprecated
        [string[]] $ExcludeTagFilter,

        [Parameter(Position = 1, Mandatory = 0, ParameterSetName = "Legacy")]  # Legacy set for v4 compatibility during migration - deprecated
        [Parameter(ParameterSetName = "Simple")]
        [Alias("Name")]  # Legacy set for v4 compatibility during migration - deprecated
        [string[]] $FullNameFilter,

        [Parameter(ParameterSetName = "Simple")]
        [Switch] $CI,

        [Parameter(ParameterSetName = "Simple")]
        [ValidateSet("Diagnostic", "Detailed", "Normal", "Minimal", "None")]
        [String] $Output = "Normal",

        [Parameter(ParameterSetName = "Simple")]
        [Parameter(ParameterSetName = "Legacy")] # Legacy set for v4 compatibility during migration - deprecated
        [Switch] $PassThru,

        [Parameter(ParameterSetName = "Simple")]
        [Pester.ContainerInfo[]] $Container,

        [Parameter(ParameterSetName = "Advanced")]
        [PesterConfiguration] $Configuration,

        # rest of the Legacy set
        [Parameter(Position = 2, Mandatory = 0, ParameterSetName = "Legacy", DontShow)]  # Legacy set for v4 compatibility during migration - deprecated
        [switch]$EnableExit,

        [Parameter(ParameterSetName = "Legacy", DontShow)] # Legacy set for v4 compatibility during migration - deprecated
        [object[]] $CodeCoverage = @(),

        [Parameter(ParameterSetName = "Legacy", DontShow)] # Legacy set for v4 compatibility during migration - deprecated
        [string] $CodeCoverageOutputFile,

        [Parameter(ParameterSetName = "Legacy", DontShow)] # Legacy set for v4 compatibility during migration - deprecated
        [string] $CodeCoverageOutputFileEncoding = 'utf8',

        [Parameter(ParameterSetName = "Legacy", DontShow)] # Legacy set for v4 compatibility during migration - deprecated
        [ValidateSet('JaCoCo')]
        [String]$CodeCoverageOutputFileFormat = "JaCoCo",

        [Parameter(ParameterSetName = "Legacy", DontShow)] # Legacy set for v4 compatibility during migration - deprecated
        [Switch]$Strict,

        [Parameter(ParameterSetName = "Legacy", DontShow)] # Legacy set for v4 compatibility during migration - deprecated
        [string] $OutputFile,

        [Parameter(ParameterSetName = "Legacy", DontShow)] # Legacy set for v4 compatibility during migration - deprecated
        [ValidateSet('NUnitXml', 'NUnit2.5', 'JUnitXml')]
        [string] $OutputFormat = 'NUnitXml',

        [Parameter(ParameterSetName = "Legacy", DontShow)] # Legacy set for v4 compatibility during migration - deprecated
        [Switch]$Quiet,

        [Parameter(ParameterSetName = "Legacy", DontShow)] # Legacy set for v4 compatibility during migration - deprecated
        [object]$PesterOption,

        [Parameter(ParameterSetName = "Legacy", DontShow)] # Legacy set for v4 compatibility during migration - deprecated
        [String] $Show = 'All'
    )
    begin {
        $start = [DateTime]::Now
        # this will inherit to child scopes and allow Describe / Context to run directly from a file or command line
        $invokedViaInvokePester = $true

        if ($null -eq $state) {
            # Cleanup any leftover mocks from previous runs, but only if we are not running in a nested Pester-run
            # todo: move mock cleanup to BeforeAllBlockContainer when there is any?
            Remove-MockFunctionsAndAliases -SessionState $PSCmdlet.SessionState
        }
        else {
            # this will inherit to child scopes and affect behavior of ex. TestDrive/TestRegistry
            $runningPesterInPester = $true
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
            elseif ('Legacy' -eq $PSCmdlet.ParameterSetName) {
                & $SafeCommands['Write-Warning'] 'You are using Legacy parameter set that adapts Pester 5 syntax to Pester 4 syntax. This parameter set is deprecated, and does not work 100%. The -Strict and -PesterOption parameters are ignored, and providing advanced configuration to -Path (-Script), and -CodeCoverage via a hash table does not work. Please refer to https://github.com/pester/Pester/releases/tag/5.0.1#legacy-parameter-set for more information.'

                # dot-sourcing the function to allow removing local variables
                $Configuration = . Convert-PesterLegacyParameterSet -BoundParameters $PSBoundParameters
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

            $r = Invoke-Test -BlockContainer $containers -Plugin $plugins -PluginConfiguration $pluginConfiguration -PluginData $pluginData -SessionState $sessionState -Filter $filter -Configuration $PesterPreference

            foreach ($c in $r) {
                Fold-Container -Container $c  -OnTest { param($t) Add-RSpecTestObjectProperties $t }
            }

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
            foreach ($i in @($r)) {
                $run.Containers.Add($i)
            }

            PostProcess-RSpecTestRun -TestRun $run

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
                    throw 'Passing hashtable configuration to -Path / -Script is currently not supported in Pester 5.0. Please provide just paths, as an array of strings.'
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

function Convert-PesterLegacyParameterSet ($BoundParameters) {
    $Configuration = [PesterConfiguration]::Default

    $migrations = @{
        'Path'                           = {
            if ($null -ne $Path) {
                $Configuration.Run.Path = $Path
            }
        }

        'FullNameFilter'                 = {
            if ($null -ne $FullNameFilter -and 0 -lt @($FullNameFilter).Count) {
                $Configuration.Filter.FullName = $FullNameFilter
            }
        }

        'EnableExit'                     = {
            if ($EnableExit) {
                $Configuration.Run.Exit = $true
            }
        }

        'TagFilter'                      = {
            if ($null -ne $TagFilter -and 0 -lt @($TagFilter).Count) {
                $Configuration.Filter.Tag = $TagFilter
            }
        }

        'ExcludeTagFilter'               = {
            if ($null -ne $ExcludeTagFilter -and 0 -lt @($ExcludeTagFilter).Count) {
                $Configuration.Filter.ExcludeTag = $ExcludeTagFilter
            }
        }

        'PassThru'                       = {
            if ($null -ne $PassThru) {
                $Configuration.Run.PassThru = [bool] $PassThru
            }
        }

        'CodeCoverage'                   = {
            # advanced CC options won't work (hashtable)
            if ($null -ne $CodeCoverage) {
                $Configuration.CodeCoverage.Enabled = $true
                $Configuration.CodeCoverage.Path = $CodeCoverage
            }
        }

        'CodeCoverageOutputFile'         = {
            if ($null -ne $CodeCoverageOutputFile) {
                $Configuration.CodeCoverage.Enabled = $true
                $Configuration.CodeCoverage.OutputPath = $CodeCoverageOutputFile
            }
        }

        'CodeCoverageOutputFileEncoding' = {
            if ($null -ne $CodeCoverageOutputFileEncoding) {
                $Configuration.CodeCoverage.Enabled = $true
                $Configuration.CodeCoverage.OutputEncoding = $CodeCoverageOutputFileEncoding
            }
        }

        'CodeCoverageOutputFileFormat'   = {
            if ($null -ne $CodeCoverageOutputFileFormat) {
                $Configuration.CodeCoverage.Enabled = $true
                $Configuration.CodeCoverage.OutputFormat = $CodeCoverageOutputFileFormat
            }
        }

        'OutputFile'                     = {
            if ($null -ne $OutputFile -and 0 -lt @($OutputFile).Count) {
                $Configuration.TestResult.Enabled = $true
                $Configuration.TestResult.OutputPath = $OutputFile
            }
        }

        'OutputFormat'                   = {
            if ($null -ne $OutputFormat -and 0 -lt @($OutputFormat).Count) {
                $Configuration.TestResult.OutputFormat = $OutputFormat
            }
        }

        'Show'                           = {
            if ($null -ne $Show) {
                # most used v4 options are adapted, and it also takes v5 options to be able to migrate gradually
                # without switching the whole param set just to get Diagnostic output
                # {None | Default | Passed | Failed | Skipped | Inconclusive | Describe | Context | Summary | Header | Fails | All}
                $verbosity = switch ($Show) {
                    'All' { 'Detailed' }
                    'Default' { 'Detailed' }
                    'Fails' { 'Normal' }
                    'Diagnostic' { 'Diagnostic' }
                    'Detailed' { 'Detailed' }
                    'Normal' { 'Normal' }
                    'Minimal' { 'Minimal' }
                    'None' { 'None' }
                    default { 'Detailed' }
                }

                $Configuration.Output.Verbosity = $verbosity
            }
        }

        'Quiet'                          = {
            if ($null -ne $Quiet) {
                if ($Quiet) {
                    $Configuration.Output.Verbosity = 'None'
                }
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

    # Remove auto null-variables for undefined parameters in set
    # TODO: Why are these special? Only removed when not defined, but they're never used. Other are only removed when expliclity set
    if (-not $BoundParameters.ContainsKey('Strict')) {
        & $SafeCommands['Get-Variable'] 'Strict' -Scope Local | Remove-Variable
    }

    if (-not $BoundParameters.ContainsKey('PesterOption')) {
        & $SafeCommands['Get-Variable'] 'PesterOption' -Scope Local | Remove-Variable
    }

    return $Configuration
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
