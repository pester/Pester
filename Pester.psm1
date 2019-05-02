Get-Module Pester.Utility, Pester.Runtime, Pester.RSpec | Remove-Module
Import-Module $PSScriptRoot\new-runtimepoc\Pester.Utility.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\new-runtimepoc\Pester.Runtime.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\new-runtimepoc\Pester.RSpec.psm1 -DisableNameChecking

. $PSScriptRoot\Functions\Pester.SafeCommands.ps1

$script:AssertionOperators = & $SafeCommands['New-Object'] 'Collections.Generic.Dictionary[string,object]'([StringComparer]::InvariantCultureIgnoreCase)
$script:AssertionAliases = & $SafeCommands['New-Object'] 'Collections.Generic.Dictionary[string,object]'([StringComparer]::InvariantCultureIgnoreCase)
$script:AssertionDynamicParams = & $SafeCommands['New-Object'] System.Management.Automation.RuntimeDefinedParameterDictionary
$script:DisableScopeHints = $true


function Test-NullOrWhiteSpace {
    param ([string]$String)

    $String -match "^\s*$"
}

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

    $entry = New-Object psobject -Property @{
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

    foreach ($string in $Alias | Where { -not (Test-NullOrWhiteSpace $_)}) {
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
    -not (Compare-Object $Operator.Alias $existing.Alias)
}
function Assert-AssertionOperatorNameIsUnique {
    param (
        [string[]] $Name
    )

    foreach ($string in $name | Where { -not (Test-NullOrWhiteSpace $_)}) {
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
    $commandInfo = Get-Command __AssertionTest__ -CommandType Function
    $metadata = [System.Management.Automation.CommandMetadata]$commandInfo

    $attribute = New-Object Management.Automation.ParameterAttribute
    $attribute.ParameterSetName = $AssertionEntry.Name
    $attribute.Mandatory = $true

    $attributeCollection = New-Object Collections.ObjectModel.Collection[Attribute]
    $null = $attributeCollection.Add($attribute)
    if (-not (Test-NullOrWhiteSpace $AssertionEntry.Alias)) {
        Assert-ValidAssertionAlias -Alias $AssertionEntry.Alias
        $attribute = New-Object System.Management.Automation.AliasAttribute($AssertionEntry.Alias)
        $attributeCollection.Add($attribute)
    }

    $dynamic = New-Object System.Management.Automation.RuntimeDefinedParameter($AssertionEntry.Name, [switch], $attributeCollection)
    $null = $script:AssertionDynamicParams.Add($AssertionEntry.Name, $dynamic)

    if ($script:AssertionDynamicParams.ContainsKey('Not')) {
        $dynamic = $script:AssertionDynamicParams['Not']
    }
    else {
        $dynamic = New-Object System.Management.Automation.RuntimeDefinedParameter('Not', [switch], (New-Object System.Collections.ObjectModel.Collection[Attribute]))
        $null = $script:AssertionDynamicParams.Add('Not', $dynamic)
    }

    $attribute = New-Object System.Management.Automation.ParameterAttribute
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

            $dynamic = New-Object System.Management.Automation.RuntimeDefinedParameter($parameter.Name, $type, (New-Object System.Collections.ObjectModel.Collection[Attribute]))
            $null = $script:AssertionDynamicParams.Add($parameter.Name, $dynamic)
        }

        $attribute = New-Object Management.Automation.ParameterAttribute
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

$Script:PesterRoot = & $SafeCommands['Split-Path'] -Path $MyInvocation.MyCommand.Path
"$PesterRoot\Functions\*.ps1", "$PesterRoot\Functions\Assertions\*.ps1" |
    & $script:SafeCommands['Resolve-Path'] |
    & $script:SafeCommands['Where-Object'] { -not ($_.ProviderPath.ToLower().Contains(".tests.")) } |
    & $script:SafeCommands['ForEach-Object'] { . $_.ProviderPath }

if (& $script:SafeCommands['Test-Path'] "$PesterRoot\Dependencies") {
    # sub-modules
    & $script:SafeCommands['Get-ChildItem'] "$PesterRoot\Dependencies\*\*.psm1" |
        & $script:SafeCommands['ForEach-Object'] { & $script:SafeCommands['Import-Module'] $_.FullName -DisableNameChecking }
}

Add-Type -TypeDefinition @"
using System;

namespace Pester
{
    [Flags]
    public enum OutputTypes
    {
        None = 0,
        Default = 1,
        Passed = 2,
        Failed = 4,
        Pending = 8,
        Skipped = 16,
        Inconclusive = 32,
        Describe = 64,
        Context = 128,
        Summary = 256,
        Header = 512,
        All = Default | Passed | Failed | Pending | Skipped | Inconclusive | Describe | Context | Summary | Header,
        Fails = Default | Failed | Pending | Skipped | Inconclusive | Describe | Context | Summary | Header
    }
}
"@

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

    .PARAMETER Script
    Specifies the test files that Pester runs. You can also use the Script parameter
    to pass parameter names and values to a script that contains Pester tests. The
    value of the Script parameter can be a string, a hash table, or a collection
    of hash tables and strings. Wildcard characters are supported.

    The Script parameter is optional. If you omit it, Invoke-Pester runs all
    *.Tests.ps1 files in the local directory and its subdirectories recursively.

    To run tests in other files, such as .ps1 files, enter the path and file name of
    the file. (The file name is required. Name patterns that end in "*.ps1" run only
    *.Tests.ps1 files.)

    To run a Pester test with parameter names and/or values, use a hash table as the
    value of the script parameter. The keys in the hash table are:

    -- Path [string] (required): Specifies a test to run. The value is a path\file
    name or name pattern. Wildcards are permitted. All hash tables in a Script
    parameter value must have a Path key.

    -- Parameters [hashtable]: Runs the script with the specified parameters. The
    value is a nested hash table with parameter name and value pairs, such as
    @{UserName = 'User01'; Id = '28'}.

    -- Arguments [array]: An array or comma-separated list of parameter values
    without names, such as 'User01', 28. Use this key to pass values to positional
    parameters.


    .PARAMETER TestName
    Runs only tests in Describe blocks that have the specified name or name pattern.
    Wildcard characters are supported.

    If you specify multiple TestName values, Invoke-Pester runs tests that have any
    of the values in the Describe name (it ORs the TestName values).

    .PARAMETER EnableExit
    Will cause Invoke-Pester to exit with a exit code equal to the number of failed
    tests once all tests have been run. Use this to "fail" a build when any tests fail.

    .PARAMETER OutputFile
    The path where Invoke-Pester will save formatted test results log file.

    The path must include the location and name of the folder and file name with
    the xml extension.

    If this path is not provided, no log will be generated.

    .PARAMETER OutputFormat
    The format of output. Two formats of output are supported: NUnitXML and
    LegacyNUnitXML.

    .PARAMETER Tag
    Runs only tests in Describe blocks with the specified Tag parameter values.
    Wildcard characters are supported. Tag values that include spaces or whitespace
    will be split into multiple tags on the whitespace.

    When you specify multiple Tag values, Invoke-Pester runs tests that have any
    of the listed tags (it ORs the tags). However, when you specify TestName
    and Tag values, Invoke-Pester runs only describe blocks that have one of the
    specified TestName values and one of the specified Tag values.

    If you use both Tag and ExcludeTag, ExcludeTag takes precedence.

    .PARAMETER ExcludeTag
    Omits tests in Describe blocks with the specified Tag parameter values. Wildcard
    characters are supported. Tag values that include spaces or whitespace
    will be split into multiple tags on the whitespace.

    When you specify multiple ExcludeTag values, Invoke-Pester omits tests that have
    any of the listed tags (it ORs the tags). However, when you specify TestName
    and ExcludeTag values, Invoke-Pester omits only describe blocks that have one
    of the specified TestName values and one of the specified Tag values.

    If you use both Tag and ExcludeTag, ExcludeTag takes precedence

    .PARAMETER PassThru
    Returns a custom object (PSCustomObject) that contains the test results.

    By default, Invoke-Pester writes to the host program, not to the output stream (stdout).
    If you try to save the result in a variable, the variable is empty unless you
    use the PassThru parameter.

    To suppress the host output, use the Show parameter set to None.

    .PARAMETER CodeCoverage
    Adds a code coverage report to the Pester tests. Takes strings or hash table values.

    A code coverage report lists the lines of code that did and did not run during
    a Pester test. This report does not tell whether code was tested; only whether
    the code ran during the test.

    By default, the code coverage report is written to the host program
    (like Write-Host). When you use the PassThru parameter, the custom object
    that Invoke-Pester returns has an additional CodeCoverage property that contains
    a custom object with detailed results of the code coverage test, including lines
    hit, lines missed, and helpful statistics.

    However, NUnitXML and LegacyNUnitXML output (OutputXML, OutputFormat) do not include
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
    The path where Invoke-Pester will save formatted code coverage results file.

    The path must include the location and name of the folder and file name with
    a required extension (usually the xml).

    If this path is not provided, no file will be generated.

    .PARAMETER CodeCoverageOutputFileFormat
    The name of a code coverage report file format.

    Default value is: JaCoCo.

    Currently supported formats are:
    - JaCoCo - this XML file format is compatible with the VSTS/TFS

    .PARAMETER Strict
    Makes Pending and Skipped tests to Failed tests. Useful for continuous
    integration where you need to make sure all tests passed.

    .PARAMETER Show
    Customizes the output Pester writes to the screen. Available options are None, Default,
    Passed, Failed, Pending, Skipped, Inconclusive, Describe, Context, Summary, Header, All, Fails.

    The options can be combined to define presets.
    Common use cases are:

    None - to write no output to the screen.
    All - to write all available information (this is default option).
    Fails - to write everything except Passed (but including Describes etc.).

    A common setting is also Failed, Summary, to write only failed tests and test summary.

    This parameter does not affect the PassThru custom object or the XML output that
    is written when you use the Output parameters.

    .PARAMETER PesterOption
    Sets advanced options for the test execution. Enter a PesterOption object,
    such as one that you create by using the New-PesterOption cmdlet, or a hash table
    in which the keys are option names and the values are option values.
    For more information on the options available, see the help for New-PesterOption.

    .Example
    Invoke-Pester

    This command runs all *.Tests.ps1 files in the current directory and its subdirectories.

    .Example
    Invoke-Pester -Script .\Util*

    This commands runs all *.Tests.ps1 files in subdirectories with names that begin
    with 'Util' and their subdirectories.

    .Example
    Invoke-Pester -Script D:\MyModule, @{ Path = '.\Tests\Utility\ModuleUnit.Tests.ps1'; Parameters = @{ Name = 'User01' }; Arguments = srvNano16  }

    This command runs all *.Tests.ps1 files in D:\MyModule and its subdirectories.
    It also runs the tests in the ModuleUnit.Tests.ps1 file using the following
    parameters: .\Tests\Utility\ModuleUnit.Tests.ps1 srvNano16 -Name User01

    .Example
    Invoke-Pester -Script @{Script = $scriptText}
    This command runs all tests passed as string in $scriptText variable with no aditional parameters and arguments. This notation can be combined with
    Invoke-Pester -Script D:\MyModule, @{ Path = '.\Tests\Utility\ModuleUnit.Tests.ps1'; Parameters = @{ Name = 'User01' }; Arguments = srvNano16  }
    if needed. This command can be used when tests and scripts are stored not on the FileSystem, but somewhere else, and it is impossible to provide a path to it.

    .Example
    Invoke-Pester -TestName "Add Numbers"

    This command runs only the tests in the Describe block named "Add Numbers".

    .EXAMPLE
    $results = Invoke-Pester -Script D:\MyModule -PassThru -Show None
    $failed = $results.TestResult | where Result -eq 'Failed'

    $failed.Name
    cannot find help for parameter: Force : in Compress-Archive
    help for Force parameter in Compress-Archive has wrong Mandatory value
    help for Compress-Archive has wrong parameter type for Force
    help for Update parameter in Compress-Archive has wrong Mandatory value
    help for DestinationPath parameter in Expand-Archive has wrong Mandatory value

    $failed[0]
    Describe               : Test help for Compress-Archive in Microsoft.PowerShell.Archive (1.0.0.0)
    Context                : Test parameter help for Compress-Archive
    Name                   : cannot find help for parameter: Force : in Compress-Archive
    Result                 : Failed
    Passed                 : False
    Time                   : 00:00:00.0193083
    FailureMessage         : Expected: value to not be empty
    StackTrace             : at line: 279 in C:\GitHub\PesterTdd\Module.Help.Tests.ps1
                            279:                     $parameterHelp.Description.Text | Should Not BeNullOrEmpty
    ErrorRecord            : Expected: value to not be empty
    ParameterizedSuiteName :
    Parameters             : {}

    This examples uses the PassThru parameter to return a custom object with the
    Pester test results. By default, Invoke-Pester writes to the host program, but not
    to the output stream. It also uses the Show parameter set to None to suppress the host output.

    The first command runs Invoke-Pester with the PassThru and Show parameters and
    saves the PassThru output in the $results variable.

    The second command gets only failing results and saves them in the $failed variable.

    The third command gets the names of the failing results. The result name is the
    name of the It block that contains the test.

    The fourth command uses an array index to get the first failing result. The
    property values describe the test, the expected result, the actual result, and
    useful values, including a stack trace.

    .Example
    Invoke-Pester -EnableExit -OutputFile ".\artifacts\TestResults.xml" -OutputFormat NUnitXml

    This command runs all tests in the current directory and its subdirectories. It
    writes the results to the TestResults.xml file using the NUnitXml schema. The
    test returns an exit code equal to the number of test failures.

    .EXAMPLE
    Invoke-Pester -CodeCoverage 'ScriptUnderTest.ps1'

    Runs all *.Tests.ps1 scripts in the current directory, and generates a coverage
    report for all commands in the "ScriptUnderTest.ps1" file.

    .EXAMPLE
    Invoke-Pester -CodeCoverage @{ Path = 'ScriptUnderTest.ps1'; Function = 'FunctionUnderTest' }

    Runs all *.Tests.ps1 scripts in the current directory, and generates a coverage
    report for all commands in the "FunctionUnderTest" function in the "ScriptUnderTest.ps1" file.

    .EXAMPLE
    Invoke-Pester -CodeCoverage 'ScriptUnderTest.ps1' -CodeCoverageOutputFile '.\artifacts\TestOutput.xml'

    Runs all *.Tests.ps1 scripts in the current directory, and generates a coverage
    report for all commands in the "ScriptUnderTest.ps1" file, and writes the coverage report to TestOutput.xml
    file using the JaCoCo XML Report DTD.

    .EXAMPLE
    Invoke-Pester -CodeCoverage @{ Path = 'ScriptUnderTest.ps1'; StartLine = 10; EndLine = 20 }

    Runs all *.Tests.ps1 scripts in the current directory, and generates a coverage
    report for all commands on lines 10 through 20 in the "ScriptUnderTest.ps1" file.

    .EXAMPLE
    Invoke-Pester -Script C:\Tests -Tag UnitTest, Newest -ExcludeTag Bug

    This command runs *.Tests.ps1 files in C:\Tests and its subdirectories. In those
    files, it runs only tests that have UnitTest or Newest tags, unless the test
    also has a Bug tag.

    .LINK
    https://github.com/pester/Pester/wiki/Invoke-Pester

    .LINK
    Describe
    about_Pester
    New-PesterOption

    #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param(
        [Parameter(Position = 0, Mandatory = 0)]
        [String[]]$Path = '.',
        [String[]]$ExcludePath = @(),

        [switch]$EnableExit,

        [string[]]$Tag,

        [string[]]$ExcludeTag,

        [switch]$PassThru,

        [object[]] $CodeCoverage = @(),

        [string] $CodeCoverageOutputFile,

        [ValidateSet('JaCoCo')]
        [String]$CodeCoverageOutputFileFormat = "JaCoCo",

        [Switch]$Strict,

        [Parameter(Mandatory = $true, ParameterSetName = 'NewOutputSet')]
        [string] $OutputFile,

        [Parameter(ParameterSetName = 'NewOutputSet')]
        [ValidateSet('NUnitXml')]
        [string] $OutputFormat = 'NUnitXml',

        [object]$PesterOption,

        [Pester.OutputTypes]$Show = 'All',

        [ScriptBlock[]] $ScriptBlock
    )
    begin {
        # Ensure when running Pester that we're using RSpec strings
        & $script:SafeCommands['Import-LocalizedData'] -BindingVariable Script:ReportStrings -BaseDirectory $PesterRoot -FileName RSpec.psd1 -ErrorAction SilentlyContinue

        # Fallback to en-US culture strings
        if ([String]::IsNullOrEmpty($ReportStrings)) {
            & $script:SafeCommands['Import-LocalizedData'] -BaseDirectory $PesterRoot -BindingVariable Script:ReportStrings -UICulture 'en-US' -FileName RSpec.psd1 -ErrorAction Stop
        }
    }

    end {
        try {
            $script:mockTable = @{}
            # todo: move mock cleanup to BeforeAllBlockContainer when there is any
            Remove-MockFunctionsAndAliases
            $sessionState = Set-SessionStateHint -PassThru  -Hint "Caller - Captured in Invoke-Pester" -SessionState $PSCmdlet.SessionState

            # TODO: remove all references to $pester
            $pester = @{ SessionState = $PSCmdlet.SessionState }
            $pluginConfiguration = @{}
            $plugins = @(
                Get-WriteScreenPlugin
                Get-TestDrivePlugin
                Get-MockPlugin
            )

            if ($CodeCoverage) {
                $plugins += (Get-CoveragePlugin)
                $pluginConfiguration["Coverage"] = $CodeCoverage
            }


            $filter = New-FilterObject -Tag $Tag -ExcludeTag $ExcludeTag

            $containers = @()
            if (any $ScriptBlock) {
                Write-Host -ForegroundColor Magenta "Running tests in $($ScriptBlock.Count) scriptblocks."
                $containers += @( $ScriptBlock | foreach { Pester.Runtime\New-BlockContainerObject -ScriptBlock $_ })
            }

            if (any $Path) {
                if (none ($ScriptBlock) -or ((any $ScriptBlock) -and '.' -ne $Path[0])) {
                    #TODO: Skipping the invocation when scriptblock is provided and the default path, later keep path in the default parameter set and remove scriptblock from it, so get-help still shows . as the default value and we can still provide script blocks via an advanced settings parameter
                    Write-Host -ForegroundColor Magenta "Running all tests in $Path"
                    $containers += @(Find-RSpecTestFile -Path $Path -ExcludePath $ExcludePath | foreach { Pester.Runtime\New-BlockContainerObject -File $_ })
                }
            }

            if (none $containers) {
                Write-Host -ForegroundColor Magenta "No test files were found and no scriptblocks were provided."
                return
            }

            $r = Pester.Runtime\Invoke-Test -BlockContainer $containers -Plugin $plugins -PluginConfiguration $pluginConfiguration -SessionState $sessionState -Filter $filter
            $legacyResult = Get-LegacyResult $r
            Write-PesterReport $legacyResult

            if ($PassThru) {
                $r
            }

            if ($EnableExit -and $legacyResult.FailedCount -gt 0) {
                exit ($legacyResult.FailedCount)
            }
        }
        catch {
            Write-ErrorToScreen $_
            if ($EnableExit) {
                exit 999
            }
        }
    }
}

