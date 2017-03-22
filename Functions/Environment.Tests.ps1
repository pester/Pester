InModuleScope -ModuleName Pester {
    Describe 'Get-PowerShellVersion' {
        Mock Get-Variable
        It 'Returns value of $PSVersionTable.PsVersion.Major' {
            Mock Get-Variable -ParameterFilter { $Name -eq 'PSVersionTable' -and $ValueOnly } -MockWIth {
                @{ PSVersion = [Version]'1.0.0' }
            }

            Get-PowerShellVersion | Should -Be 1
        }
    }

    Describe "Get-OperatingSystem" {
        Mock Get-Variable
        Context "Windows with PowerShell 5 and lower" {
            It "Returns 'Windows' when PowerShell version is lower than 6" {
                Mock Get-PowerShellVersion { 5 }

                Get-OperatingSystem | Should -Be 'Windows'
            }
        }

        Context "Windows with PowerShell 6 and higher" {
            Mock Get-Variable -ParameterFilter { $Name -eq 'IsWindows' -and $ValueOnly } -MockWith { $true }
            Mock Get-Variable -ParameterFilter { $Name -eq 'IsLinux' -and $ValueOnly } -MockWith { $false }
            Mock Get-Variable -ParameterFilter { $Name -eq 'IsOSX' -and $ValueOnly } -MockWith { $false }
            Mock Get-PowerShellVersion { 6 }

            $os = Get-OperatingSystem
            It "Returns 'Windows' when `$IsWindows is `$true and powershell version is 6 or higher" {
                $os | Should -Be 'Windows'
            }

            It "Uses Get-Variable to retreive IsWindows" {
                # IsWindows is a constant and cannot be overwritten, so check that we are using
                # Get-Variable to access its value, which allows us to mock it easily without
                # depending on the OS

                Assert-MockCalled Get-Variable -ParameterFilter { $Name -eq 'IsWindows' -and ($ValueOnly) } -Exactly 1
            }
        }

        Context "Linux with PowerShell 6 and higher" {
            Mock Get-Variable -ParameterFilter { $Name -eq 'IsWindows' -and $ValueOnly } -MockWith { $false }
            Mock Get-Variable -ParameterFilter { $Name -eq 'IsLinux' -and $ValueOnly } -MockWith { $true }
            Mock Get-Variable -ParameterFilter { $Name -eq 'IsOSX' -and $ValueOnly } -MockWith { $false }
            Mock Get-PowerShellVersion { 6 }

            $os = Get-OperatingSystem
            It "Returns 'Linux' when `$IsLinux is `$true and powershell version is 6 or higher" {
                $os | Should -Be 'Linux'
            }

            It "Uses Get-Variable to retreive IsLinux" {
                Assert-MockCalled Get-Variable -ParameterFilter { $Name -eq 'IsLinux' -and $ValueOnly } -Exactly 1
            }
        }

        Context "OSx with PowerShell 6 and higher" {
            Mock Get-Variable -ParameterFilter { $Name -eq 'IsWindows' -and $ValueOnly } -MockWith { $false }
            Mock Get-Variable -ParameterFilter { $Name -eq 'IsLinux' -and $ValueOnly } -MockWith { $false }
            Mock Get-Variable -ParameterFilter { $Name -eq 'IsOSX' -and $ValueOnly } -MockWith { $true }
            Mock Get-PowerShellVersion { 6 }

            $os = Get-OperatingSystem
            It "Returns 'OSX' when `$IsOSX is `$true and powershell version is 6 or higher" {
                $os | Should -Be 'OSX'
            }

            It "Uses Get-Variable to retreive IsOSX" {
                Assert-MockCalled Get-Variable -ParameterFilter { $Name -eq 'IsOSX' -and $ValueOnly } -Exactly 1
            }
        }
    }


    Describe 'Get-TempDirectory' {
        It 'returns the correct temp directory for Windows' {
            Mock 'Get-OperatingSystem' {
                'Windows'
            }
            $expected = $env:TEMP = "C:\temp"

            $temp = Get-TempDirectory
            $temp | Should -Not -BeNullOrEmpty
            $temp | Should -Be $expected
        }

        It "returns '/tmp' directory for MacOS" {
            Mock 'Get-OperatingSystem' {
                'MacOS'
            }
            Get-TempDirectory | Should -Be '/tmp'
        }

        It "returns '/tmp' directory for Linux" {
            Mock 'Get-OperatingSystem' {
                'Linux'
            }
            Get-TempDirectory | Should -Be '/tmp'
        }
    }
}
