Get-Item function:wrapper -ErrorAction SilentlyContinue | remove-item


Get-Module Pester.Runtime, Pester.Utility, P, Pester, Axiom, Stack | Remove-Module
# Import-Module Pester -MinimumVersion 4.4.3

Import-Module $PSScriptRoot\stack.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\Pester.Utility.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\Pester.Runtime.psm1 -DisableNameChecking

$script:DisableScopeHints = $true

. $PSScriptRoot\..\Functions\Pester.Debugging.ps1
. $PSScriptRoot\..\Functions\Pester.Scoping.ps1
. $PSScriptRoot\..\Functions\Pester.SafeCommands.ps1

# imported because of New-ShouldErrorRecord
. $PSScriptRoot\..\Functions\Assertions\Should.ps1

# it only works when mock is a module (so . sourcing does not destroy the current scope)
Get-Module -Name mck | Remove-Module
New-Module -Name mck -ScriptBlock { . $PSScriptRoot\..\Functions\Mock.ps1 } | Import-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\..\Dependencies\Axiom\Axiom.psm1 -DisableNameChecking

$invokeMock = {
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

i {
    b "mocking" {


        t "function can be mocked without Pester global state" {

            $mockTable = @{}

            function f () { "real" }
            New-Mock f { "mock" } -SessionState $ExecutionContext.SessionState -MockTable $mockTable -InvokeMockCallback $invokeMock
            $actual = f

            $actual | Verify-Equal "mock"
        }


        t "1 function call can be validated without Pester global scope" {

            $mockTable = @{}

            function f () { "real" }
            New-Mock f { "mock" } -SessionState $ExecutionContext.SessionState -MockTable $mockTable -InvokeMockCallback $invokeMock

            f

            Assert-MockCalledInternal f -Times 1 -SessionState $ExecutionContext.SessionState -MockTable $mockTable
        }

        t "0 function calls can be asserted without Pester global scope" {

            $mockTable = @{}
            function f () { "real" }
            New-Mock f { "mock" } -SessionState $ExecutionContext.SessionState -MockTable $mockTable -InvokeMockCallback $invokeMock

            f

            { Assert-MockCalledInternal f -Times 0 -SessionState $ExecutionContext.SessionState -MockTable $mockTable } | Verify-Throw
        }
    }

    b "mocks with scoping" {

        t "mocks are be setup per scope and not per-block, and self remove itself" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {
                    New-Block -Name "block1" {

                        New-OneTimeTestSetup {
                            function f () { "real" }
                        }

                        New-Test "test 1" {
                            $mockTable = @{}
                            Get-Module -Name m | Remove-Module
                            New-Module -Name m -ScriptBlock { . C:\projects\pester_main\Functions\Mock.ps1 } | Import-Module
                            $invokeCallback = (Get-Command Invoke-Mock)
                            New-Mock f { "mock" } -SessionState $ExecutionContext.SessionState -MockTable $mockTable -InvokeMockCallBack $invokeMock
                            f
                        }

                        New-Test "test 2" {
                            f
                        }
                    }
                }
            )

            $actual.Blocks[0].Tests[0].StandardOutput | Verify-Equal "mock"
            $actual.Blocks[0].Tests[1].StandardOutput | Verify-Equal "real"
        }

        t "mocks are be setup by the defining block, and remove themself" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {
                    New-Block -Name "block1" {
                        New-OneTimeTestSetup {
                            function g () { "real" }
                            $mockTable = @{}

                            New-Mock g { "mock" } -SessionState $ExecutionContext.SessionState -MockTable $mockTable -InvokeMockCallBack $invokeMock

                        }
                        New-Test "test 1" {
                            g
                        }

                        New-Test "test 2" {
                            g
                        }
                    }
                }
            )

            $actual.Blocks[0].Tests[0].StandardOutput | Verify-Equal "mock"
            $actual.Blocks[0].Tests[1].StandardOutput | Verify-Equal "mock"
        }
    }
}
