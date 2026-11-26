Set-StrictMode -Version Latest

InModuleScope -ModuleName Pester {
    BeforeAll {
        # GetPesterPsVersion and GetPesterOs read $PSVersionTable and the
        # $IsWindows / $IsMacOS / $IsLinux automatic variables through
        # $SafeCommands['Get-Variable']. Going through $SafeCommands bypasses command
        # resolution, so Mock cannot intercept these calls. To simulate a different
        # PowerShell version or operating system we temporarily swap the SafeCommands
        # entry for a stub and restore it afterwards. The stub only fakes PSVersionTable
        # and the three OS switches and delegates every other lookup to the real
        # Get-Variable, so the override does not leak into Pester's own machinery, which
        # relies on these same functions while the test runs.
        function Invoke-WithFakedEnvironment {
            param(
                [int] $Version = 7,
                [hashtable] $Variable = @{ },
                [Parameter(Mandatory)] [scriptblock] $Test
            )

            $original = $SafeCommands['Get-Variable']
            try {
                $SafeCommands['Get-Variable'] = {
                    param([string] $Name, [switch] $ValueOnly, $ErrorAction)
                    if ('PSVersionTable' -eq $Name) {
                        return @{ PSVersion = [version]::new($Version, 0) }
                    }
                    if ($Name -in 'IsWindows', 'IsMacOS', 'IsLinux') {
                        if ($Variable.ContainsKey($Name)) { return $Variable[$Name] }
                        return $false
                    }
                    return & $original @PSBoundParameters
                }.GetNewClosure()

                & $Test
            }
            finally {
                $SafeCommands['Get-Variable'] = $original
            }
        }
    }

    Describe 'GetPesterPsVersion' {
        It 'Returns the major version of $PSVersionTable.PSVersion' {
            Invoke-WithFakedEnvironment -Version 4 -Test {
                GetPesterPsVersion | Should-Be 4
            }
        }
    }

    Describe 'GetPesterOs' {
        It "Returns 'Windows' on Windows PowerShell (version below 7)" {
            # Pester 6 supports Windows PowerShell 5.1 and PowerShell 7+. PowerShell 6 is
            # EOL and is treated as Windows-only, so any version below 7 reports 'Windows'.
            Invoke-WithFakedEnvironment -Version 5 -Test {
                GetPesterOs | Should-BeString 'Windows'
            }
        }

        It "Returns 'Windows' when `$IsWindows is `$true on PowerShell 7+" {
            Invoke-WithFakedEnvironment -Version 7 -Variable @{ IsWindows = $true } -Test {
                GetPesterOs | Should-BeString 'Windows'
            }
        }

        It "Returns 'macOS' when `$IsMacOS is `$true on PowerShell 7+" {
            Invoke-WithFakedEnvironment -Version 7 -Variable @{ IsMacOS = $true } -Test {
                GetPesterOs | Should-BeString 'macOS'
            }
        }

        It "Returns 'Linux' when `$IsLinux is `$true on PowerShell 7+" {
            Invoke-WithFakedEnvironment -Version 7 -Variable @{ IsLinux = $true } -Test {
                GetPesterOs | Should-BeString 'Linux'
            }
        }

        It 'Throws for an unsupported operating system on PowerShell 7+' {
            Invoke-WithFakedEnvironment -Version 7 -Test {
                { GetPesterOs } | Should-Throw -ExceptionMessage 'Unsupported Operating system!'
            }
        }
    }

    Describe 'Get-TempDirectory' {
        It "Returns '/private/tmp' on macOS" {
            Mock GetPesterOs { 'macOS' }
            Get-TempDirectory | Should-BeString '/private/tmp'
        }

        It 'Returns the system temp path on Windows' {
            Mock GetPesterOs { 'Windows' }
            Get-TempDirectory | Should-Be ([System.IO.Path]::GetTempPath())
        }

        It 'Returns the system temp path on Linux' {
            Mock GetPesterOs { 'Linux' }
            Get-TempDirectory | Should-Be ([System.IO.Path]::GetTempPath())
        }
    }

    Describe 'Get-TempRegistry' -Skip:((GetPesterOs) -ne 'Windows') {
        # Get-TempRegistry uses the Windows registry provider, which only exists on Windows.
        It 'Returns the Pester registry root path' {
            Get-TempRegistry | Should-BeString 'Microsoft.PowerShell.Core\Registry::HKEY_CURRENT_USER\Software\Pester'
        }
    }
}
