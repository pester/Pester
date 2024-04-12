param ([switch] $PassThru)

Get-Module P, PTestHelpers, Pester, Axiom | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\axiom\Axiom.psm1 -DisableNameChecking

. $PSScriptRoot\..\src\Pester.Utility.ps1

i -PassThru:$PassThru {
    b "Merging objects" {
        t "merges simple hashtable into destination" {
            $default = [PSCustomObject] @{
                A = "default a"
                B = "default b"
            }

            $override = @{
                A = "override a"
            }

            Merge-HashtableOrObject -Destination $default -Source $override
            $default.A | Verify-Equal "override a"
            $default.B | Verify-Equal "default b"
        }

        t "merges hashtable with hashtables in it into destination" {
            $default = [PSCustomObject]@{
                A = "default a"
                B = "default b"
                C = [PSCustomObject] @{
                    D = "default d"
                    E = "default e"
                }
            }

            $override = @{
                A = "override a"
                C = @{
                    D = "override d"
                }
                G = @{
                    H = "override h"
                }
            }


            Merge-HashtableOrObject -Destination $default -Source $override
            $default.A | Verify-Equal "override a"
            $default.B | Verify-Equal "default b"
            $default.C.D | Verify-Equal "override d"
            $default.C.E | Verify-Equal "default e"
            $default.G.H | Verify-Equal "override h"
        }

        t "merges hashtable into ps object" {
            $default = [PSCustomObject] @{
                A = "default a"
                B = "default b"
                C = [PSCustomObject] @{
                    D = "default d"
                    E = "default e"
                }
            }

            $override = @{
                A = "override a"
                C = @{
                    D = "override d"
                }
                G = @{
                    H = "override h"
                }
            }


            Merge-HashtableOrObject -Destination $default -Source $override
            $default.A | Verify-Equal "override a"
            $default.B | Verify-Equal "default b"
            $default.C.D | Verify-Equal "override d"
            $default.C.E | Verify-Equal "default e"
            $default.G.H | Verify-Equal "override h"
        }
    }
}
