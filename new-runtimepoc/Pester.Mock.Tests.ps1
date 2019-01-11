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


Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\..\Dependencies\Axiom\Axiom.psm1 -DisableNameChecking

C:\Projects\pester_main\Functions\Pester.Debugging.ps1

b "mocking" {
    dt "function can be mocked" {
        $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
            New-BlockContainerObject -ScriptBlock {
                New-Block -Name "block1" {
                    New-Test "test 1" {
                        function f () { "real" }
                        New-Mock f { "mock" } -SessionState $ExecutionContext.SessionState

                        # now it fails here, on null array, most likely cannot find the mock in the table.
                        # look at the mock lookup code
                        f
                    }
                }
            }
        )

        $actual.Blocks[0].Tests[0].StandardOutput | Verify-Equal "mock"
    }
}
