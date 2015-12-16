# Pester
# Version: $version$
# Changeset: $sha$

if ($PSVersionTable.PSVersion.Major -ge 3)
{
    $script:IgnoreErrorPreference = 'Ignore'
    $outNullModule = 'Microsoft.PowerShell.Core'
}
else
{
    $script:IgnoreErrorPreference = 'SilentlyContinue'
    $outNullModule = 'Microsoft.PowerShell.Utility'
}

# Tried using $ExecutionState.InvokeCommand.GetCmdlet() here, but it does not trigger module auto-loading the way
# Get-Command does.  Since this is at import time, before any mocks have been defined, that's probably acceptable.
# If someone monkeys with Get-Command before they import Pester, they may break something.

$script:SafeCommands = @{
    'Add-Member'          = Get-Command -Name Add-Member          -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Add-Type'            = Get-Command -Name Add-Type            -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Compare-Object'      = Get-Command -Name Compare-Object      -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Export-ModuleMember' = Get-Command -Name Export-ModuleMember -Module Microsoft.PowerShell.Core       -CommandType Cmdlet -ErrorAction Stop
    'ForEach-Object'      = Get-Command -Name ForEach-Object      -Module Microsoft.PowerShell.Core       -CommandType Cmdlet -ErrorAction Stop
    'Format-Table'        = Get-Command -Name Format-Table        -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Get-ChildItem'       = Get-Command -Name Get-ChildItem       -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Get-Command'         = Get-Command -Name Get-Command         -Module Microsoft.PowerShell.Core       -CommandType Cmdlet -ErrorAction Stop
    'Get-Content'         = Get-Command -Name Get-Content         -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Get-Date'            = Get-Command -Name Get-Date            -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Get-Item'            = Get-Command -Name Get-Item            -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Get-Location'        = Get-Command -Name Get-Location        -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Get-Member'          = Get-Command -Name Get-Member          -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Get-Module'          = Get-Command -Name Get-Module          -Module Microsoft.PowerShell.Core       -CommandType Cmdlet -ErrorAction Stop
    'Get-PSDrive'         = Get-Command -Name Get-PSDrive         -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Get-Variable'        = Get-Command -Name Get-Variable        -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Get-WmiObject'       = Get-Command -Name Get-WmiObject       -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Group-Object'        = Get-Command -Name Group-Object        -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Join-Path'           = Get-Command -Name Join-Path           -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Measure-Object'      = Get-Command -Name Measure-Object      -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'New-Item'            = Get-Command -Name New-Item            -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'New-Module'          = Get-Command -Name New-Module          -Module Microsoft.PowerShell.Core       -CommandType Cmdlet -ErrorAction Stop
    'New-Object'          = Get-Command -Name New-Object          -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'New-PSDrive'         = Get-Command -Name New-PSDrive         -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'New-Variable'        = Get-Command -Name New-Variable        -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Out-Null'            = Get-Command -Name Out-Null            -Module $outNullModule                  -CommandType Cmdlet -ErrorAction Stop
    'Out-String'          = Get-Command -Name Out-String          -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Pop-Location'        = Get-Command -Name Pop-Location        -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Push-Location'       = Get-Command -Name Push-Location       -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Remove-Item'         = Get-Command -Name Remove-Item         -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Remove-PSBreakpoint' = Get-Command -Name Remove-PSBreakpoint -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Remove-PSDrive'      = Get-Command -Name Remove-PSDrive      -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Remove-Variable'     = Get-Command -Name Remove-Variable     -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Resolve-Path'        = Get-Command -Name Resolve-Path        -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Select-Object'       = Get-Command -Name Select-Object       -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Set-Content'         = Get-Command -Name Set-Content         -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Set-PSBreakpoint'    = Get-Command -Name Set-PSBreakpoint    -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Set-StrictMode'      = Get-Command -Name Set-StrictMode      -Module Microsoft.PowerShell.Core       -CommandType Cmdlet -ErrorAction Stop
    'Set-Variable'        = Get-Command -Name Set-Variable        -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Sort-Object'         = Get-Command -Name Sort-Object         -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Split-Path'          = Get-Command -Name Split-Path          -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Start-Sleep'         = Get-Command -Name Start-Sleep         -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Test-Path'           = Get-Command -Name Test-Path           -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Where-Object'        = Get-Command -Name Where-Object        -Module Microsoft.PowerShell.Core       -CommandType Cmdlet -ErrorAction Stop
    'Write-Error'         = Get-Command -Name Write-Error         -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Write-Progress'      = Get-Command -Name Write-Progress      -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Write-Verbose'       = Get-Command -Name Write-Verbose       -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Write-Warning'       = Get-Command -Name Write-Warning       -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
}

