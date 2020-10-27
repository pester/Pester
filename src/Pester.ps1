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
    function BeAwesome($ActualValue, [switch] $Negate)
    {

        [bool] $succeeded = $ActualValue -eq 'Awesome'
        if ($Negate) { $succeeded = -not $succeeded }

        if (-not $succeeded)
        {
            if ($Negate)
            {
                $failureMessage = "{$ActualValue} is Awesome"
            }
            else
            {
                $failureMessage = "{$ActualValue} is not Awesome"
            }
        }

        return New-Object psobject -Property @{
            Succeeded      = $succeeded
            FailureMessage = $failureMessage
        }
    }

    Add-ShouldOperator -Name  BeAwesome `
                        -Test  $function:BeAwesome `
                        -Alias 'BA'

    PS C:\> "bad" | should -BeAwesome
    {bad} is not Awesome
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

    $entry = & $SafeCommands['New-Object'] psobject -Property @{
        Test               = $Test
        SupportsArrayInput = [bool]$SupportsArrayInput
        Name               = $Name
        Alias              = $Alias
        InternalName       = If ($InternalName) {
            $InternalName
        }
        Else {
            $Name
        }
    }
    if (Test-AssertionOperatorIsDuplicate -Operator $entry) {
        # This is an exact duplicate of an existing assertion operator.
        return
    }

    $namesToCheck = @(
        $Name
        $Alias
    )

    Assert-AssertionOperatorNameIsUnique -Name $namesToCheck

    $script:AssertionOperators[$Name] = $entry

    foreach ($string in $Alias | & $SafeCommands['Where-Object'] { -not ([string]::IsNullOrWhiteSpace($_))}) {
        Assert-ValidAssertionAlias -Alias $string
        $script:AssertionAliases[$string] = $Name
    }

    Add-AssertionDynamicParameterSet -AssertionEntry $entry
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

    foreach ($string in $name | & $SafeCommands['Where-Object'] { -not ([string]::IsNullOrWhiteSpace($_))}) {
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

    $attribute = & $SafeCommands['New-Object'] Management.Automation.ParameterAttribute
    $attribute.ParameterSetName = $AssertionEntry.Name

    $attributeCollection = & $SafeCommands['New-Object'] Collections.ObjectModel.Collection[Attribute]
    $null = $attributeCollection.Add($attribute)
    if (-not ([string]::IsNullOrWhiteSpace($AssertionEntry.Alias))) {
        Assert-ValidAssertionAlias -Alias $AssertionEntry.Alias
        $attribute = & $SafeCommands['New-Object'] System.Management.Automation.AliasAttribute($AssertionEntry.Alias)
        $attributeCollection.Add($attribute)
    }

    $dynamic = & $SafeCommands['New-Object'] System.Management.Automation.RuntimeDefinedParameter($AssertionEntry.Name, [switch], $attributeCollection)
    $null = $script:AssertionDynamicParams.Add($AssertionEntry.Name, $dynamic)

    if ($script:AssertionDynamicParams.ContainsKey('Not')) {
        $dynamic = $script:AssertionDynamicParams['Not']
    }
    else {
        $dynamic = & $SafeCommands['New-Object'] System.Management.Automation.RuntimeDefinedParameter('Not', [switch], (& $SafeCommands['New-Object'] System.Collections.ObjectModel.Collection[Attribute]))
        $null = $script:AssertionDynamicParams.Add('Not', $dynamic)
    }

    $attribute = & $SafeCommands['New-Object'] System.Management.Automation.ParameterAttribute
    $attribute.ParameterSetName = $AssertionEntry.Name
    $attribute.Mandatory = $false
    $null = $dynamic.Attributes.Add($attribute)

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

            $dynamic = & $SafeCommands['New-Object'] System.Management.Automation.RuntimeDefinedParameter($parameter.Name, $type, (& $SafeCommands['New-Object'] System.Collections.ObjectModel.Collection[Attribute]))
            $null = $script:AssertionDynamicParams.Add($parameter.Name, $dynamic)
        }

        $attribute = & $SafeCommands['New-Object'] Management.Automation.ParameterAttribute
        $attribute.ParameterSetName = $AssertionEntry.Name
        $attribute.Mandatory = $false
        $attribute.Position = ($i++)

        $null = $dynamic.Attributes.Add($attribute)
    }
}

function Get-AssertionOperatorEntry([string] $Name) {
    return $script:AssertionOperators[$Name]
}

function Get-AssertionDynamicParams {
    return $script:AssertionDynamicParams
}

