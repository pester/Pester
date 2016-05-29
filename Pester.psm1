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

# Not all platforms have Get-WmiObject (Nano)
# Get-CimInstance is prefered, but we can use Get-WmiObject if it exists
# Moreover, it shouldn't really be fatal if neither of those cmdlets
# exist 
if ( Get-Command -ea SilentlyContinue Get-CimInstance )
{
    $script:SafeCommands['Get-CimInstance'] = Get-Command -Name Get-CimInstance -Module CimCmdlets -CommandType Cmdlet -ErrorAction Stop
}
elseif ( Get-command -ea SilentlyContinue Get-WmiObject )
{
    $script:SafeCommands['Get-WmiObject']   = Get-Command -Name Get-WmiObject   -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
}
else
{
    Write-Warning "OS Information retrieval is not possible, reports will contain only partial system data"
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
Invokes Pester to run all tests (files containing *.Tests.ps1) recursively under
the Path

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

Also, by default, Pester tests write test results to the host program, much like 
Write-Host does, but you can use the Quiet parameter to supress the host 
messages, use the PassThru parameter to generate a custom object 
(PSCustomObject) that contains the test results, use the OutputXml and 
OutputFormat parameters to write the test results to an XML file, and use the 
EnableExit parameter to return an exit code that contains the number of failed 
tests. 

You can also use the Strict parameter to fail all pending and skipped tests. 
This feature is ideal for build systems and other processes that require success 
on every test. 

To help with test design, Invoke-Pester includes a CodeCoverage parameter that 
lists commands, functions, and lines of code that did not run during test 
execution and returns the code that ran as a percentage of all tested code.

Invoke-Pester, and the Pester module that exports it, are products of an 
open-source project hosted on GitHub. To view, comment, or contribute to the 
repository, see https://github.com/Pester.

.PARAMETER Script
Specifies test files by path or file name or name pattern. You can also use the 
Script parameter to pass parameter names and values to a script that contains 
Pester tests.

The Script parameter is optional. If you omit it, Invoke-Pester runs all 
*.Tests.ps1 files in the local directory and its subdirectories recursively. Use 
the TestName, Tag, and ExcludeTag parameters with or without the Script 
parameter, to specify the tests to run.

The value of the Script parameter can be a string, a hash table, or a collection 
of hash tables and strings.

To specify test files by path or name, enter a string with the path or path\name, 
or a name pattern. Wildcards characters are supported. You can specify the name 
of any file that includes Pester tests. This value is not limited to files with 
the *.Tests.ps1 file name pattern.

To run a Pester test with parameter names and values, use a hash table as the 
value of the script parameter. The keys in the hash table are:

-- Path [string] (required): Specifies a test to run. The value is a path\file 
   name or name pattern. Wildcards are permitted. All hash tables in a Script 
   parameter value must have a Path key. 
	
-- Parameters [hashtable]: Runs the script with the specified parameters. The 
   value is hash table with parameter name and value pairs, such as 
   @{UserName = 'User01'; Id = '28'}. 
	
-- Arguments [array]: An array or comma-separated list of parameter values 
   without names. Use this key to pass values to positional parameters.
	

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

.PARAMETER PesterOption
Sets advanced options for the test execution. Enter a PesterOption object, such as one that you create by using the New-PesterOption cmdlet, or a hash table in which the keys are option names and the values are option values.
For more information on the options available, see the help for New-PesterOption.

.Example
Invoke-Pester

This will find all *.Tests.ps1 files and run their tests. No exit code will be returned and no log file will be saved.

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
Invoke-Pester -TestName "Add Numbers"

This command runs only the tests in the Describe block named "Add Numbers".

.Example
Invoke-Pester -EnableExit -OutputFile ".\artifacts\TestResults.xml" -OutputFormat NUnitXml

This command runs all tests in the current directory and its subdirectories. It
writes the results to the TestResults.xml file using the NUnitXml schema. The 
test returns an exit code equal to the number of test failures.

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
New-PesterOption

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

        [Parameter(ParameterSetName = 'NewOutputSet')]
        [ValidateSet('LegacyNUnitXml', 'NUnitXml')]
        [string] $OutputFormat = 'NUnitXml',

        [Switch]$Quiet,

        [object]$PesterOption
    )

    if ($PSBoundParameters.ContainsKey('OutputXml'))
    {
        & $script:SafeCommands['Write-Warning'] 'The -OutputXml parameter has been deprecated; please use the new -OutputFile and -OutputFormat parameters instead.  To get the same type of export that the -OutputXml parameter currently provides, use an -OutputFormat of "LegacyNUnitXml".'

        & $script:SafeCommands['Start-Sleep'] -Seconds 2

        $OutputFile = $OutputXml
        $OutputFormat = 'LegacyNUnitXml'
    }

    $script:mockTable = @{}

    $pester = New-PesterState -TestNameFilter $TestName -TagFilter ($Tag -split "\s") -ExcludeTagFilter ($ExcludeTag -split "\s") -SessionState $PSCmdlet.SessionState -Strict:$Strict -Quiet:$Quiet -PesterOption $PesterOption
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

    $testScripts = @(ResolveTestScripts $Script)

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

            # This is a hack to ensure that XML output is valid for now.  The test-suite names come from the Describe attribute of the TestResult
            # objects, and a blank name is invalid NUnit XML.  This will go away when we promote test scripts to have their own test-suite nodes,
            # planned for v4.0
            $pester.TestResult[-1].Describe = "Error in $($testScript.Path)"

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

function New-PesterOption
{
<#
.SYNOPSIS
   Creates an object that contains advanced options for Invoke-Pester
.PARAMETER IncludeVSCodeMarker
   When this switch is set, an extra line of output will be written to the console for test failures, making it easier
   for VSCode's parser to provide highlighting / tooltips on the line where the error occurred.
.INPUTS
   None
   You cannot pipe input to this command.
.OUTPUTS
   System.Management.Automation.PSObject
.LINK
   Invoke-Pester
#>

    [CmdletBinding()]
    param (
        [switch] $IncludeVSCodeMarker
    )

    return & $script:SafeCommands['New-Object'] psobject -Property @{
        IncludeVSCodeMarker = [bool]$IncludeVSCodeMarker
    }
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

                if ($null -eq $Parameters) { $Parameters = @{} }

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
& $script:SafeCommands['Export-ModuleMember'] New-Fixture, Set-Fixture, Get-TestDriveItem, Should, Invoke-Pester, Setup, InModuleScope, Invoke-Mock
& $script:SafeCommands['Export-ModuleMember'] BeforeEach, AfterEach, BeforeAll, AfterAll
& $script:SafeCommands['Export-ModuleMember'] Get-MockDynamicParameters, Set-DynamicParameterVariables
& $script:SafeCommands['Export-ModuleMember'] SafeGetCommand, New-PesterOption
