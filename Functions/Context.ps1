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
        $Tag=@(),

        [Parameter(Position = 1)]
        [ValidateNotNull()]
        [ScriptBlock] $Fixture = $(Throw "No test script block is provided. (Have you put the open curly brace on the next line?)")
    )

    Describe @PSBoundParameters -CommandUsed Context
}