function Has-Flag {
    param
    (
        [Parameter(Mandatory = $true)]
        [Pester.OutputTypes]
        $Setting,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Pester.OutputTypes]
        $Value
    )

    0 -ne ($Setting -band $Value)
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

    You can also use the Strict parameter to fail all pending and skipped tests.
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
    Enable Code Coverage, Test Results and Exit after Run

    Replace with ConfigurationProperty
        CodeCoverage.Enabled = $true
        TestResult.Enabled = $true
        Run.Exit = $true

    .PARAMETER CodeCoverage
    (Deprecated v4)
    Replace with ConfigurationProperty CodeCoverage.Enabled = $true
    Adds a code coverage report to the Pester tests. Takes strings or hash table values.
    A code coverage report lists the lines of code that did and did not run during
    a Pester test. This report does not tell whether code was tested; only whether
    the code ran during the test.
    By default, the code coverage report is written to the host program
    (like Write-Host). When you use the PassThru parameter, the custom object
    that Invoke-Pester returns has an additional CodeCoverage property that contains
    a custom object with detailed results of the code coverage test, including lines
    hit, lines missed, and helpful statistics.
    However, NUnitXml and JUnitXml output (OutputXML, OutputFormat) do not include
    any code coverage information, because it's not supported by the schema.
    Enter the path to the files of code under test (not the test file).
    Wildcard characters are supported. If you omit the path, the default is local
    directory, not the directory specified by the Script parameter. Pester test files
    are by default excluded from code coverage when a directory is provided. When you
    provide a test file directly using string, code coverage will be measured. To include
    tests in code coverage of a directory, use the dictionary syntax and provide
    IncludeTests = $true option, as shown below.
    To run a code coverage test only on selected classes, functions or lines in a script,
    enter a hash table value with the following keys:
    -- Path (P)(mandatory) <string>: Enter one path to the files. Wildcard characters
    are supported, but only one string is permitted.
    -- IncludeTests <bool>: Includes code coverage for Pester test files (*.tests.ps1).
    Default is false.
    One of the following: Class/Function or StartLine/EndLine
    -- Class (C) <string>: Enter the class name. Wildcard characters are
    supported, but only one string is permitted. Default is *.
    -- Function (F) <string>: Enter the function name. Wildcard characters are
    supported, but only one string is permitted. Default is *.
    -or-
    -- StartLine (S): Performs code coverage analysis beginning with the specified
    line. Default is line 1.
    -- EndLine (E): Performs code coverage analysis ending with the specified line.
    Default is the last line of the script.

    .PARAMETER CodeCoverageOutputFile
    (Deprecated v4)
    The path where Invoke-Pester will save formatted code coverage results file.
    The path must include the location and name of the folder and file name with
    a required extension (usually the xml).
    If this path is not provided, no file will be generated.

    .PARAMETER CodeCoverageOutputFileEncoding
    (Deprecated v4)
    Replace with ConfigurationProperty CodeCoverage.CodeCoverageOutputFileEncoding
    Sets the output encoding of CodeCoverageOutputFileFormat
    Default is utf8

    .PARAMETER CodeCoverageOutputFileFormat
    (Deprecated v4)
    Replace with ConfigurationProperty CodeCoverage.CodeCoverageOutputFileFormat
    The name of a code coverage report file format.
    Default value is: JaCoCo.
    Currently supported formats are:
    - JaCoCo - this XML file format is compatible with Azure Devops, VSTS/TFS

    The ReportGenerator tool can be used to consolidate multiple reports and provide code coverage reporting.
    https://github.com/danielpalme/ReportGenerator

    .PARAMETER Configuration
    (Introduced v5)
    [PesterConfiguration] object for Advanced Configuration

    Pester supports Simple and Advanced Configuration.

    Invoke-Pester -Configuration <PesterConfiguration> [<CommonParameters>]

    Default is [PesterConfiguration]::Default

    ConfigurationProperties include following:

    [PesterConfiguration]::Default.Run
    ---
    Run.ExcludePath - Directories or files to be excluded from the run.
    Run.Exit - Exit with non-zero exit code when the test run fails.
        Default is: false
    Run.PassThru - Return result object to the pipeline after finishing the test run.
        Default is: false
    Run.Path - Directories to be searched for tests, paths directly to test files, or combination of both.
        Default is: .
    Run.ScriptBlock - ScriptBlocks containing tests to be executed.
    Run.TestExtension - Filter used to identify test files.
        Default is: *.Tests.ps1*
    Output.Verbosity - The verbosity of output, options are None, Normal, Detailed and Diagnostic.
        Default is: Normal

    [PesterConfiguration]::Default.CodeCoverage
    ------------
    CodeCoverage.Enabled - Enable CodeCoverage.
        Default is: false
    CodeCoverage.OutputFormat - Format to use for code coverage report. Possible values: JaCoCo
    CodeCoverage.OutputPath - Path relative to the current directory where code coverage report is saved.
        Default is: coverage.xml
    CodeCoverage.OutputEncoding - Encoding of the output file. Currently UTF8
    CodeCoverage.Path - Directories or files to be used for codecoverage, by default the Path(s) from general settings are used, unless overridden here.
    CodeCoverage.ExcludeTests - Exclude tests from code coverage. This uses the TestFilter from general configuration.
        Default is: true

    [PesterConfiguration]::Default.TestResult
    ----------
    TestResult.Enabled - Enable TestResult.
    TestResult.OutputFormat - Format to use for test result report. Possible values: NUnit2.5
    TestResult.OutputPath - Path relative to the current directory where test result report is saved.
        Default is: testResults.xml
    TestResult.OutputEncoding - Encoding of the output file. Currently UTF8
    TestResult.TestSuiteName - Set the name assigned to the root 'test-suite' element.
        Default is: Pester

    [PesterConfiguration]::Default.Filter
    ------
    Filter.ExcludeTag - Exclude a tag, accepts wildcards
    Filter.FullName - Full name of test with -like wildcards, joined by dot. Example: '*.describe Get-Item.test1'
    Filter.Line - Filter by file and scriptblock start line, useful to run parsed tests programatically to avoid problems with expanded names. Example: 'C:\tests\file1.Tests.ps1:37'
    Filter.Tag - Tags of Describe, Context or It to be run.
    Should.ErrorAction - Controls if Should throws on error. Use 'Stop' to throw on error, or 'Continue' to fail at the end of the test.

    [PesterConfiguration]::Default.Debug
    -----
    Debug.ShowFullErrors - Show full errors including Pester internal stack.
    Debug.ShowNavigationMarkers - Write paths after every block and test, for easy navigation in VSCode.
    Debug.WriteDebugMessages - Write Debug messages to screen.
    Debug.WriteDebugMessagesFrom - Write Debug messages from a given source, WriteDebugMessages must be set to true for this to work. You can use like wildcards to get messages from multiple sources, as well as * to get everything.
        Available options: "Discovery", "Skip", "Filter", "Mock", "CodeCoverage"

    .PARAMETER EnableExit
    (Deprecated v4)
    Replace with ConfigurationProperty Run.EnableExit
    Will cause Invoke-Pester to exit with a exit code equal to the number of failed
    tests once all tests have been run. Use this to "fail" a build when any tests fail.

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
    Replace with ConfigurationProperty TestResult.OutputFile
    The path where Invoke-Pester will save formatted test results log file.
    The path must include the location and name of the folder and file name with
    the xml extension.
    If this path is not provided, no log will be generated.

    .PARAMETER OutputFormat
    (Deprecated v4)
    Replace with ConfigurationProperty TestResult.OutputFormat
    The format of output. Currently NUnitXml is supported.
    Note that JUnitXml is not currently supported in Pester 5.

    .PARAMETER PassThru
    Replace with ConfigurationProperty Run.PassThru
    Returns a custom object (PSCustomObject) that contains the test results.
    By default, Invoke-Pester writes to the host program, not to the output stream (stdout).
    If you try to save the result in a variable, the variable is empty unless you
    use the PassThru parameter.
    To suppress the host output, use the Show parameter set to None.

    .PARAMETER Path
    Aliases Script
    Specifies a test to run. The value is a path\file
    name or name pattern. Wildcards are permitted. All hash tables in a Script
    parameter values must have a Path key.

    .PARAMETER PesterOption
    (Deprecated v4)
    Sets advanced options for the test execution. Enter a PesterOption object,
    such as one that you create by using the New-PesterOption cmdlet, or a hash table
    in which the keys are option names and the values are option values.
    For more information on the options available, see the help for New-PesterOption.

    .PARAMETER Quiet
    (Deprecated v4)
    The parameter Quiet is deprecated since Pester v4.0 and will be deleted
    in the next major version of Pester. Please use the parameter Show
    with value 'None' instead.
    The parameter Quiet suppresses the output that Pester writes to the host program,
    including the result summary and CodeCoverage output.
    This parameter does not affect the PassThru custom object or the XML output that
    is written when you use the Output parameters.

    .PARAMETER Show
    (Deprecated v4)
    Replace with ConfigurationProperty Output.Verbosity
    Customizes the output Pester writes to the screen. Available options are None, Default,
    Passed, Failed, Pending, Skipped, Inconclusive, Describe, Context, Summary, Header, All, Fails.
    The options can be combined to define presets.
    ConfigurationProperty Output.Verbosity supports the following values:
    None
    Minimal
    Normal
    Detailed
    Diagnostic

    Show parameter supports the following parameter values:
    None - (None) to write no output to the screen.
    All - (Detailed) to write all available information (this is default option).
    Default - (Detailed)
    Detailed - (Detailed)
    Fails - (Normal) to write everything except Passed (but including Describes etc.).
    Diagnostic - (Diagnostic)
    Normal - (Normal)
    Minimal - (Minimal)

    A common setting is also Failed, Summary, to write only failed tests and test summary.
    This parameter does not affect the PassThru custom object or the XML output that
    is written when you use the Output parameters.

    .PARAMETER Strict
    (Deprecated v4)
    Makes Pending and Skipped tests to Failed tests. Useful for continuous
    integration where you need to make sure all tests passed.

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
    $config = [PesterConfiguration]@{
    Should = @{ <- # Should configuration.
        ErrorAction = 'Stop' # <- "Controls if Should throws on error."
        }
    }

    Invoke-Pester -Configuration $config

    .EXAMPLE
    $config = [PesterConfiguration]::Default

    Invoke-Pester -Configuration $config

    .LINK
    https://pester.dev/docs/quick-start

    .LINK
    https://pester.dev/docs/commands/Invoke-Pester

    .LINK
    https://pswiki.net/invoke-pester-pester/

    .LINK
    Describe
    about_Pester
    #>
    # Currently doesn't work. $IgnoreUnsafeCommands filter used in rule as workaround
    # [Diagnostics.CodeAnalysis.SuppressMessageAttribute('Pester.BuildAnalyzerRules\Measure-SafeComands', 'Remove-Variable', Justification = 'Remove-Variable can't remove "optimized variables" when using "alias" for Remove-Variable.')]
    [CmdletBinding(DefaultParameterSetName = 'Simple')]
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
        [Pester.TestContainer[]] $Container,

        [Parameter(ParameterSetName = "Advanced")]
        [PesterConfiguration] $Configuration,

        # rest of the Legacy set
        [Parameter(Position = 2, Mandatory = 0, ParameterSetName = "Legacy")]  # Legacy set for v4 compatibility during migration - deprecated
        [switch]$EnableExit,

        [Parameter(ParameterSetName = "Legacy")] # Legacy set for v4 compatibility during migration - deprecated
        [object[]] $CodeCoverage = @(),

        [Parameter(ParameterSetName = "Legacy")] # Legacy set for v4 compatibility during migration - deprecated
        [string] $CodeCoverageOutputFile,

        [Parameter(ParameterSetName = "Legacy")] # Legacy set for v4 compatibility during migration - deprecated
        [string] $CodeCoverageOutputFileEncoding = 'utf8',

        [Parameter(ParameterSetName = "Legacy")] # Legacy set for v4 compatibility during migration - deprecated
        [ValidateSet('JaCoCo')]
        [String]$CodeCoverageOutputFileFormat = "JaCoCo",

        [Parameter(ParameterSetName = "Legacy")] # Legacy set for v4 compatibility during migration - deprecated
        [Switch]$Strict,

        [Parameter(ParameterSetName = "Legacy")] # Legacy set for v4 compatibility during migration - deprecated
        [string] $OutputFile,

        [Parameter(ParameterSetName = "Legacy")] # Legacy set for v4 compatibility during migration - deprecated
        [ValidateSet('NUnitXml', 'JUnitXml')]
        [string] $OutputFormat = 'NUnitXml',

        [Parameter(ParameterSetName = "Legacy")] # Legacy set for v4 compatibility during migration - deprecated
        [Switch]$Quiet,

        [Parameter(ParameterSetName = "Legacy")] # Legacy set for v4 compatibility during migration - deprecated
        [object]$PesterOption,

        [Parameter(ParameterSetName = "Legacy")] # Legacy set for v4 compatibility during migration - deprecated
        [Pester.OutputTypes]$Show = 'All'
    )
    begin {
        $start = [DateTime]::Now
        # this will inherit to child scopes and allow Describe / Context to run directly from a file or command line
        $invokedViaInvokePester = $true

        # TODO: Remove all references to mock table, there should not be many.
        $script:mockTable = @{}
        # todo: move mock cleanup to BeforeAllBlockContainer when there is any
        Remove-MockFunctionsAndAliases
    }

    end {
        try {
            if ('Simple' -eq $PSCmdlet.ParameterSetName) {
                # populate config from parameters and remove them so we
                # don't inherit them to child functions by accident

                $Configuration = [PesterConfiguration]::Default

                if ($PSBoundParameters.ContainsKey('Path')) {
                    if ($null -ne $Path) {
                        if (@($Path)[0] -is [System.Collections.IDictionary]) {
                            throw "Passing hashtable configuration to -Path / -Script is currently not supported in Pester 5.0. Please provide just paths, as an array of strings."
                        }

                        $Configuration.Run.Path = $Path
                    }

                    & $SafeCommands['Get-Variable'] 'Path' -Scope Local | Remove-Variable
                }

                if ($PSBoundParameters.ContainsKey('ExcludePath')) {
                    if ($null -ne $ExcludePath) {
                        $Configuration.Run.ExcludePath = $ExcludePath
                    }

                    & $SafeCommands['Get-Variable'] 'ExcludePath' -Scope Local | Remove-Variable
                }

                if ($PSBoundParameters.ContainsKey('TagFilter')) {
                    if ($null -ne $TagFilter -and 0 -lt @($TagFilter).Count) {
                        $Configuration.Filter.Tag = $TagFilter
                    }

                    & $SafeCommands['Get-Variable'] 'TagFilter' -Scope Local | Remove-Variable
                }

                if ($PSBoundParameters.ContainsKey('ExcludeTagFilter')) {
                    if ($null -ne $ExcludeTagFilter -and 0 -lt @($ExludeTagFilter).Count) {
                        $Configuration.Filter.ExcludeTag = $ExcludeTagFilter
                    }

                    & $SafeCommands['Get-Variable'] 'ExcludeTagFilter' -Scope Local | Remove-Variable
                }

                if ($PSBoundParameters.ContainsKey('FullNameFilter')) {
                    if ($null -ne $FullNameFilter -and 0 -lt @($FullNameFilter).Count){
                        $Configuration.Filter.FullName = $FullNameFilter
                    }

                    & $SafeCommands['Get-Variable'] 'FullNameFilter' -Scope Local | Remove-Variable
                }

                if ($PSBoundParameters.ContainsKey('CI')) {
                    if ($CI) {
                        $Configuration.Run.Exit = $true
                        $Configuration.CodeCoverage.Enabled = $true
                        $Configuration.TestResult.Enabled = $true
                    }

                    & $SafeCommands['Get-Variable'] 'CI' -Scope Local | Remove-Variable
                }

                if ($PSBoundParameters.ContainsKey('Output')) {
                    if ($null -ne $Output) {
                        $Configuration.Output.Verbosity = $Output
                    }

                    & $SafeCommands['Get-Variable'] 'Output' -Scope Local | Remove-Variable
                }

                if ($PSBoundParameters.ContainsKey('PassThru')) {
                    if ($null -ne $PassThru) {
                        $Configuration.Run.PassThru = [bool] $PassThru
                    }

                    & $SafeCommands['Get-Variable'] 'PassThru' -Scope Local | Remove-Variable
                }


                if ($PSBoundParameters.ContainsKey('Container')) {
                    # expand from the public Pester.TestContainer, or more likely Pester.TestPath types to ContainerInfo
                    # the public types can hold multiple sets of data, ContainerInfo can hold only one to keep the internal
                    # logic simple.
                    if ($null -ne $Container) {
                        $cs = @()

                        foreach ($c in $Container) {
                            $data = $c.Data
                            if ($c -is [Pester.TestScriptBlock]) {
                                foreach ($d in @($data)) {
                                    $cs += New-BlockContainerObject -ScriptBlock $c.ScriptBlock -Data $d
                                }
                            }

                            if ($c -is [Pester.TestPath]) {
                                foreach ($d in $data) {
                                    # resolve the path we are given in the same way we would resolve -Path
                                    $files = @(Find-File -Path $c.Path -ExcludePath $PesterPreference.Run.ExcludePath.Value -Extension $PesterPreference.Run.TestExtension.Value)
                                    foreach ($file in $files) {
                                        $cs += New-BlockContainerObject -File $file -Data $d
                                    }
                                }
                            }
                        }

                        $Configuration.Run.Container = $cs
                    }

                    & $SafeCommands['Get-Variable'] 'Container' -Scope Local | Remove-Variable
                }
            }

            if ('Legacy' -eq $PSCmdlet.ParameterSetName) {
                & $SafeCommands['Write-Warning'] "You are using Legacy parameter set that adapts Pester 5 syntax to Pester 4 syntax. This parameter set is deprecated, and does not work 100%. The -Strict and -PesterOption parameters are ignored, and providing advanced configuration to -Path (-Script), and -CodeCoverage via a hash table does not work. Please refer to https://github.com/pester/Pester/releases/tag/5.0.1#legacy-parameter-set for more information."
                # populate config from parameters and remove them so we
                # don't inherit them to child functions by accident

                $Configuration = [PesterConfiguration]::Default

                if ($PSBoundParameters.ContainsKey('Path')) {
                    if ($null -ne $Path) {
                        $Configuration.Run.Path = $Path
                    }

                    & $SafeCommands['Get-Variable'] 'Path' -Scope Local | Remove-Variable
                }

                if ($PSBoundParameters.ContainsKey('FullNameFilter')) {
                    if ($null -ne $FullNameFilter -and 0 -lt @($FullNameFilter).Count){
                        $Configuration.Filter.FullName = $FullNameFilter
                    }

                    & $SafeCommands['Get-Variable'] 'FullNameFilter' -Scope Local | Remove-Variable
                }

                if ($PSBoundParameters.ContainsKey('EnableExit')) {
                    if ($EnableExit) {
                        $Configuration.Run.Exit = $true
                    }

                    & $SafeCommands['Get-Variable'] 'EnableExit' -Scope Local | Remove-Variable
                }

                if ($PSBoundParameters.ContainsKey('TagFilter')) {
                    if ($null -ne $TagFilter -and 0 -lt @($TagFilter).Count) {
                        $Configuration.Filter.Tag = $TagFilter
                    }

                    & $SafeCommands['Get-Variable'] 'TagFilter' -Scope Local | Remove-Variable
                }

                if ($PSBoundParameters.ContainsKey('ExcludeTagFilter')) {
                    if ($null -ne $ExcludeTagFilter -and 0 -lt @($ExludeTagFilter).Count) {
                        $Configuration.Filter.ExcludeTag = $ExcludeTagFilter
                    }

                    & $SafeCommands['Get-Variable'] 'ExcludeTagFilter' -Scope Local | Remove-Variable
                }

                if ($PSBoundParameters.ContainsKey('PassThru')) {
                    if ($null -ne $PassThru) {
                        $Configuration.Run.PassThru = [bool] $PassThru
                    }

                    & $SafeCommands['Get-Variable'] 'PassThru' -Scope Local | Remove-Variable
                }

                if ($PSBoundParameters.ContainsKey('CodeCoverage')) {

                    # advanced CC options won't work (hashtable)
                    if ($null -ne $CodeCoverage) {
                        $Configuration.CodeCoverage.Enabled = $true
                        $Configuration.CodeCoverage.Path = $CodeCoverage
                    }

                    & $SafeCommands['Get-Variable'] 'CodeCoverage' -Scope Local | Remove-Variable
                }

                if ($PSBoundParameters.ContainsKey('CodeCoverageOutputFile')) {
                    if ($null -ne $CodeCoverageOutputFile) {
                        $Configuration.CodeCoverage.Enabled = $true
                        $Configuration.CodeCoverage.OutputPath = $CodeCoverageOutputFile
                    }

                    & $SafeCommands['Get-Variable'] 'CodeCoverageOutputFile' -Scope Local | Remove-Variable
                }

                if ($PSBoundParameters.ContainsKey('CodeCoverageOutputFileEncoding')) {
                    if ($null -ne $CodeCoverageOutputFileEncoding) {
                        $Configuration.CodeCoverage.Enabled = $true
                        $Configuration.CodeCoverage.OutputEncoding = $CodeCoverageOutputFileEncoding
                    }

                    & $SafeCommands['Get-Variable'] 'CodeCoverageOutputFileEncoding' -Scope Local | Remove-Variable
                }

                if ($PSBoundParameters.ContainsKey('CodeCoverageOutputFileFormat')) {
                    if ($null -ne $CodeCoverageOutputFileFormat) {
                        $Configuration.CodeCoverage.Enabled = $true
                        $Configuration.CodeCoverage.OutputFormat = $CodeCoverageOutputFileFormat
                    }

                    & $SafeCommands['Get-Variable'] 'CodeCoverageOutputFileFormat' -Scope Local | Remove-Variable
                }

                if (-not $PSBoundParameters.ContainsKey('Strict')) {
                    & $SafeCommands['Get-Variable'] 'Strict' -Scope Local | Remove-Variable
                }

                if (-not $PSBoundParameters.ContainsKey('PesterOption')) {
                    & $SafeCommands['Get-Variable'] 'PesterOption' -Scope Local | Remove-Variable
                }

                if ($PSBoundParameters.ContainsKey('OutputFile')) {
                    if ($null -ne $OutputFile -and 0 -lt @($OutputFile).Count){
                        $Configuration.TestResult.Enabled = $true
                        $Configuration.TestResult.OutputPath = $OutputFile
                    }

                    & $SafeCommands['Get-Variable'] 'OutputFile' -Scope Local | Remove-Variable
                }

                if ($PSBoundParameters.ContainsKey('OutputFormat')) {
                    if ($null -ne $OutputFormat -and 0 -lt @($OutputFormat).Count) {
                        if ("JUnitXml" -eq $OutputFormat) {
                            throw "JUnitXml is currently not supported in Pester 5."
                        }

                        $Configuration.TestResult.OutputFormat = $OutputFormat
                    }

                    & $SafeCommands['Get-Variable'] 'OutputFormat' -Scope Local | Remove-Variable
                }

                if ($PSBoundParameters.ContainsKey('Show')) {
                    if ($null -ne $Show) {
                        # most used v4 options are adapted, and it also takes v5 options to be able to migrate gradually
                        # without switching the whole param set just to get Diagnostic output
                        # {None | Default | Passed | Failed | Pending | Skipped | Inconclusive | Describe | Context | Summary | Header | Fails | All}
                        $verbosity = switch ($Show) {
                            "All" { "Detailed" }
                            "Default" { "Detailed" }
                            "Fails" { "Normal" }
                            "Diagnostic" { "Diagnostic" }
                            "Detailed" { "Detailed" }
                            "Normal" { "Normal" }
                            "Minimal" { "Minimal" }
                            "None" { "None" }
                            default { "Detailed" }
                        }

                        $Configuration.Output.Verbosity = $verbosity
                    }

                    & $SafeCommands['Get-Variable'] 'Quiet' -Scope Local | Remove-Variable
                }

                if ($PSBoundParameters.ContainsKey('Quiet')) {
                    if ($null -ne $Quiet) {
                        if ($Quiet) {
                            $Configuration.Output.Verbosity = 'None'
                        }
                    }

                    & $SafeCommands['Get-Variable'] 'Quiet' -Scope Local | Remove-Variable
                }
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
                [PesterConfiguration] $PesterPreference = $Configuration
            }
            elseif ($hasCallerPreference) {
                [PesterConfiguration] $PesterPreference = [PesterConfiguration]::Merge($callerPreference, $Configuration)
            }

            & $SafeCommands['Get-Variable'] 'Configuration' -Scope Local | Remove-Variable

            # $sessionState = Set-SessionStateHint -PassThru  -Hint "Caller - Captured in Invoke-Pester" -SessionState $PSCmdlet.SessionState
            $sessionState = $PSCmdlet.SessionState

            $pluginConfiguration = @{}
            $plugins = @()
            if ('None' -ne $PesterPreference.Output.Verbosity.Value) {
                $plugins += Get-WriteScreenPlugin -Verbosity $PesterPreference.Output.Verbosity.Value
            }

            if ('Diagnostic' -eq $PesterPreference.Output.Verbosity.Value) {
                $PesterPreference.Debug.WriteDebugMessages = $true
                $PesterPreference.Debug.WriteDebugMessagesFrom = "Discovery", "Skip", "Filter", "Mock", "CodeCoverage"
            }

            $plugins +=
            @(
                # decorator plugin needs to be added after output
                # because on teardown they will run in opposite order
                # and that way output can consume the fixed object that decorator
                # decorated, not nice but works
                Get-RSpecObjectDecoratorPlugin
                Get-TestDrivePlugin
            )

            if ("Windows" -eq (GetPesterOs)) {
                $plugins += @(Get-TestRegistryPlugin)
            }

            $plugins +=  @(Get-MockPlugin)

            if ($PesterPreference.CodeCoverage.Enabled.Value) {
                $paths = @(if (0 -lt $PesterPreference.CodeCoverage.Path.Value.Count) {
                        $PesterPreference.CodeCoverage.Path.Value
                    }
                    else {
                        # no paths specific to CodeCoverage were provided, resolve them from
                        # tests by using the whole directory in which the test or the
                        # provided directory. We might need another option to disable this convention.
                        @(foreach ($p in $PesterPreference.Run.Path.Value) {
                            # this is a bit ugly, but the logic here is
                            # that we check if the path exists,
                            # and if it does and is a file then we return the
                            # parent directory, otherwise we got a directory
                            # and return just it
                            $i = & $SafeCommands['Get-Item'] $p
                            if ($i.PSIsContainer) {
                                & $SafeCommands['Join-Path'] $i.FullName "*"
                            }
                            else {
                                & $SafeCommands['Join-Path'] $i.Directory.FullName "*"
                            }
                        })
                    })

                $outputPath = if ([IO.Path]::IsPathRooted($PesterPreference.CodeCoverage.OutputPath.Value)) {
                        $PesterPreference.CodeCoverage.OutputPath.Value
                    }
                    else {
                        & $SafeCommands['Join-Path'] $pwd.Path $PesterPreference.CodeCoverage.OutputPath.Value
                    }

                $CodeCoverage = @{
                    Enabled = $PesterPreference.CodeCoverage.Enabled.Value
                    OutputFormat = $PesterPreference.CodeCoverage.OutputFormat.Value
                    OutputPath = $outputPath
                    OutputEncoding = $PesterPreference.CodeCoverage.OutputEncoding.Value
                    ExcludeTests = $PesterPreference.CodeCoverage.ExcludeTests.Value
                    Path = @($paths)
                    TestExtension = $PesterPreference.Run.TestExtension.Value
                }

                $plugins += (Get-CoveragePlugin)
                $pluginConfiguration["Coverage"] = $CodeCoverage
            }

            $filter = New-FilterObject `
                -Tag $PesterPreference.Filter.Tag.Value `
                -ExcludeTag $PesterPreference.Filter.ExcludeTag.Value `
                -Line $PesterPreference.Filter.Line.Value `
                -FullName $PesterPreference.Filter.FullName.Value

            $containers = @()
            if (any $PesterPreference.Run.ScriptBlock.Value) {
                $containers += @( $PesterPreference.Run.ScriptBlock.Value | & $SafeCommands['ForEach-Object'] { New-BlockContainerObject -ScriptBlock $_ })
            }

            foreach ($c in $PesterPreference.Run.Container.Value) {
                $containers += $c
            }

            if ((any $PesterPreference.Run.Path.Value)) {
                if (((none $PesterPreference.Run.ScriptBlock.Value) -and (none $PesterPreference.Run.Container.Value)) -or ('.' -ne $PesterPreference.Run.Path.Value[0])) {
                    #TODO: Skipping the invocation when scriptblock is provided and the default path, later keep path in the default parameter set and remove scriptblock from it, so get-help still shows . as the default value and we can still provide script blocks via an advanced settings parameter
                    # TODO: pass the startup options as context to Start instead of just paths

                    $exclusions = combineNonNull @($PesterPreference.Run.ExcludePath.Value, ($PesterPreference.Run.Container.Value | & $SafeCommands['Where-Object'] { "File" -eq $_.Type } | & $SafeCommands['ForEach-Object'] {$_.Item.FullName }))
                    $containers += @(Find-File -Path $PesterPreference.Run.Path.Value -ExcludePath $exclusions -Extension $PesterPreference.Run.TestExtension.Value | & $SafeCommands['ForEach-Object'] { New-BlockContainerObject -File $_ })
                }
            }

            # monkey patching that we need global data for code coverage, this is problematic because code coverage should be setup once for the whole run, but because at the start everything was separated on container level the discovery is not done at this point, and we don't have any info about the containers apart from the path, or scriptblock content
            $pluginData = @{}

            $steps = $Plugins.Start
            if ($null -ne $steps -and 0 -lt @($steps).Count) {
                Invoke-PluginStep -Plugins $Plugins -Step Start -Context @{
                    Containers = $containers
                    Configuration = $pluginConfiguration
                    GlobalPluginData = $pluginData
                    WriteDebugMessages = $PesterPreference.Debug.WriteDebugMessages.Value
                    Write_PesterDebugMessage = if ($PesterPreference.Debug.WriteDebugMessages) { $script:SafeCommands['Write-PesterDebugMessage'] }
                } -ThrowOnFailure
            }

            if ((none $containers)) {
                throw "No test files were found and no scriptblocks were provided."
                return
            }

            $r = Invoke-Test -BlockContainer $containers -Plugin $plugins -PluginConfiguration $pluginConfiguration -SessionState $sessionState -Filter $filter -Configuration $PesterPreference

            foreach ($c in $r) {
                Fold-Container -Container $c  -OnTest { param($t) Add-RSpecTestObjectProperties $t }
            }

            $parameters = @{
                PSBoundParameters = $PSBoundParameters
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
            $run.Version = if ($m.PrivateData -and $m.PrivateData.PSData -and $m.PrivateData.PSData.PreRelease)
            {
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
                    TestRun = $run
                    Configuration = $pluginConfiguration
                } -ThrowOnFailure
            }

            if ($PesterPreference.TestResult.Enabled.Value) {
                Export-NunitReport $run $PesterPreference.TestResult.OutputPath.Value
            }

            if ($PesterPreference.CodeCoverage.Enabled.Value) {
                $breakpoints = @($run.PluginData.Coverage.CommandCoverage)
                $coverageReport = Get-CoverageReport -CommandCoverage $breakpoints
                $totalMilliseconds = $run.Duration.TotalMilliseconds
                $jaCoCoReport = Get-JaCoCoReportXml -CommandCoverage $breakpoints -TotalMilliseconds $totalMilliseconds -CoverageReport $coverageReport
                $jaCoCoReport | & $SafeCommands['Out-File'] $PesterPreference.CodeCoverage.OutputPath.Value -Encoding $PesterPreference.CodeCoverage.OutputEncoding.Value
            }

            if (-not $PesterPreference.Debug.ReturnRawResultObject.Value) {
                Remove-RSPecNonPublicProperties $run
            }

            if ($PesterPreference.Run.PassThru.Value) {
                $run
            }

            # exit with exit code if we fail and even if we succeed, othwerise we could inherit
            # exit code of some other app end exit with it's exit code instead with ours
            if ($PesterPreference.Run.Exit.Value) {
                exit ($run.FailedCount + $run.FailedBlocksCount + $run.FailedContainersCount)
            }
            else {
                [System.Environment]::ExitCode = $run.FailedCount + $run.FailedBlocksCount + $run.FailedContainersCount
            }
        }
        catch {
            Write-ErrorToScreen $_
            if ($PesterPreference.Run.Exit.Value) {
                exit -1
            }
        }
    }
}

