Set-StrictMode -Version Latest

InModuleScope Pester {

    Describe 'Add-PesterSuppression' {

        AfterEach {

            Clear-PesterSuppression
        }

        It 'Should use a wildcard as script entry' {

            # Act
            Add-PesterSuppression -Group 'My Group' -It 'My Test'

            # Assert
            (Get-PesterSuppression)[0]        | Should -Not -BeNullOrEmpty
            (Get-PesterSuppression)[0].Script | Should -Be '*'
        }

        It 'Should add a suppression entry' {

            # Act
            Add-PesterSuppression -Script 'MyScript.ps1' -Group 'My Group 1', 'My Group 2' -It 'My Test'

            # Assert
            (Get-PesterSuppression)[0]          | Should -Not -BeNullOrEmpty
            (Get-PesterSuppression)[0].Script   | Should -Be 'MyScript.ps1'
            (Get-PesterSuppression)[0].Group[0] | Should -Be 'My Group 1'
            (Get-PesterSuppression)[0].Group[1] | Should -Be 'My Group 2'
            (Get-PesterSuppression)[0].It       | Should -Be 'My Test'
        }

        It 'Should join the group array with a backslash' {

            # Act
            Add-PesterSuppression -Group 'My Demo *', '123.4', '$!?' -It '*'

            # Assert
            (Get-PesterSuppression)[0]           | Should -Not -BeNullOrEmpty
            (Get-PesterSuppression)[0].GroupFlat | Should -Be 'My Demo *\123.4\$!?'
        }
    }

    Describe 'Test-PesterSuppression' {

        $testCases = @(
            @{
                TestGroupList = [PSCustomObject] @{ Hint = 'Root';     Name = 'Pester' },
                                [PSCustomObject] @{ Hint = 'Script';   Name = 'DemoScript.ps1' },
                                [PSCustomObject] @{ Hint = 'Describe'; Name = 'My Group 1' },
                                [PSCustomObject] @{ Hint = 'Context';  Name = 'My Group 2' }
                TestGroupName = 'MyScript.ps1 \ My Group 1 \ My Group 2'
                TestName      = 'My Test'
                Expected      = $false   # because the script does not match
            }
            @{
                TestGroupList = [PSCustomObject] @{ Hint = 'Root';     Name = 'Pester' },
                                [PSCustomObject] @{ Hint = 'Script';   Name = 'MyScript.ps1' },
                                [PSCustomObject] @{ Hint = 'Describe'; Name = 'My Group 1' }
                TestGroupName = 'MyScript.ps1 \ My Group 1'
                TestName      = 'My Test'
                Expected      = $false   # because the group 'My Group 2' is missing
            }
            @{
                TestGroupList = [PSCustomObject] @{ Hint = 'Root';     Name = 'Pester' },
                                [PSCustomObject] @{ Hint = 'Script';   Name = 'MyScript.ps1' },
                                [PSCustomObject] @{ Hint = 'Describe'; Name = 'My Group 1' },
                                [PSCustomObject] @{ Hint = 'Context';  Name = 'My Group 2' }
                TestGroupName = 'MyScript.ps1 \ My Group 1 \ My Group 2'
                TestName      = 'My Test'
                Expected      = $true   # match without any wildcards
            }
            @{
                TestGroupList = [PSCustomObject] @{ Hint = 'Root';     Name = 'Pester' },
                                [PSCustomObject] @{ Hint = 'Script';   Name = 'MyScript.ps1' },
                                [PSCustomObject] @{ Hint = 'Describe'; Name = 'My Group 1' },
                                [PSCustomObject] @{ Hint = 'Context';  Name = 'My Group 2' }
                TestGroupName = 'MyScript.ps1 \ My Group 1 \ My Group 2'
                TestName      = 'First Demo FOO BAR 123 $!? Wildcard'
                Expected      = $true   # match by test name with the wildcard
            }
            @{
                TestGroupList = [PSCustomObject] @{ Hint = 'Root';     Name = 'Pester' },
                                [PSCustomObject] @{ Hint = 'Script';   Name = 'MyScript.ps1' },
                                [PSCustomObject] @{ Hint = 'Describe'; Name = 'Second Demo FOO BAR 123 $!? Wildcard' }
                TestGroupName = 'MyScript.ps1 \ Second Demo FOO BAR 123 $!? Wildcard'
                TestName      = 'My Test'
                Expected      = $true   # match by group with the wildcard
            }
        )

        Context 'Specific Suppression' {

            BeforeEach {

                Add-PesterSuppression -Script 'MyScript.ps1' -Group 'My Group 1', 'My Group 2' -It 'My Test'
                Add-PesterSuppression -Script 'MyScript.ps1' -Group 'My Group 1', 'My Group 2' -It 'First Demo * Wildcard'
                Add-PesterSuppression -Script 'MyScript.ps1' -Group 'Second Demo * Wildcard' -It 'My Test'
            }

            AfterEach {

                Clear-PesterSuppression
            }

            It 'Should return <Expected> for test group <TestGroupName> and test <TestName>' -TestCases $testCases {

                param ($TestGroupList, $TestName, $Expected)

                # Act
                $skip = Test-PesterSuppression -TestGroupList $TestGroupList -TestName $TestName

                # Assert
                if ($Expected)
                {
                    $skip | Should -BeTrue
                }
                else
                {
                    $skip | Should -BeFalse
                }
            }
        }

        Context 'Wilcard Suppression' {

            BeforeEach {

                Add-PesterSuppression -Script '*' -Group '*' -It '*'
            }

            AfterEach {

                Clear-PesterSuppression
            }

            It 'Should return $true for test group <TestGroupName> and test <TestName>' -TestCases $testCases {

                param ($TestGroupList, $TestName)

                # Act
                $skip = Test-PesterSuppression -TestGroupList $TestGroupList -TestName $TestName

                # Assert
                $skip | Should -BeTrue
            }
        }
    }
}
