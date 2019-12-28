param ([switch] $PassThru)

Get-Module Pester.Utility, P, Axiom | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\..\Dependencies\Axiom\Axiom.psm1 -DisableNameChecking

Import-Module $PSScriptRoot\Pester.Utility.psm1 -DisableNameChecking

i -PassThru:$PassThru {
    b "Merging objects" {
        t "merges simple hashtable" {
            $default = @{
                A = "default a"
                B = "default a"
            }

            $override = @{
                A = "overrride a"
            }

            Merge-HashtableOrObject -Destination $default -Source $override
            $default.A | Verify-Equal "override a"
            $default.B | Verify-Equal "default b"
        }
    }
}
