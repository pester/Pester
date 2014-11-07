function Context {
<#
.SYNOPSIS
Provides logical grouping of It blocks within a single Describe block. Any Mocks defined
inside a Context are removed at the end of the Context scope, as are any files or folders
added to the TestDrive during the Context block's execution. Any BeforeEach or AfterEach
blocks defined inside a Context also only apply to tests within that Context .

.PARAMETER Name
The name of the Context. This is a phrase describing a set of tests within a describe.

.PARAMETER Fixture
Script that is executed. This may include setup specific to the context and one or more It
blocks that validate the expected outcomes.

.EXAMPLE
function Add-Numbers($a, $b) {
    return $a + $b
}

Describe "Add-Numbers" {

    Context "when root does not exist" {
         It "..." { ... }
    }

    Context "when root does exist" {
        It "..." { ... }
        It "..." { ... }
        It "..." { ... }
    }
}

.LINK
Describe
It
BeforeEach
AfterEach
about_Should
about_Mocking
about_TestDrive

#>
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [ValidateNotNull()]
        [ScriptBlock] $Fixture  = $(Throw "No test script block is provided. (Have you put the open curly brace on the next line?)")
    )

    ContextImpl @PSBoundParameters -Pester $Pester -ContextOutputBlock ${function:Write-Context} -TestOutputBlock ${function:Write-PesterResult}
}

function ContextImpl
{
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [ValidateNotNull()]
        [ScriptBlock] $Fixture  = $(Throw "No test script block is provided. (Have you put the open curly brace on the next line?)"),

        $Pester,
        [scriptblock] $ContextOutputBlock,
        [scriptblock] $TestOutputBlock
    )

    Assert-DescribeInProgress -CommandName Context

    $Pester.EnterContext($Name)
    $TestDriveContent = Get-TestDriveChildItem

    if ($null -ne $ContextOutputBlock)
    {
        $Pester.CurrentContext | & $ContextOutputBlock
    }

    try
    {
        Add-SetupAndTeardown -ScriptBlock $Fixture
        $null = & $Fixture
    }
    catch
    {
        $firstStackTraceLine = $_.InvocationInfo.PositionMessage.Trim() -split '\r?\n' | Select-Object -First 1
        $Pester.AddTestResult('Error occurred in Context block', "Failed", $null, $_.Exception.Message, $firstStackTraceLine)

        if ($null -ne $TestOutputBlock)
        {
            $Pester.TestResult[-1] | & $TestOutputBlock
        }
    }

    Clear-SetupAndTeardown
    Clear-TestDrive -Exclude ($TestDriveContent | Select-Object -ExpandProperty FullName)
    Exit-MockScope

    $Pester.LeaveContext()
}
