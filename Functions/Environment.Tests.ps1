Set-StrictMode -Version Latest

InModuleScope -ModuleName Pester {
    Describe 'GetPesterPsVersion' {
        It 'Returns value of $PSVersionTable.PsVersion.Major' {
            Mock Get-Variable -ParameterFilter { $Name -eq 'PSVersionTable' -and $ValueOnly } -MockWIth {
                @{ PSVersion = [Version]'1.0.0' }
            }

            GetPesterPsVersion | Should -Be 1
        }
    }

    # these tests mock GetPesterOs on which It and Context depend
    # for figuring out if TestRegistry should be used, so keep the mocks
    # inside of It blocks otherwise the framework thinks we are on windows and
    # tries to activate TestRegistry on Linux which fails, because there are no registry
    Describe "GetPesterOs" {
        Context "Windows with PowerShell 5 and lower" {
            It "Returns 'Windows' when PowerShell version is lower than 6" {
                Mock GetPesterPsVersion { 5 }

                GetPesterOs | Should -Be 'Windows'
            }
        }

        Context "Windows with PowerShell 6 and higher" {
            It "Returns 'Windows' when `$IsWindows is `$true and powershell version is 6 or higher" {

                Mock Get-Variable -ParameterFilter { $Name -eq 'IsWindows' -and $ValueOnly } -MockWith { $true }
                Mock Get-Variable -ParameterFilter { $Name -eq 'IsLinux' -and $ValueOnly } -MockWith { $false }
                Mock Get-Variable -ParameterFilter { $Name -eq 'IsMacOS' -and $ValueOnly } -MockWith { $false }
                Mock GetPesterPsVersion { 6 }

                GetPesterOs | Should -Be 'Windows'
            }

            It "Uses Get-Variable to retrieve IsWindows" {
                # IsWindows is a constant and cannot be overwritten, so check that we are using
                # Get-Variable to access its value, which allows us to mock it easily without
                # depending on the OS, same for IsLinux and IsMacOS

                Mock Get-Variable -ParameterFilter { $Name -eq 'IsWindows' -and $ValueOnly } -MockWith { $true }
                Mock GetPesterPsVersion { 6 }

                $null = GetPesterOs

                Assert-MockCalled Get-Variable -ParameterFilter { $Name -eq 'IsWindows' -and ($ValueOnly) } -Exactly 1 -Scope It
            }
        }

        Context "Linux with PowerShell 6 and higher" {
            It "Returns 'Linux' when `$IsLinux is `$true and powershell version is 6 or higher" {
                Mock Get-Variable -ParameterFilter { $Name -eq 'IsWindows' -and $ValueOnly } -MockWith { $false }
                Mock Get-Variable -ParameterFilter { $Name -eq 'IsLinux' -and $ValueOnly } -MockWith { $true }
                Mock Get-Variable -ParameterFilter { $Name -eq 'IsMacOS' -and $ValueOnly } -MockWith { $false }
                Mock GetPesterPsVersion { 6 }

                GetPesterOs | Should -Be 'Linux'
            }

            It "Uses Get-Variable to retrieve IsLinux" {
                Mock Get-Variable -ParameterFilter { $Name -eq 'IsLinux' -and $ValueOnly } -MockWith { $true }
                Mock GetPesterPsVersion { 6 }

                $null = GetPesterOs

                Assert-MockCalled Get-Variable -ParameterFilter { $Name -eq 'IsLinux' -and $ValueOnly } -Exactly 1 -Scope It
            }
        }

        Context "macOS with PowerShell 6 and higher" {
            It "Returns 'OSX' when `$IsMacOS is `$true and powershell version is 6 or higher" {
                Mock Get-Variable -ParameterFilter { $Name -eq 'IsWindows' -and $ValueOnly } -MockWith { $false }
                Mock Get-Variable -ParameterFilter { $Name -eq 'IsLinux' -and $ValueOnly } -MockWith { $false }
                Mock Get-Variable -ParameterFilter { $Name -eq 'IsMacOS' -and $ValueOnly } -MockWith { $true }
                Mock GetPesterPsVersion { 6 }

                GetPesterOs | Should -Be 'macOS'
            }

            It "Uses Get-Variable to retrieve IsMacOS" {
                Mock Get-Variable -ParameterFilter { $Name -eq 'IsMacOS' -and $ValueOnly } -MockWith { $true }

                $null = GetPesterOs

                Assert-MockCalled Get-Variable -ParameterFilter { $Name -eq 'IsMacOS' -and $ValueOnly } -Exactly 1 -Scope It
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

    if ('Windows' -eq (GetPesterOs)) {
        Describe 'Get-TempRegistry' {
            Mock 'GetPesterOs' {
                return 'Windows'
            }

            It 'return the corret temp registry for Windows' {

                $expected = 'Microsoft.PowerShell.Core\Registry::HKEY_CURRENT_USER\Software\Pester'
                $tempPath = Get-TempRegistry
                $tempPath | Should -Be $expected
            }
        }
    }
}
