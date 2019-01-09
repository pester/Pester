Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Should -Be" {
        It "returns true if the 2 arguments are equal" {
            1 | Should Be 1
            1 | Should -Be 1
            1 | Should -EQ 1
        }
        It "returns true if the 2 arguments are equal and have different case" {
            'A' | Should Be 'a'
            'A' | Should -Be 'a'
            'A' | Should -EQ 'a'
        }

        It "returns false if the 2 arguments are not equal" {
            1 | Should Not Be 2
            1 | Should -Not -Be 2
            1 | Should -Not -EQ 2
        }

        It 'Compares Arrays properly' {
            $array = @(1, 2, 3, 4, 'I am a string', (New-Object psobject -Property @{ IAm = 'An Object' }))
            $array | Should Be $array
            $array | Should -Be $array
            $array | Should -EQ $array
        }

        It 'Compares arrays with correct case-insensitive behavior' {
            $string = 'I am a string'
            $array = @(1, 2, 3, 4, $string)
            $arrayWithCaps = @(1, 2, 3, 4, $string.ToUpper())

            $array | Should Be $arrayWithCaps
            $array | Should -Be $arrayWithCaps
            $array | Should -EQ $arrayWithCaps
        }

        It 'Handles reference types properly' {
            $object1 = New-Object psobject -Property @{ Value = 'Test' }
            $object2 = New-Object psobject -Property @{ Value = 'Test' }

            $object1 | Should Be $object1
            $object1 | Should Not Be $object2
            $object1 | Should -Be $object1
            $object1 | Should -Not -Be $object2
            $object1 | Should -EQ $object1
            $object1 | Should -Not -EQ $object2
        }

        It 'Handles arrays with nested arrays' {
            $array1 = @(
                @(1, 2, 3, 4, 5),
                @(6, 7, 8, 9, 0)
            )

            $array2 = @(
                @(1, 2, 3, 4, 5),
                @(6, 7, 8, 9, 0)
            )

            $array1 | Should Be $array2
            $array1 | Should -Be $array2
            $array1 | Should -EQ $array2

            $array3 = @(
                @(1, 2, 3, 4, 5),
                @(6, 7, 8, 9, 0, 'Oops!')
            )

            $array1 | Should Not Be $array3
            $array1 | Should -Not -Be $array3
            $array1 | Should -Not -EQ $array3
        }

        It "returns true if the actual value can be cast to the expected value and they are the same value" {
            {abc} | Should Be "aBc"
            {abc} | Should -Be "aBc"
            {abc} | Should -EQ "aBc"
        }

        It "returns true if the actual value can be cast to the expected value and they are the same value (case sensitive)" {
            {abc} | Should BeExactly "abc"
            {abc} | Should -BeExactly "abc"
            {abc} | Should -CEQ "abc"
        }

        It 'Does not overflow on IEnumerable' {
            # see https://github.com/pester/Pester/issues/785
            $doc = [xml]'<?xml version="1.0" encoding="UTF-8" standalone="no" ?><root></root>'
            $doc | Should -be $doc
        }

        # The test excluded on macOS due to issue https://github.com/PowerShell/PowerShell/issues/4268
        If ((GetPesterOS) -ne 'macOS') {
            It 'throws exception when self-imposed recursion limit is reached' {
                $a1 = @(0, 1)
                $a2 = @($a1, 2)
                $a1[0] = $a2

                { $a1 | Should -be $a2 } | Should -throw 'recursion depth limit'
            }
        }

    }

    Describe "ShouldBeFailureMessage" {
        #the correctness of difference index value and the arrow pointing to the correct place
        #are not tested here thoroughly, but the behaviour was visually checked and is
        #implicitly tested by using the whole output in the following tests


        It "Returns nothing for two identical strings" {
            #this situation should actually never happen, as the code is called
            #only when the objects are not equal

            $string = "string"
            ShouldBeFailureMessage $string $string | Verify-Equal ''
        }

        It "Outputs less verbose message for two different objects that are not strings" {
            ShouldBeFailureMessage 2 1 | Verify-Equal "Expected 1, but got 2."
        }

        It "Outputs less verbose message for two different objects that are not strings, with reason" {
            ShouldBeFailureMessage 2 1 -Because 'reason' | Verify-Equal "Expected 1, because reason, but got 2."
        }

        It "Outputs verbose message for two strings of different length" {
            ShouldBeFailureMessage "actual" "expected" | Verify-Equal "Expected strings to be the same, but they were different.`nExpected length: 8`nActual length:   6`nStrings differ at index 0.`nExpected: 'expected'`nBut was:  'actual'`n-----------^"
        }

        It "Outputs verbose message for two strings of different length" {
            ShouldBeFailureMessage "actual" "expected" -Because 'reason' | Verify-Equal "Expected strings to be the same, because reason, but they were different.`nExpected length: 8`nActual length:   6`nStrings differ at index 0.`nExpected: 'expected'`nBut was:  'actual'`n-----------^"
        }

        It "Outputs verbose message for two different strings of the same length" {
            ShouldBeFailureMessage "x" "y" | Verify-Equal "Expected strings to be the same, but they were different.`nString lengths are both 1.`nStrings differ at index 0.`nExpected: 'y'`nBut was:  'x'`n-----------^"
        }

        It "Replaces non-printable characters correctly" {
            ShouldBeFailureMessage "`n`r`b`0`tx" "`n`r`b`0`ty" | Verify-Equal "Expected strings to be the same, but they were different.`nString lengths are both 6.`nStrings differ at index 5.`nExpected: '\n\r\b\0\ty'`nBut was:  '\n\r\b\0\tx'`n---------------------^"
        }

        It "The arrow points to the correct position when non-printable characters are replaced before the difference" {
            ShouldBeFailureMessage "123`n456" "123`n789" | Verify-Equal "Expected strings to be the same, but they were different.`nString lengths are both 7.`nStrings differ at index 4.`nExpected: '123\n789'`nBut was:  '123\n456'`n----------------^"
        }

        It "The arrow points to the correct position when non-printable characters are replaced after the difference" {
            ShouldBeFailureMessage "abcd`n123" "abc!`n123" | Verify-Equal "Expected strings to be the same, but they were different.`nString lengths are both 8.`nStrings differ at index 3.`nExpected: 'abc!\n123'`nBut was:  'abcd\n123'`n--------------^"
        }
    }
}

