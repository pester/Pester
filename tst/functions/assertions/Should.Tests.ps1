Set-StrictMode -Version Latest

InPesterModuleScope {

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

    Describe 'Returning values from Should' {
        It 'Should -Be swallows the given object' {
            $user = [PSCustomObject]@{
                Name = "Jakub"
            }

            $returnedValue = $user | Should -Not -Be $null # just some test so we call the assertion
            $returnedValue | Should -BeNullOrEmpty # make sure the previous assertion returned nothing
        }
    }

    Describe "Legacy syntax" {
        It "Throws informative error message when Legacy syntax is used" {
            $err = { 1 | Should be 1 } | Should -Throw -PassThru
            $err | Should -Match "legacy should syntax.*no longer supported"
        }
    }
}