# little sanity check to make sure we don't blow up a system with a typo up there
# (not that I've EVER done that by, for example, mapping New-Item to Remove-Item...)

foreach ($keyValuePair in $script:SafeCommands.GetEnumerator())
{
    if ($keyValuePair.Key -ne $keyValuePair.Value.Name)
    {
        throw "SafeCommands entry for $($keyValuePair.Key) does not hold a reference to the proper command."
    }
}

$moduleRoot = & $script:SafeCommands['Split-Path'] -Path $MyInvocation.MyCommand.Path

"$moduleRoot\Functions\*.ps1", "$moduleRoot\Functions\Assertions\*.ps1" |
& $script:SafeCommands['Resolve-Path'] |
& $script:SafeCommands['Where-Object'] { -not ($_.ProviderPath.ToLower().Contains(".tests.")) } |
& $script:SafeCommands['ForEach-Object'] { . $_.ProviderPath }

function Invoke-Pester {
<#
.SYNOPSIS
Invokes Pester to run all tests (files containing *.Tests.ps1) recursively under the Path

.DESCRIPTION
Upon calling Invoke-Pester, all files that have a name containing
"*.Tests.ps1" will have the tests defined in their Describe blocks
executed. Invoke-Pester begins at the location of Path and
runs recursively through each sub directory looking for
"*.Tests.ps1" files containing tests. If a TestName is provided,
Invoke-Pester will only run tests that have a describe block with a
matching name. By default, Invoke-Pester will end the test run with a
simple report of the number of tests passed and failed output to the
console. One may want pester to "fail a build" in the event that any
tests fail. To accomodate this, Invoke-Pester will return an exit
code equal to the number of failed tests if the EnableExit switch is
set. Invoke-Pester will also write a NUnit style log of test results
if the OutputXml parameter is provided. In these cases, Invoke-Pester
will write the result log to the path provided in the OutputXml
parameter.

Optionally, Pester can generate a report of how much code is covered
by the tests, and information about any commands which were not
executed.

.PARAMETER Script
This parameter indicates which test scripts should be run.
This parameter may be passed simple strings (wildcards are allowed), or hashtables containing Path, Arguments and Parameters keys.
If hashtables are used, the Parameters key must refer to a hashtable, and the Arguments key must refer to an array; these will be splatted to the test script(s) indicated in the Path key.

Note:  If the path contains any wildcards, or if it refers to a directory, then Pester will search for and execute all test scripts named *.Tests.ps1 in the target path; the search is recursive.  If the path contains no wildcards and refers to a file, Pester will just try to execute that file regardless of its name.

Aliased to 'Path' and 'relative_path' for backwards compatibility.

.PARAMETER TestName
Informs Invoke-Pester to only run Describe blocks that match this name.

.PARAMETER EnableExit
Will cause Invoke-Pester to exit with a exit code equal to the number of failed tests once all tests have been run. Use this to "fail" a build when any tests fail.

.PARAMETER OutputXml
The path where Invoke-Pester will save a NUnit formatted test results log file. If this path is not provided, no log will be generated.

.PARAMETER Tag
Informs Invoke-Pester to only run Describe blocks tagged with the tags specified. Aliased 'Tags' for backwards compatibility.

.PARAMETER ExcludeTag
Informs Invoke-Pester to not run blocks tagged with the tags specified.

.PARAMETER PassThru
Returns a Pester result object containing the information about the whole test run, and each test.

.PARAMETER CodeCoverage
Instructs Pester to generate a code coverage report in addition to running tests.  You may pass either hashtables or strings to this parameter.
If strings are used, they must be paths (wildcards allowed) to source files, and all commands in the files are analyzed for code coverage.
By passing hashtables instead, you can limit the analysis to specific lines or functions within a file.
Hashtables must contain a Path key (which can be abbreviated to just "P"), and may contain Function (or "F"), StartLine (or "S"), and EndLine ("E") keys to narrow down the commands to be analyzed.
If Function is specified, StartLine and EndLine are ignored.
If only StartLine is defined, the entire script file starting with StartLine is analyzed.
If only EndLine is present, all lines in the script file up to and including EndLine are analyzed.
Both Function and Path (as well as simple strings passed instead of hashtables) may contain wildcards.

.PARAMETER Strict
Makes Pending and Skipped tests to Failed tests. Useful for continuous integration where you need to make sure all tests passed.

.PARAMETER Quiet
Disables the output Pester writes to screen. No other output is generated unless you specify PassThru, or one of the Output parameters.

.Example
Invoke-Pester

This will find all *.Tests.ps1 files and run their tests. No exit code will be returned and no log file will be saved.

.Example
Invoke-Pester -Script ./tests/Utils*

This will run all tests in files under ./Tests that begin with Utils and alsocontains .Tests.

.Example
Invoke-Pester -Script @{ Path = './tests/Utils*'; Parameters = @{ NamedParameter = 'Passed By Name' }; Arguments = @('Passed by position') }

Executes the same tests as in Example 1, but will run them with the equivalent of the following command line:  & $testScriptPath -NamedParameter 'Passed By Name' 'Passed by position'

.Example
Invoke-Pester -TestName "Add Numbers"

This will only run the Describe block named "Add Numbers"

.Example
Invoke-Pester -EnableExit -OutputXml "./artifacts/TestResults.xml"

This runs all tests from the current directory downwards and writes the results according to the NUnit schema to artifacts/TestResults.xml just below the current directory. The test run will return an exit code equal to the number of test failures.

.Example
Invoke-Pester -EnableExit -OutputFile "./artifacts/TestResults.xml" -OutputFormat NUnitxml

This runs all tests from the current directory downwards and writes the results to an output file and NUnitxml output format

.EXAMPLE
Invoke-Pester -CodeCoverage 'ScriptUnderTest.ps1'

Runs all *.Tests.ps1 scripts in the current directory, and generates a coverage report for all commands in the "ScriptUnderTest.ps1" file.

.EXAMPLE
Invoke-Pester -CodeCoverage @{ Path = 'ScriptUnderTest.ps1'; Function = 'FunctionUnderTest' }

Runs all *.Tests.ps1 scripts in the current directory, and generates a coverage report for all commands in the "FunctionUnderTest" function in the "ScriptUnderTest.ps1" file.

.EXAMPLE
Invoke-Pester -CodeCoverage @{ Path = 'ScriptUnderTest.ps1'; StartLine = 10; EndLine = 20 }

Runs all *.Tests.ps1 scripts in the current directory, and generates a coverage report for all commands on lines 10 through 20 in the "ScriptUnderTest.ps1" file.

.LINK
Describe
about_pester

#>
    [CmdletBinding(DefaultParameterSetName = 'LegacyOutputXml')]
    param(
        [Parameter(Position=0,Mandatory=0)]
        [Alias('Path', 'relative_path')]
        [object[]]$Script = '.',

        [Parameter(Position=1,Mandatory=0)]
        [Alias("Name")]
        [string[]]$TestName,

        [Parameter(Position=2,Mandatory=0)]
        [switch]$EnableExit,

        [Parameter(Position=3,Mandatory=0, ParameterSetName = 'LegacyOutputXml')]
        [string]$OutputXml,

        [Parameter(Position=4,Mandatory=0)]
        [Alias('Tags')]
        [string[]]$Tag,

        [string[]]$ExcludeTag,

        [switch]$PassThru,

        [object[]] $CodeCoverage = @(),

        [Switch]$Strict,

        [Parameter(Mandatory = $true, ParameterSetName = 'NewOutputSet')]
        [string] $OutputFile,

        [Parameter(Mandatory = $true, ParameterSetName = 'NewOutputSet')]
        [ValidateSet('LegacyNUnitXml', 'NUnitXml')]
        [string] $OutputFormat,

        [Switch]$Quiet
    )

    if ($PSBoundParameters.ContainsKey('OutputXml'))
    {
        & $script:SafeCommands['Write-Warning'] 'The -OutputXml parameter has been deprecated; please use the new -OutputFile and -OutputFormat parameters instead.  To get the same type of export that the -OutputXml parameter currently provides, use an -OutputFormat of "LegacyNUnitXml".'

        & $script:SafeCommands['Start-Sleep'] -Seconds 2

        $OutputFile = $OutputXml
        $OutputFormat = 'LegacyNUnitXml'
    }

    $script:mockTable = @{}

    $pester = New-PesterState -TestNameFilter $TestName -TagFilter ($Tag -split "\s") -ExcludeTagFilter ($ExcludeTag -split "\s") -SessionState $PSCmdlet.SessionState -Strict:$Strict -Quiet:$Quiet
    Enter-CoverageAnalysis -CodeCoverage $CodeCoverage -PesterState $pester

    Write-Screen "`r`n`r`n`r`n`r`n"

    $invokeTestScript = {
        param (
            [Parameter(Position = 0)]
            [string] $Path,

            [object[]] $Arguments = @(),
            [System.Collections.IDictionary] $Parameters = @{}
        )

        & $Path @Parameters @Arguments
    }

    Set-ScriptBlockScope -ScriptBlock $invokeTestScript -SessionState $PSCmdlet.SessionState

    $testScripts = ResolveTestScripts $Script

    foreach ($testScript in $testScripts)
    {
        try
        {
            do
            {
                & $invokeTestScript -Path $testScript.Path -Arguments $testScript.Arguments -Parameters $testScript.Parameters
            } until ($true)
        }
        catch
        {
            $firstStackTraceLine = $_.ScriptStackTrace -split '\r?\n' | & $script:SafeCommands['Select-Object'] -First 1
            $pester.AddTestResult("Error occurred in test script '$($testScript.Path)'", "Failed", $null, $_.Exception.Message, $firstStackTraceLine, $null, $null, $_)
            $pester.TestResult[-1] | Write-PesterResult
        }
    }

    $pester | Write-PesterReport
    $coverageReport = Get-CoverageReport -PesterState $pester
    Show-CoverageReport -CoverageReport $coverageReport
    Exit-CoverageAnalysis -PesterState $pester

    if(& $script:SafeCommands['Get-Variable'] -Name OutputFile -ValueOnly -ErrorAction $script:IgnoreErrorPreference) {
        Export-PesterResults -PesterState $pester -Path $OutputFile -Format $OutputFormat
    }

    if ($PassThru) {
        #remove all runtime properties like current* and Scope
        $properties = @(
            "TagFilter","ExcludeTagFilter","TestNameFilter","TotalCount","PassedCount","FailedCount","SkippedCount","PendingCount","Time","TestResult"

            if ($CodeCoverage)
            {
                @{ Name = 'CodeCoverage'; Expression = { $coverageReport } }
            }
        )

        $pester | & $script:SafeCommands['Select-Object'] -Property $properties
    }

    if ($EnableExit) { Exit-WithCode -FailedCount $pester.FailedCount }
}

