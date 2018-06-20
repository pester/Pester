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
            $pesterSuppression        | Should -Not -BeNullOrEmpty
            $pesterSuppression.Script | Should -Be '*'
        }

        It 'Should add a suppression entry' {

            # Act
            Add-PesterSuppression -Script 'MyScript.ps1' -Group 'My Group 1', 'My Group 2' -It 'My Test'
            $pesterSuppression = Get-PesterSuppression | Select-Object -First 1

            # Assert
            $pesterSuppression          | Should -Not -BeNullOrEmpty
            $pesterSuppression.Script   | Should -Be 'MyScript.ps1'
            $pesterSuppression.Group[0] | Should -Be 'My Group 1'
            $pesterSuppression.Group[1] | Should -Be 'My Group 2'
            $pesterSuppression.It       | Should -Be 'My Test'
        }

        It 'Should join the group array with a backslash' {

            # Act
            Add-PesterSuppression -Group 'My Demo *', '123.4', '$!?' -It '*'

            # Assert
            $pesterSuppression           | Should -Not -BeNullOrEmpty
            $pesterSuppression.GroupFlat | Should -Be 'My Demo *\123.4\$!?'
        }
    }

    Describe 'Test-PesterSuppression' {

        $testCases = @(
            @{
                TestGroupList = (New-Object -TypeName 'PSObject' -Property @{ Hint = 'Root';     Name = 'Pester' }),
                                (New-Object -TypeName 'PSObject' -Property @{ Hint = 'Script';   Name = 'DemoScript.ps1' }),
                                (New-Object -TypeName 'PSObject' -Property @{ Hint = 'Describe'; Name = 'My Group 1' }),
                                (New-Object -TypeName 'PSObject' -Property @{ Hint = 'Context';  Name = 'My Group 2' })
                TestGroupName = 'MyScript.ps1 \ My Group 1 \ My Group 2'
                TestName      = 'My Test'
                Expected      = $false   # because the script does not match
            }
            @{
                TestGroupList = (New-Object -TypeName 'PSObject' -Property @{ Hint = 'Root';     Name = 'Pester' }),
                                (New-Object -TypeName 'PSObject' -Property @{ Hint = 'Script';   Name = 'MyScript.ps1' }),
                                (New-Object -TypeName 'PSObject' -Property @{ Hint = 'Describe'; Name = 'My Group 1' })
                TestGroupName = 'MyScript.ps1 \ My Group 1'
                TestName      = 'My Test'
                Expected      = $false   # because the group 'My Group 2' is missing
            }
            @{
                TestGroupList = (New-Object -TypeName 'PSObject' -Property @{ Hint = 'Root';     Name = 'Pester' }),
                                (New-Object -TypeName 'PSObject' -Property @{ Hint = 'Script';   Name = 'MyScript.ps1' }),
                                (New-Object -TypeName 'PSObject' -Property @{ Hint = 'Describe'; Name = 'My Group 1' }),
                                (New-Object -TypeName 'PSObject' -Property @{ Hint = 'Context';  Name = 'My Group 2' })
                TestGroupName = 'MyScript.ps1 \ My Group 1 \ My Group 2'
                TestName      = 'My Test'
                Expected      = $true   # match without any wildcards
            }
            @{
                TestGroupList = (New-Object -TypeName 'PSObject' -Property @{ Hint = 'Root';     Name = 'Pester' }),
                                (New-Object -TypeName 'PSObject' -Property @{ Hint = 'Script';   Name = 'MyScript.ps1' }),
                                (New-Object -TypeName 'PSObject' -Property @{ Hint = 'Describe'; Name = 'My Group 1' }),
                                (New-Object -TypeName 'PSObject' -Property @{ Hint = 'Context';  Name = 'My Group 2' })
                TestGroupName = 'MyScript.ps1 \ My Group 1 \ My Group 2'
                TestName      = 'First Demo FOO BAR 123 $!? Wildcard'
                Expected      = $true   # match by test name with the wildcard
            }
            @{
                TestGroupList = (New-Object -TypeName 'PSObject' -Property @{ Hint = 'Root';     Name = 'Pester' }),
                                (New-Object -TypeName 'PSObject' -Property @{ Hint = 'Script';   Name = 'MyScript.ps1' }),
                                (New-Object -TypeName 'PSObject' -Property @{ Hint = 'Describe'; Name = 'Second Demo FOO BAR 123 $!? Wildcard' })
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
