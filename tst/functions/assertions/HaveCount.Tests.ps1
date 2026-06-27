Set-StrictMode -Version Latest

InPesterModuleScope {

    Describe "Should -HaveCount" {
        It "passes if collection has the expected amount of items" {
            @(1, 'a', 3) | Should -HaveCount 3
        }

        It "passes given scalar value and expecting collection of count 1" {
            'a' | Should -HaveCount 1
        }

        It "fails if collection has less values" {
            { @('a', 3) | Should -HaveCount 3 } | Verify-AssertionFailed
        }

        It "fails if collection has more values" {
            { @(1, 'a', 3, 4) | Should -HaveCount 3 } | Verify-AssertionFailed
        }

        It "fails if given scalar value" {
            { 'a' | Should -HaveCount 3 } | Verify-AssertionFailed
        }

        It "returns the correct assertion message when collection is not empty" {
            $err = { @(1, 'a', 3, 4) | Should -HaveCount 3 -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected a collection with size 3, because reason, but got collection with size 4 @(1, 'a', 3, 4)."
        }

        It "returns the correct assertion message when collection is not empty" {
            $err = { @() | Should -HaveCount 3 -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal 'Expected a collection with size 3, because reason, but got an empty collection.'
        }

        It "returns the correct assertion message when collection is not empty" {
            $err = { @(1) | Should -HaveCount 0 -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal 'Expected an empty collection, because reason, but got collection with size 1 1.'
        }

        It "validates the expected size to be bigger than 0" {
            $err = { @(1) | Should -HaveCount (-1) } | Verify-Throw
            $err.Exception | Verify-Type ([ArgumentException])
        }
    }

    Describe "Should -HaveCount with dictionaries" {
        # The pipeline does not enumerate dictionaries and hashtables, so they arrive
        # as a single item. HaveCount looks inside and counts their entries. (#1234, #1200)

        It "counts the entries of a hashtable" {
            @{ Property1 = '1'; Property2 = '3' } | Should -HaveCount 2
        }

        It "counts an empty hashtable as 0" {
            @{} | Should -HaveCount 0
        }

        It "counts the entries of an ordered dictionary" {
            ([ordered]@{ a = 1; b = 2; c = 3 }) | Should -HaveCount 3
        }

        It "counts the entries of a generic dictionary" {
            $dictionary = [System.Collections.Generic.Dictionary[string, string]]::new()
            $dictionary.Add('a', '1')
            $dictionary.Add('b', '2')
            $dictionary | Should -HaveCount 2
        }

        It "counts an empty generic dictionary as 0" {
            [System.Collections.Generic.Dictionary[string, string]]::new() | Should -HaveCount 0
        }

        It "counts the entries of a hashtable passed via -ActualValue" {
            Should -ActualValue @{ Property1 = '1'; Property2 = '3' } -HaveCount 2
        }

        It "counts the entries of a single dictionary wrapped in an array" {
            # The accepted trade-off: an array holding one dictionary counts the
            # dictionary's entries, not the array's single item.
            @(@{ a = 1; b = 2 }) | Should -HaveCount 2
        }
    }

    Describe "Should -HaveCount with `$null" {
        # Casting an empty pipeline to [System.Array] yields @($null) - a one-element
        # array holding $null - which should count as empty. (#1000)

        It "counts a lone `$null as 0" {
            , $null | Should -HaveCount 0
        }

        It "counts an array casted from an empty pipeline as 0" {
            $value = [System.Array] (1..3 | Where-Object { $false })
            $value | Should -HaveCount 0
        }

        It "counts an empty result piped without casting as 0" {
            (1..3 | Where-Object { $false }) | Should -HaveCount 0
        }
    }

    Describe "Should -HaveCount with single objects" {
        It "counts a scalar as 1" {
            'a' | Should -HaveCount 1
        }

        It "counts a single object that is not a collection as 1" {
            (Get-Date) | Should -HaveCount 1
        }

        It "counts a single PSCustomObject as 1" {
            ([pscustomobject]@{ a = 1; b = 2 }) | Should -HaveCount 1
        }
    }

    Describe "Should -Not -HaveCount" {
        It "passes if collection does not have the expected count of items" {
            @(1, 'a', 3, 4) | Should -Not -HaveCount 3
        }

        It "fails if collection HaveCounts the value" {
            { @(1, 'a', 3) | Should -Not -HaveCount 3 } | Verify-AssertionFailed
        }

        It "returns the correct assertion message" {
            $err = { @(1, 'a', 3) | Should -Not -HaveCount 3 -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected a collection with size different from 3, because reason, but got collection with that size @(1, 'a', 3)."
        }

        It "returns the correct assertion message" {
            $err = { @() | Should -Not -HaveCount 0 -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal 'Expected a non-empty collection, because reason, but got an empty collection.'
        }

        It "validates the expected size to be bigger than 0" {
            $err = { @(1) | Should -HaveCount (-1) } | Verify-Throw
            $err.Exception | Verify-Type ([ArgumentException])
        }
    }
}