function ResolveTestScripts
{
    param ([object[]] $Path)

    $resolvedScriptInfo = @(
        foreach ($object in $Path)
        {
            if ($object -is [System.Collections.IDictionary])
            {
                $unresolvedPath = Get-DictionaryValueFromFirstKeyFound -Dictionary $object -Key 'Path', 'p'
                $arguments      = @(Get-DictionaryValueFromFirstKeyFound -Dictionary $object -Key 'Arguments', 'args', 'a')
                $parameters     = Get-DictionaryValueFromFirstKeyFound -Dictionary $object -Key 'Parameters', 'params'

                if ($unresolvedPath -isnot [string] -or $unresolvedPath -notmatch '\S')
                {
                    throw 'When passing hashtables to the -Path parameter, the Path key is mandatory, and must contain a single string.'
                }

                if ($null -ne $parameters -and $parameters -isnot [System.Collections.IDictionary])
                {
                    throw 'When passing hashtables to the -Path parameter, the Parameters key (if present) must be assigned an IDictionary object.'
                }
            }
            else
            {
                $unresolvedPath = [string] $object
                $arguments      = @()
                $parameters     = @{}
            }

            if ($unresolvedPath -notmatch '[\*\?\[\]]' -and
                (& $script:SafeCommands['Test-Path'] -LiteralPath $unresolvedPath -PathType Leaf) -and
                (& $script:SafeCommands['Get-Item'] -LiteralPath $unresolvedPath) -is [System.IO.FileInfo])
            {
                $extension = [System.IO.Path]::GetExtension($unresolvedPath)
                if ($extension -ne '.ps1')
                {
                    & $script:SafeCommands['Write-Error'] "Script path '$unresolvedPath' is not a ps1 file."
                }
                else
                {
                    & $script:SafeCommands['New-Object'] psobject -Property @{
                        Path       = $unresolvedPath
                        Arguments  = $arguments
                        Parameters = $parameters
                    }
                }
            }
            else
            {
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
                        Arguments  = $arguments
                        Parameters = $parameters
                    }
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

function Get-DictionaryValueFromFirstKeyFound
{
    param ([System.Collections.IDictionary] $Dictionary, [object[]] $Key)

    foreach ($keyToTry in $Key)
    {
        if ($Dictionary.Contains($keyToTry)) { return $Dictionary[$keyToTry] }
    }
}

function Set-ScriptBlockScope
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $true, ParameterSetName = 'FromSessionState')]
        [System.Management.Automation.SessionState]
        $SessionState,

        [Parameter(Mandatory = $true, ParameterSetName = 'FromSessionStateInternal')]
        $SessionStateInternal
    )

    $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'

    if ($PSCmdlet.ParameterSetName -eq 'FromSessionState')
    {
        $SessionStateInternal = $SessionState.GetType().GetProperty('Internal', $flags).GetValue($SessionState, $null)
    }

    [scriptblock].GetProperty('SessionStateInternal', $flags).SetValue($ScriptBlock, $SessionStateInternal, $null)
}