InModuleScope Pester {
    Describe "Should -BeExactly" {
        It "passes if letter case matches" {
            'a' | Should BeExactly 'a'
            'a' | Should -BeExactly 'a'
        }

        It "fails if letter case doesn't match" {
            'A' | Should Not BeExactly 'a'
            'A' | Should -Not -BeExactly 'a'
        }

        It "passes for numbers" {
            1 | Should BeExactly 1
            2.15 | Should BeExactly 2.15
            1 | Should -BeExactly 1
            2.15 | Should -BeExactly 2.15
        }

        It 'Compares Arrays properly' {
            $array = @(1, 2, 3, 4, 'I am a string', (New-Object psobject -Property @{ IAm = 'An Object' }))
            $array | Should BeExactly $array
            $array | Should -BeExactly $array
        }

        It 'Compares arrays with correct case-sensitive behavior' {
            $string = 'I am a string'
            $array = @(1, 2, 3, 4, $string)
            $arrayWithCaps = @(1, 2, 3, 4, $string.ToUpper())

            $array | Should Not BeExactly $arrayWithCaps
            $array | Should -Not -BeExactly $arrayWithCaps
        }
    }

    Describe "ShouldBeExactlyFailureMessage" {
        It "Writes verbose message for strings that differ by case" {
            ShouldBeExactlyFailureMessage "a" "A" -Because "reason" | Verify-Equal "Expected strings to be the same, because reason, but they were different.`nString lengths are both 1.`nStrings differ at index 0.`nExpected: 'A'`nBut was:  'a'`n-----------^"
        }
    }
}