function New-PesterOption {
    #TODO: move those options, right now I am just not exposing this function and added the testSuiteName
    <#
    .SYNOPSIS
    Creates an object that contains advanced options for Invoke-Pester
    .DESCRIPTION
    By using New-PesterOption you can set options what allow easier integration with external applications or
    modifies output generated by Invoke-Pester.
    The result of New-PesterOption need to be assigned to the parameter 'PesterOption' of the Invoke-Pester function.
    .PARAMETER IncludeVSCodeMarker
    When this switch is set, an extra line of output will be written to the console for test failures, making it easier
    for VSCode's parser to provide highlighting / tooltips on the line where the error occurred.
    .PARAMETER TestSuiteName
    When generating NUnit XML output, this controls the name assigned to the root "test-suite" element.  Defaults to "Pester".
    .PARAMETER ScriptBlockFilter
    Filters scriptblock based on the path and line number. This is intended for integration with external tools so we don't rely on names (strings) that can have expandable variables in them.
    .PARAMETER Experimental
    Enables experimental features of Pester to be enabled.
    .PARAMETER ShowScopeHints
    EXPERIMENTAL: Enables debugging output for debugging tranisition among scopes. (Experimental flag needs to be used to enable this.)

    .INPUTS
    None
    You cannot pipe input to this command.
    .OUTPUTS
    System.Management.Automation.PSObject
    .EXAMPLE
        PS > $Options = New-PesterOption -TestSuiteName "Tests - Set A"

        PS > Invoke-Pester -PesterOption $Options -Outputfile ".\Results-Set-A.xml" -OutputFormat NUnitXML

        The result of commands will be execution of tests and saving results of them in a NUnitMXL file where the root "test-suite"
        will be named "Tests - Set A".
    .LINK
    https://github.com/pester/Pester/wiki/New-PesterOption

    .LINK
    Invoke-Pester
    #>

    [CmdletBinding()]
    param (
        [switch] $IncludeVSCodeMarker,

        [ValidateNotNullOrEmpty()]
        [string] $TestSuiteName = 'Pester',

        [switch] $Experimental,

        [switch] $ShowScopeHints,

        [hashtable[]] $ScriptBlockFilter
    )

    # in PowerShell 2 Add-Member can attach properties only to
    # PSObjects, I could work around this by capturing all instances
    # in checking them during runtime, but that would bring a lot of
    # object management problems - so let's just not allow this in PowerShell 2
    if ($Experimental -and $ShowScopeHints) {
        if ($PSVersionTable.PSVersion.Major -lt 3) {
            throw "Scope hints cannot be used on PowerShell 2 due to limitations of Add-Member."
        }

        $script:DisableScopeHints = $false
    }
    else {
        $script:DisableScopeHints = $true
    }

    return & $script:SafeCommands['New-Object'] psobject -Property @{
        IncludeVSCodeMarker = [bool] $IncludeVSCodeMarker
        TestSuiteName       = $TestSuiteName
        ShowScopeHints      = $ShowScopeHints
        Experimental        = $Experimental
        ScriptBlockFilter   = $ScriptBlockFilter
    }
}

