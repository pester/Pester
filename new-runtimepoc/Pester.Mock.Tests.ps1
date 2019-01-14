Get-Item function:wrapper -ErrorAction SilentlyContinue | remove-item


Get-Module Pester.Runtime, Pester.Utility, P, Pester, Axiom, Stack | Remove-Module
# Import-Module Pester -MinimumVersion 4.4.3

Import-Module $PSScriptRoot\stack.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\Pester.Utility.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\Pester.Runtime.psm1 -DisableNameChecking

$script:DisableScopeHints = $true
. $PSScriptRoot\..\Functions\Mock.ps1
. $PSScriptRoot\..\Functions\Pester.Debugging.ps1
. $PSScriptRoot\..\Functions\Pester.Scoping.ps1
. $PSScriptRoot\..\Functions\Pester.SafeCommands.ps1

# imported because of New-ShouldErrorRecord
. $PSScriptRoot\..\Functions\Assertions\Should.ps1


Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\..\Dependencies\Axiom\Axiom.psm1 -DisableNameChecking

C:\Projects\pester_main\Functions\Pester.Debugging.ps1

i {
    b "mocking" {
        function Invoke-Mock {
            [CmdletBinding()]
            param (
                [Parameter(Mandatory = $true)] [string] $CommandName,
                [Parameter(Mandatory = $true)] [hashtable] $MockCallState,
                [string] $ModuleName,
                [hashtable] $BoundParameters = @{},
                [object[]] $ArgumentList = @(),
                [object] $CallerSessionState,
                [ValidateSet('Begin', 'Process', 'End')] [string] $FromBlock,
                [object] $InputObject
            )

            # this is a simple implementation of a callback that happens
            # when user calls the mock bootstrap function. This is needed
            # so I can use a simple mock table here in tests, and other
            # implementations can use a more complex implementation that
            # uses multiple mocktables and merges them based on the current
            # scope and other parameters (this keeps the internal implementation)
            # simple and concerned only with a single flat mock table and not
            # many tables

            # uses the mock table defined in the parent scope
            Invoke-MockInternal @PSBoundParameters -MockTable $mockTable -SessionState $ExecutionContext.SessionState
        }

        t "function can be mocked without Pester global state" {

            $mockTable = @{}

            function f () { "real" }
            New-Mock f { "mock" } -SessionState $ExecutionContext.SessionState -MockTable $mockTable

            $actual = f

            $actual | Verify-Equal "mock"
        }


        t "1 function call can be validated without Pester global scope" {

            $mockTable = @{}

            function f () { "real" }
            New-Mock f { "mock" } -SessionState $ExecutionContext.SessionState -MockTable $mockTable

            f

            Assert-MockCalledInternal f -Times 1 -SessionState $ExecutionContext.SessionState -MockTable $mockTable
        }

        t "0 function calls can be asserted without Pester global scope" {

            $mockTable = @{}

            function f () { "real" }
            New-Mock f { "mock" } -SessionState $ExecutionContext.SessionState -MockTable $mockTable

            f

            { Assert-MockCalledInternal f -Times 0 -SessionState $ExecutionContext.SessionState -MockTable $mockTable } | Verify-Throw
        }
    }
}
