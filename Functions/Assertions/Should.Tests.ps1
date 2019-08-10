Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe -Tag "Acceptance" "Should" {
        It "can use the Be assertion" {
            1 | Should -Be 1
        }

        It "can use the Not Be assertion" {
            1 | Should -Not -Be 2
        }

        It "can use the BeNullOrEmpty assertion" {
            $null | Should -BeNullOrEmpty
            @()   | Should -BeNullOrEmpty
            ""    | Should -BeNullOrEmpty
        }

        It "can use the Not BeNullOrEmpty assertion" {
            @("foo") | Should -Not -BeNullOrEmpty
            "foo"    | Should -Not -BeNullOrEmpty
            "   "    | Should -Not -BeNullOrEmpty
            @(1, 2, 3) | Should -Not -BeNullOrEmpty
            12345    | Should -Not -BeNullOrEmpty
            $item1 = New-Object PSObject -Property @{Id = 1; Name = "foo"}
            $item2 = New-Object PSObject -Property @{Id = 2; Name = "bar"}
            @($item1, $item2) | Should -Not -BeNullOrEmpty
        }

        It "can handle exception thrown assertions" {
            { foo } | Should -Throw
        }

        It "can handle exception should not be thrown assertions" {
            { $foo = 1 } | Should -Not -Throw
        }

        It "can handle Exist assertion" {
            "TestDrive:" | Should -Exist
        }

        It "can handle the Match assertion" {
            "abcd1234" | Should -Match "d1"
        }

        It "can test for file contents" {
            "expected text" | Set-Content "TestDrive:\test.foo"
            "TestDrive:\test.foo" | Should -FileContentMatch "expected text"
        }

        It "ensures all assertion functions provide failure messages" {
            $assertionFunctions = @("ShouldBe", "ShouldThrow", "ShouldBeNullOrEmpty", "ShouldExist",
                "ShouldMatch", "ShouldFileContentMatch")
            $assertionFunctions | ForEach-Object {
                "function:$($_)FailureMessage" | Should -Exist
                "function:Not$($_)FailureMessage" | Should -Exist
            }
        }

        # TODO: understand the purpose of this test, perhaps some better wording
        Context "can process functions with empty output as input" {
            BeforeAll {
                function ReturnNothing {
                }
            }

            It 'throws using ErrorAction Stop' {
                { $(ReturnNothing) | Should -Not -BeNullOrEmpty -ErrorAction Stop } | Verify-Throw
            }

            It 'does not throw without ErrorAction Stop' {
                $errors = @({ $(ReturnNothing) | Should -Not -BeNullOrEmpty } | Verify-AssertionFailed)

                $errors.Count | Should -Be 1
            }
        }

        # Assertion messages aren't convention-based anymore, but we should probably still make sure
        # that our tests are complete (including negative tests) to verify the proper messages get
        # returned.  Those will need to exist in other tests files.

        <#
        It 'All failure message functions are present' {
            $assertionFunctions = Get-Command -CommandType Function -Module Pester |
                                  Select -ExpandProperty Name |
                                  Where { $_ -like 'Pester*' -and $_ -notlike '*FailureMessage' }

            $missingFunctions = @(
                foreach ($assertionFunction in $assertionFunctions)
                {
                    $positiveFailureMessage = "${assertionFunction}FailureMessage"
                    $negativeFailureMessage = "Not${assertionFunction}FailureMessage"

                    if (-not (Test-Path function:$positiveFailureMessage)) { $positiveFailureMessage }
                    if (-not (Test-Path function:$negativeFailureMessage)) { $negativeFailureMessage }
                }
            )

            [string]$missingFunctions | Should BeNullOrEmpty
        }
        #>
    }

    Describe 'Compound Assertions' {
        $script:functionBlock = {
            function Get-Object {
                [PSCustomObject]@{
                    Name = 'Rene'
                    Age = 28
                }
            }
        }

        Context "ErrorAction specification" {
            BeforeAll {
                . $script:functionBlock
            }

            It "with ErrorAction" {
                $user = Get-Object
                $user | Should -Not -Be $null -ErrorAction Stop
            }

            It 'without ErrorAction' {
                $user = Get-Object
                $user | Should -Not -Be $null
            }
        }

        Context "Chained assertions" {
            BeforeAll {
                . $script:functionBlock
            }

            It "Succeeding without ErrorAction " {
                $user = Get-Object

                $user |
                    Should -BeOfType PSCustomObject |
                    Should -Not -Be $null
            }

            It "Failing without ErrorAction" {
                $user = Get-Object

                $errors = @({
                    $user |
                        Should -Not -BeOfType PSCustomObject |
                        Should -Be $null
                } | Verify-AssertionFailed)

                $errors.Count | Should -Be 2
            }

            It "With ErrorAction in first assertions section" {
                $user = Get-Object

                $errors = @({
                    $user |
                        Should -Not -BeOfType PSCustomObject -ErrorAction Stop |
                        Should -Be $null
                } | Verify-AssertionFailed)

                $errors.Count | Should -Be 1
            }

            It "With ErrorAction in last assertion section" {
                $user = Get-Object

                $errors = @({
                    $user |
                        Should -Not -BeOfType PSCustomObject |
                        Should -Be $null -ErrorAction Stop
                } | Verify-AssertionFailed)

                $errors.Count | Should -Be 2
            }
        }

        Context "Mixing" {
            BeforeAll {
                . $script:functionBlock
            }

            It "ErrorAction on Single assertion" {
                $user = Get-Object
                $errors = @({
                    $user | Should -Be $null -ErrorAction Stop

                    $user |
                        Should -Not -BeOfType PSCustomObject |
                        Should -Be $null
                } | Verify-AssertionFailed)

                $errors.Count | Should -Be 1
            }

            It 'No ErrorAction' {
                $user = Get-Object
                $errors = @({
                    $user | Should -Be $null

                    $user |
                        Should -Not -BeOfType PSCustomObject |
                        Should -Be $null
                } | Verify-AssertionFailed)

                $errors.Count | Should -Be 3
            }
        }

        Context 'Using should-throw' {

            It 'should not throw without ErrorAction' {
                $errors = @({ { 4 | Should -Be 5 } | Verify-AssertionFailed } | Should -Not -Throw)

                $errors.Count | Should -Be 1
            }

            It 'should throw with ErrorAction Stop' {
                { 4 | Should -Be 5 -ErrorAction Stop } | Should -Throw
            }
        }
    }
}