function ResolveTestScripts {
    param ([object[]] $Path)

    $resolvedScriptInfo = @(
        foreach ($object in $Path) {
            if ($object -is [System.Collections.IDictionary]) {
                $unresolvedPath = Get-DictionaryValueFromFirstKeyFound -Dictionary $object -Key 'Path', 'p'
                $script = Get-DictionaryValueFromFirstKeyFound -Dictionary $object -Key 'Script'
                $arguments = @(Get-DictionaryValueFromFirstKeyFound -Dictionary $object -Key 'Arguments', 'args', 'a')
                $parameters = Get-DictionaryValueFromFirstKeyFound -Dictionary $object -Key 'Parameters', 'params'

                if ($null -eq $Parameters) {
                    $Parameters = @{}
                }

                if ($unresolvedPath -isnot [string] -or $unresolvedPath -notmatch '\S' -and ($script -isnot [string] -or $script -notmatch '\S')) {
                    throw 'When passing hashtables to the -Path parameter, the Path key is mandatory, and must contain a single string.'
                }

                if ($null -ne $parameters -and $parameters -isnot [System.Collections.IDictionary]) {
                    throw 'When passing hashtables to the -Path parameter, the Parameters key (if present) must be assigned an IDictionary object.'
                }
            }
            else {
                $unresolvedPath = [string] $object
                $script = [string] $object
                $arguments = @()
                $parameters = @{}
            }

            if (-not [string]::IsNullOrEmpty($unresolvedPath)) {
                if ($unresolvedPath -notmatch '[\*\?\[\]]' -and
                    (& $script:SafeCommands['Test-Path'] -LiteralPath $unresolvedPath -PathType Leaf) -and
                    (& $script:SafeCommands['Get-Item'] -LiteralPath $unresolvedPath) -is [System.IO.FileInfo]) {
                    $extension = [System.IO.Path]::GetExtension($unresolvedPath)
                    if ($extension -ne '.ps1') {
                        & $script:SafeCommands['Write-Error'] "Script path '$unresolvedPath' is not a ps1 file."
                    }
                    else {
                        & $script:SafeCommands['New-Object'] psobject -Property @{
                            Path       = $unresolvedPath
                            Script     = $null
                            Arguments  = $arguments
                            Parameters = $parameters
                        }
                    }
                }
                else {
                    # World's longest pipeline?

                    & $script:SafeCommands['Resolve-Path'] -Path $unresolvedPath |
                        & $script:SafeCommands['Where-Object'] { $_.Provider.Name -eq 'FileSystem' } |
                        & $script:SafeCommands['Select-Object'] -ExpandProperty ProviderPath |
                        & $script:SafeCommands['Get-ChildItem'] -Include *.Tests.ps1 -Recurse |
                        & $script:SafeCommands['Where-Object'] { -not $_.PSIsContainer } |
                        & $script:SafeCommands['Select-Object'] -ExpandProperty FullName -Unique |
                        & $script:SafeCommands['ForEach-Object'] {
                        & $script:SafeCommands['New-Object'] psobject -Property @{
                            Path       = $_
                            Script     = $null
                            Arguments  = $arguments
                            Parameters = $parameters
                        }
                    }
                }
            }
            elseif (-not [string]::IsNullOrEmpty($script)) {
                & $script:SafeCommands['New-Object'] psobject -Property @{
                    Path       = $null
                    Script     = $script
                    Arguments  = $arguments
                    Parameters = $parameters
                }
            }
        }
    )

    # Here, we have the option of trying to weed out duplicate file paths that also contain identical
    # Parameters / Arguments.  However, we already make sure that each object in $Path didn't produce
    # any duplicate file paths, and if the caller happens to pass in a set of parameters that produce
    # dupes, maybe that's not our problem.  For now, just return what we found.

    $resolvedScriptInfo
}

