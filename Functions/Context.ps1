function Context {
    <#
.SYNOPSIS
Provides logical grouping of It blocks within a single Describe block.

.DESCRIPTION
Provides logical grouping of It blocks within a single Describe block.
Any Mocks defined inside a Context are removed at the end of the Context scope,
as are any files or folders added to the TestDrive during the Context block's
execution. Any BeforeEach or AfterEach blocks defined inside a Context also only
apply to tests within that Context .

.PARAMETER Name
The name of the Context. This is a phrase describing a set of tests within a describe.

.PARAMETER Tag
Optional parameter containing an array of strings.  When calling Invoke-Pester,
it is possible to specify a -Tag parameter which will only execute Context blocks
containing the same Tag.

.PARAMETER Fixture
Script that is executed. This may include setup specific to the context
and one or more It blocks that validate the expected outcomes.

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
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Name,

        [Alias('Tags')]
        [string[]] $Tag = @(),

        [Parameter(Position = 1)]
        [ValidateNotNull()]
        [ScriptBlock] $Fixture = $(Throw "No test script block is provided. (Have you put the open curly brace on the next line?)")
    )

    if ($null -eq (& $SafeCommands['Get-Variable'] -Name Pester -ValueOnly -ErrorAction $script:IgnoreErrorPreference)) {
        # User has executed a test script directly instead of calling Invoke-Pester
        $sessionState = Set-SessionStateHint -PassThru -Hint "Caller - Captured in Context" -SessionState $PSCmdlet.SessionState
        $Pester = New-PesterState -Path (& $SafeCommands['Resolve-Path'] .) -TestNameFilter $null -TagFilter @() -SessionState SessionState
        $script:mockTable = @{}
    }

    DescribeImpl @PSBoundParameters -CommandUsed 'Context' -Pester $Pester -DescribeOutputBlock ${function:Write-Describe} -TestOutputBlock ${function:Write-PesterResult} -NoTestRegistry:('Windows' -ne (GetPesterOs))
}
