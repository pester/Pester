# Pester
# Version: $version$
# Changeset: $sha$

function Get-VariableAsHash {
    $hash = @{}
    Get-Variable | ForEach-Object {
      $key = $_.Name
      $hash.$key = ""
    }

    return $hash
}

@("$PSScriptRoot\Functions\*.ps1",
  "$PSScriptRoot\Functions\Assertions\*.ps1"
 ) | Resolve-Path |
  ? { -not ($_.ProviderPath.Contains(".Tests.")) } |
  % { . $_.ProviderPath }

function Invoke-Pester {
<#
.SYNOPSIS
Invokes Pester to run all tests (files containing *Tests.ps1) recursively under the Path

.DESCRIPTION
Upon calling Invoke-Pester. All files that have a name containing 
"*Tests.ps1" will have there tests defined in their Describe blocks 
executed. Invoke-Pester begins at the location of Path and 
runs recursively through each sub directory looking for 
*Tests.ps1 files for tests to run. If a TestName is provided, 
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

.PARAMETER Path
The path where Invoke-Pester begins to search for test files. The default is the current directory. Aliased 'relative_path' for backwards compatibility.

.PARAMETER TestName
Informs Invoke-Pester to only run Describe blocks that match this name.

.PARAMETER EnableExit
Will cause Invoke-Pester to exit with a exit code equal to the number of failed tests once all tests have been run. Use this to "fail" a build when any tests fail.

.PARAMETER OutputXml
The path where Invoke-Pester will save a NUnit formatted test results log file. If this path is not provided, no log will be generated.

.PARAMETER Tag 
Informs Invoke-Pester to only run Describe blocks tagged with the tags specified. Aliased 'Tags' for backwards compatibility.

.PARAMETER PassThru
Returns a Pester result object containing the information about the whole test run, and each test.

.Example
Invoke-Pester

This will find all *Tests.ps1 files and run their tests. No exit code will be returned and no log file will be saved.

.Example
Invoke-Pester ./tests/Utils*

This will run all tests in files under ./Tests that begin with Utils and alsocontains .Tests.

.Example
Invoke-Pester -TestName "Add Numbers"

This will only run the Describe block named "Add Numbers"

.Example
Invoke-Pester -EnableExit -OutputXml "./artifacts/TestResults.xml"

This runs all tests from the current directory downwards and writes the results according to the NUnit schema to artifatcs/TestResults.xml just below the current directory. The test run will return an exit code equal to the number of test failures.

.LINK
Describe
about_pester

#>
    param(
        [Parameter(Position=0,Mandatory=0)]
        [Alias('relative_path')]
        [string]$Path = ".",
        [Parameter(Position=1,Mandatory=0)]
        [string]$TestName, 
        [Parameter(Position=2,Mandatory=0)]
        [switch]$EnableExit, 
        [Parameter(Position=3,Mandatory=0)]
        [string]$OutputXml,
        [Parameter(Position=4,Mandatory=0)]
        [Alias('Tags')]
		[string]$Tag,
        [switch]$EnableLegacyExpectations,
		[switch]$PassThru
    )

    $script:mockTable = @{}

    # $PSCmdlet.SessionState is the caller's session state.  We use that scope to invoke the test scripts, and also assign it to the $pester.SessionState
    # property so mocking can happen in the correct scope later on.

	$pester = New-PesterState -Path (Resolve-Path $Path) -TestNameFilter $TestName -TagFilter ($Tag -split "\s") -SessionState $PSCmdlet.SessionState
    
	# TODO make this work again $pester.starting_variables = Get-VariableAsHash
    

  if ($EnableLegacyExpectations) {
      "WARNING: Enabling deprecated legacy expectations. " | Write-Host -Fore Yellow -Back DarkGray
      . "$PSScriptRoot\ObjectAdaptations\PesterFailure.ps1"
      Update-TypeData -pre "$PSScriptRoot\ObjectAdaptations\types.ps1xml" -ErrorAction SilentlyContinue
  }

  Write-Host Executing all tests in $($pester.Path)

  $scriptBlock = { & $args[0] }
  Set-ScriptBlockScope -ScriptBlock $scriptBlock -SessionState $PSCmdlet.SessionState
  
  Get-ChildItem $pester.Path -Filter "*Tests.ps1" -Recurse |
  where { -not $_.PSIsContainer } |
  foreach { & $scriptBlock $_.PSPath }

  $pester | Write-PesterReport

  if($OutputXml) {
      #TODO make this legacy option and move the nUnit report out of invoke-pester
			#TODO add warning message that informs the user how to use the nunit output properly
			Export-NunitReport $pester $OutputXml 
  }
	
	if ($PassThru) { 
		#remove all runtime properties like current* and Scope
		$pester | Select -Property "Path","TagFilter","TestNameFilter","TotalCount","PassedCount","FailedCount","Time","TestResult"
	}
  if ($EnableExit) { Exit-WithCode -FailedCount $pester.FailedCount }
	
}

function Set-ScriptBlockScope
{
    <#
        Pester now executes test scripts in the scope of the caller, wherever possible.  This utility function is the work horse for that separation, binding
        an instance of [scriptblock] to a particular session state before invoking it.

        This is used in several places in Mock.ps1, as well as Invoke-Pester, Describe, and InModuleScope.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.SessionState]
        $SessionState
    )

    $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'
    $sessionStateInternal = $SessionState.GetType().GetProperty('Internal', $flags).GetValue($SessionState, $null)
    [scriptblock].GetProperty('SessionStateInternal', $flags).SetValue($scriptBlock, $sessionStateInternal, $null)
}

Export-ModuleMember Describe, Context, It, In, Mock, Assert-VerifiableMocks, Assert-MockCalled
Export-ModuleMember New-Fixture, Get-TestDriveItem, Should, Invoke-Pester, Setup, InModuleScope, Invoke-Mock
