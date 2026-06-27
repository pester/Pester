Set-StrictMode -Version Latest

Describe "Should-BeHashtable" {
    It "Passes when the value is a hashtable or dictionary" -ForEach @(
        @{ Actual = @{} }
        @{ Actual = @{ Name = 'Jakub' } }
        @{ Actual = [ordered]@{ a = 1; b = 2 } }
        @{ Actual = (& { $d = [System.Collections.Generic.Dictionary[string, int]]::new(); $d['x'] = 1; $d }) }
    ) {
        $Actual | Should-BeHashtable
    }

    It "Fails when the value is not a hashtable" -ForEach @(
        @{ Actual = @(1, 2, 3) }
        @{ Actual = 1 }
        @{ Actual = 'hello' }
        @{ Actual = $null }
        @{ Actual = [PSCustomObject]@{ Name = 'Jakub' } }
    ) {
        $err = { $Actual | Should-BeHashtable } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Like 'Expected a hashtable, but got *'
    }

    It "Can be used with the -Actual parameter" {
        Should-BeHashtable -Actual @{ Name = 'Jakub' }
    }

    It "Can be used with positional parameters" {
        Should-BeHashtable @{ Name = 'Jakub' }
    }

    Describe "-Count" {
        It "Passes when the hashtable has the expected number of entries" -ForEach @(
            @{ Actual = @{}; Count = 0 }
            @{ Actual = @{ a = 1 }; Count = 1 }
            @{ Actual = @{ a = 1; b = 2 }; Count = 2 }
            @{ Actual = [ordered]@{ a = 1; b = 2; c = 3 }; Count = 3 }
        ) {
            $Actual | Should-BeHashtable -Count $Count
        }

        It "Fails when the hashtable does not have the expected number of entries" {
            $err = { @{ a = 1 } | Should-BeHashtable -Count 2 } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Like 'Expected 2 entries in hashtable *, but it has 1 entries.'
        }

        It "Fails the type check before counting when the value is not a hashtable" {
            $err = { @(1, 2) | Should-BeHashtable -Count 2 } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Like 'Expected a hashtable, but got *'
        }
    }

    Describe "-Ordered" {
        It "Passes when the value is an ordered dictionary" {
            [ordered]@{ a = 1; b = 2 } | Should-BeHashtable -Ordered
        }

        It "Fails when the value is an unordered hashtable" {
            $err = { @{ a = 1 } | Should-BeHashtable -Ordered } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Like 'Expected an ordered hashtable (`[ordered`]@{}), but got unordered *'
        }

        It "Can be combined with -Count" {
            [ordered]@{ a = 1; b = 2 } | Should-BeHashtable -Ordered -Count 2
        }
    }

    Describe "-Key" {
        It "Passes when all the given keys are present" {
            @{ Name = 'Jakub'; Age = 30 } | Should-BeHashtable -Key Name, Age
        }

        It "Matches keys using the dictionary comparer, so hashtable keys are case-insensitive" {
            @{ Name = 'Jakub' } | Should-BeHashtable -Key 'NAME'
        }

        It "Ignores the values of the keys" {
            @{ Name = $null } | Should-BeHashtable -Key Name
        }

        It "Fails when a single key is missing" {
            $err = { @{ Name = 'Jakub' } | Should-BeHashtable -Key Age } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Like "Expected hashtable * to contain key 'Age', but it does not."
        }

        It "Fails when multiple keys are missing" {
            $err = { @{ Name = 'Jakub' } | Should-BeHashtable -Key Age, City } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Like "Expected hashtable * to contain keys 'Age', 'City', but it does not."
        }

        Describe "with -Ordered" {
            It "Passes when the keys are present in the given order" {
                [ordered]@{ a = 1; b = 2; c = 3 } | Should-BeHashtable -Ordered -Key a, c
            }

            It "Fails when the keys are present but in a different order" {
                $err = { [ordered]@{ a = 1; b = 2; c = 3 } | Should-BeHashtable -Ordered -Key c, a } | Verify-AssertionFailed
                $err.Exception.Message | Verify-Like "Expected keys 'c', 'a' to appear in this order in hashtable *, but the actual key order is 'a', 'b', 'c'."
            }
        }
    }
}
