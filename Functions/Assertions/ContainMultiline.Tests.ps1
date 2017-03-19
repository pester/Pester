Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "PesterContainMultiline" {
        Context "when testing file contents" {
            Setup -File "test.txt" "this is line 1`nthis is line 2`nPester is awesome"
            It "returns true if the file matches the specified content on one line" {
                "$TestDrive\test.txt" | Should ContainMultiline  "Pester"
            }

            It "returns true if the file matches the specified content across multiple lines" {
                "$TestDrive\test.txt" | Should ContainMultiline  "line 2`nPester"
            }

            It "returns false if the file does not contain the specified content" {
                "$TestDrive\test.txt" | Should Not ContainMultiline  "Pastor"
            }
        }
    }
}