function New-PesterOption {
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

function Get-LegacyResult {
    param($RunResult)

    $o = @{
        Time              = [timespan]::Zero
        FrameworkTime     = [timespan]::Zero
        PassedCount       = 0
        FailedCount       = 0
        SkippedCount      = 0
        PendingCount      = 0
        InconclusiveCount = 0
    }

    $RunResult | Fold-Container -OnTest {
        param($test)
        if ($test.Passed) {
            $o.PassedCount++
        }
        elseif ($test.ShouldRun -and (-not $test.Executed -or -not $test.Passed)) {
            $o.FailedCount++
        }
        else {
            $o.SkippedCount++
        }

        $o.FrameworkTime += $test.FrameworkDuration
    }

    $o.Time = (sum $RunResult Duration ([timespan]::Zero)) + (sum $RunResult FrameworkDuration ([timespan]::Zero)) + (sum $RunResult DiscoveryDuration ([timespan]::Zero))

    $o
}

Set-SessionStateHint -Hint Pester -SessionState $ExecutionContext.SessionState
# these functions will be shared with the mock bootstrap function, or used in mocked calls so let's capture them just once instead of everytime we use a mock
$script:SafeCommands['Get-MockDynamicParameter'] = $ExecutionContext.SessionState.InvokeCommand.GetCommand('Get-MockDynamicParameter', 'function')
$SafeCommands['Write-PesterDebugMessage'] = $ExecutionContext.SessionState.InvokeCommand.GetCommand('Write-PesterDebugMessage', 'function')
$SafeCommands['Set-DynamicParameterVariable'] = $ExecutionContext.SessionState.InvokeCommand.GetCommand('Set-DynamicParameterVariable', 'function')

& $script:SafeCommands['Export-ModuleMember'] Invoke-Pester, Describe, Context, It, In, Mock, Assert-VerifiableMock, Assert-MockCalled, Set-ItResult
& $script:SafeCommands['Export-ModuleMember'] Should, InModuleScope
& $script:SafeCommands['Export-ModuleMember'] BeforeEach, AfterEach, BeforeAll, AfterAll, Anywhere
& $script:SafeCommands['Export-ModuleMember'] Get-MockDynamicParameter, Set-DynamicParameterVariable
& $script:SafeCommands['Export-ModuleMember'] New-PesterOptions
& $script:SafeCommands['Export-ModuleMember'] Invoke-Gherkin, Find-GherkinStep, BeforeEachFeature, BeforeEachScenario, AfterEachFeature, AfterEachScenario, GherkinStep -Alias Given, When, Then, And, But
& $script:SafeCommands['Export-ModuleMember'] New-MockObject, Add-ShouldOperator, Get-ShouldOperator