function Get-DictionaryValueFromFirstKeyFound {
    param ([System.Collections.IDictionary] $Dictionary, [object[]] $Key)

    foreach ($keyToTry in $Key) {
        if ($Dictionary.Contains($keyToTry)) {
            return $Dictionary[$keyToTry]
        }
    }
}

function Set-PesterStatistics($Node) {
    if ($null -eq $Node) {
        $Node = $pester.TestActions
    }

    foreach ($action in $Node.Actions) {
        if ($action.Type -eq 'TestGroup') {
            Set-PesterStatistics -Node $action

            $Node.TotalCount += $action.TotalCount
            $Node.PassedCount += $action.PassedCount
            $Node.FailedCount += $action.FailedCount
            $Node.SkippedCount += $action.SkippedCount
            $Node.PendingCount += $action.PendingCount
            $Node.InconclusiveCount += $action.InconclusiveCount
        }
        elseif ($action.Type -eq 'TestCase') {
            $node.TotalCount++

            switch ($action.Result) {
                Passed {
                    $Node.PassedCount++; break;
                }
                Failed {
                    $Node.FailedCount++; break;
                }
                Skipped {
                    $Node.SkippedCount++; break;
                }
                Pending {
                    $Node.PendingCount++; break;
                }
                Inconclusive {
                    $Node.InconclusiveCount++; break;
                }
            }
        }
    }
}

