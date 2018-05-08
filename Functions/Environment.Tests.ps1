Set-StrictMode -Version Latest

InModuleScope -ModuleName Pester {
    Describe 'GetPesterPsVersion' {
        Mock Get-Variable
        It 'Returns value of $PSVersionTable.PsVersion.Major' {
            Mock Get-Variable -ParameterFilter { $Name -eq 'PSVersionTable' -and $ValueOnly } -MockWIth {
                @{ PSVersion = [Version]'1.0.0' }
            }

            GetPesterPsVersion | Should -Be 1
        }
    }

    Describe "GetPesterOs" {
        Mock Get-Variable
        Context "Windows with PowerShell 5 and lower" {
            It "Returns 'Windows' when PowerShell version is lower than 6" {
                Mock GetPesterPsVersion { 5 }

                GetPesterOs | Should -Be 'Windows'
            }
        }

        Context "Windows with PowerShell 6 and higher" {
            Mock Get-Variable -ParameterFilter { $Name -eq 'IsWindows' -and $ValueOnly } -MockWith { $true }
            Mock Get-Variable -ParameterFilter { $Name -eq 'IsLinux' -and $ValueOnly } -MockWith { $false }
            Mock Get-Variable -ParameterFilter { $Name -eq 'IsMacOS' -and $ValueOnly } -MockWith { $false }
            Mock GetPesterPsVersion { 6 }

            $os = GetPesterOs
            It "Returns 'Windows' when `$IsWindows is `$true and powershell version is 6 or higher" {
                $os | Should -Be 'Windows'
            }

            It "Uses Get-Variable to retrieve IsWindows" {
                # IsWindows is a constant and cannot be overwritten, so check that we are using
                # Get-Variable to access its value, which allows us to mock it easily without
                # depending on the OS

                Assert-MockCalled Get-Variable -ParameterFilter { $Name -eq 'IsWindows' -and ($ValueOnly) } -Exactly 1
            }
        }

        Context "Linux with PowerShell 6 and higher" {
            Mock Get-Variable -ParameterFilter { $Name -eq 'IsWindows' -and $ValueOnly } -MockWith { $false }
            Mock Get-Variable -ParameterFilter { $Name -eq 'IsLinux' -and $ValueOnly } -MockWith { $true }
            Mock Get-Variable -ParameterFilter { $Name -eq 'IsMacOS' -and $ValueOnly } -MockWith { $false }
            Mock GetPesterPsVersion { 6 }

            $os = GetPesterOs
            It "Returns 'Linux' when `$IsLinux is `$true and powershell version is 6 or higher" {
                $os | Should -Be 'Linux'
            }

            It "Uses Get-Variable to retrieve IsLinux" {
                Assert-MockCalled Get-Variable -ParameterFilter { $Name -eq 'IsLinux' -and $ValueOnly } -Exactly 1
            }
        }

        Context "macOS with PowerShell 6 and higher" {
            Mock Get-Variable -ParameterFilter { $Name -eq 'IsWindows' -and $ValueOnly } -MockWith { $false }
            Mock Get-Variable -ParameterFilter { $Name -eq 'IsLinux' -and $ValueOnly } -MockWith { $false }
            Mock Get-Variable -ParameterFilter { $Name -eq 'IsMacOS' -and $ValueOnly } -MockWith { $true }
            Mock GetPesterPsVersion { 6 }

            $os = GetPesterOs
            It "Returns 'OSX' when `$IsMacOS is `$true and powershell version is 6 or higher" {
                $os | Should -Be 'macOS'
            }

            It "Uses Get-Variable to retrieve IsMacOS" {
                Assert-MockCalled Get-Variable -ParameterFilter { $Name -eq 'IsMacOS' -and $ValueOnly } -Exactly 1
            }
        }
    }


    Describe 'Get-TempDirectory' {
        It 'returns the correct temp directory for Windows' {
            Mock 'GetPesterOs' {
                'Windows'
            }
            $expected = $env:TEMP = "C:\temp"

            $temp = Get-TempDirectory
            $temp | Should -Not -BeNullOrEmpty
            $temp | Should -Be $expected
        }

        It "returns '/tmp' directory for MacOS" {
            Mock 'GetPesterOs' {
                'MacOS'
            }
            Get-TempDirectory | Should -Be '/tmp'
        }

        It "returns '/tmp' directory for Linux" {
            Mock 'GetPesterOs' {
                'Linux'
            }
            Get-TempDirectory | Should -Be '/tmp'
        }
    }
}