function Get-ScriptBlockScope
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock
    )

    $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'
    [scriptblock].GetProperty('SessionStateInternal', $flags).GetValue($ScriptBlock, $null)
}

function SafeGetCommand
{
    <#
        .SYNOPSIS
        This command is used by Pester's Mocking framework.  You do not need to call it directly.
    #>

    return $script:SafeCommands['Get-Command']
}

$snippetsDirectoryPath = "$PSScriptRoot\Snippets"
if ((& $script:SafeCommands['Test-Path'] -Path Variable:\psise) -and
    ($null -ne $psISE) -and
    ($PSVersionTable.PSVersion.Major -ge 3) -and
    (& $script:SafeCommands['Test-Path'] $snippetsDirectoryPath))
{
    Import-IseSnippet -Path $snippetsDirectoryPath
}

& $script:SafeCommands['Export-ModuleMember'] Describe, Context, It, In, Mock, Assert-VerifiableMocks, Assert-MockCalled, Set-TestInconclusive
& $script:SafeCommands['Export-ModuleMember'] New-Fixture, Get-TestDriveItem, Should, Invoke-Pester, Setup, InModuleScope, Invoke-Mock
& $script:SafeCommands['Export-ModuleMember'] BeforeEach, AfterEach, BeforeAll, AfterAll
& $script:SafeCommands['Export-ModuleMember'] Get-MockDynamicParameters, Set-DynamicParameterVariables
& $script:SafeCommands['Export-ModuleMember'] SafeGetCommand