function Contain-AnyStringLike ($Filter, $Collection) {
    foreach ($item in $Collection) {
        foreach ($value in $Filter) {
            if ($item -like $value) {
                return $true
            }
        }
    }
    return $false
}

function ConvertTo-Pester4Result {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        $PesterResult
    )
    process {
        $legacyResult = [PSCustomObject] @{
            Version = 4.99.0
            TagFilter = $null
            ExcludeTagFilter = $null
            TestNameFilter = $null
            ScriptBlockFilter = $null
            TotalCount = 0
            PassedCount = 0
            FailedCount = 0
            SkippedCount = 0
            PendingCount = 0
            InconclusiveCount = 0
            Time = [TimeSpan]::Zero
            TestResult = [System.Collections.Generic.List[object]]@()
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
                Passed = "Passed" -eq $test.Result
                Result = $test.Result
                Time = $test.Duration
                Name = $test.Name

                # in the legacy result the top block is considered to be a Describe and any blocks inside of it are
                # considered to be Context and joined by '\'
                Describe = $test.Path[0]
                Context = $(if ($test.Path.Count -gt 2) { $test.Path[1..($test.Path.Count-2)] -join '\'})

                Show = $PesterResult.Configuration.Output.Verbosity.Value
                Parameters = $test.Data
                ParameterizedSuiteName = $test.DisplayName

                FailureMessage = $(if (any $test.ErrorRecord -and $null -ne $test.ErrorRecord[-1].Exception) { $test.ErrorRecord[-1].DisplayErrorMessage })
                ErrorRecord = $(if (any $test.ErrorRecord) { $test.ErrorRecord[-1] })
                StackTrace = $(if (any $test.ErrorRecord) { $test.ErrorRecord[1].DisplayStackTrace })
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
        # the normal properties on the reslt to count

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
            }
        }
        $legacyResult.TotalCount = $legacyResult.TestResult.Count
        $legacyResult.PendingCount = 0
        $legacyResult.InconclusiveCount = 0
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
        The ScritpBlock to run.

        .EXAMPLE
            PS > BeforeDiscovery {
                $files = "file1.txt", "file2.txt"
            }

            Describe "File tests" {
                foreach ($file in $files) {
                    It "test" {
                        # ... test code
                    }
                }
            }

            The result of commands will be execution of tests and saving results of them in a NUnitMXL file where the root "test-suite"
            will be named "Tests - Set A".
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ScriptBlock]$ScriptBlock
    )

    . $ScriptBlock
}

# Adding Add-ShouldOperator because it used to be an alias in v4, and so when we now import it will take precedence over
# our internal function in v5, so we need a safe way to refer to it
$script:SafeCommands['Add-ShouldOperator'] = & $SafeCommands['Get-Command'] -CommandType Function -Name 'Add-ShouldOperator'
