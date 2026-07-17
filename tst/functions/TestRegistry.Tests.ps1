Set-StrictMode -Version Latest

Describe 'Invoke-TestRegistryWithRetry' {
    # This helper makes TestRegistry reads and writes resilient to the transient
    # 'IOException: No more data is available' that happens on parallel Windows PowerShell
    # runs (.NET Framework). The retry logic itself is OS-agnostic, so these tests run
    # everywhere. See https://github.com/pester/Pester/issues/2418
    It 'Returns the result of the script block on success' {
        InModuleScope -ModuleName Pester {
            Invoke-TestRegistryWithRetry { 'result' } | Should -Be 'result'
        }
    }

    It 'Invokes the script block once on success' {
        InModuleScope -ModuleName Pester {
            $calls = @{ Count = 0 }
            $null = Invoke-TestRegistryWithRetry { $calls.Count++ }
            $calls.Count | Should -Be 1
        }
    }

    It 'Retries once and returns the second result when the first attempt throws a transient IOException' {
        InModuleScope -ModuleName Pester {
            $calls = @{ Count = 0 }
            $result = Invoke-TestRegistryWithRetry {
                $calls.Count++
                if ($calls.Count -eq 1) {
                    throw [System.IO.IOException] 'No more data is available'
                }
                'recovered'
            }
            $calls.Count | Should -Be 2
            $result | Should -Be 'recovered'
        }
    }

    It 'Rethrows when the transient IOException persists on retry' {
        InModuleScope -ModuleName Pester {
            { Invoke-TestRegistryWithRetry { throw [System.IO.IOException] 'No more data is available' } } |
                Should -Throw -ExceptionType ([System.IO.IOException])
        }
    }

    It 'Does not retry on non-IOException errors' {
        InModuleScope -ModuleName Pester {
            $calls = @{ Count = 0 }
            { Invoke-TestRegistryWithRetry { $calls.Count++; throw 'boom' } } | Should -Throw
            $calls.Count | Should -Be 1
        }
    }
}

$os = InModuleScope -ModuleName Pester { GetPesterOs }
if ("Windows" -ne $os) {
    # test registry are only for Windows
    return
}

Describe "General" {
    It "creates a drive location called TestRegistry:" {
        "TestRegistry:\" | Should -Exist
    }

    It "is located in Pester key in HKCU" {
        $testRegistryPath = (Get-PSDrive TestRegistry).Root
        $testRegistryPath | Should -BeLike "HKEY_CURRENT_USER\Software\Pester*"
    }
}

Describe "TestRegistry scoping" {
    BeforeAll {
        $describeKey = New-Item -Path "TestRegistry:\" -Name "DescribeKey"
        $describeValue = New-ItemProperty -Path "TestRegistry:\DescribeKey" -Name "DescribeValue" -Value 1

        # define the variables here so we can observe
        # then outside of the Context, but create items within
        # the context
        $script:contextKey = $null
        $script:contextValue = $null
    }

    Context "Describe file is available in context" {
        BeforeAll {
            $script:contextKey = New-Item -Path "TestRegistry:\" -Name "ContextKey"
            $script:contextValue = New-ItemProperty -Path "TestRegistry:\ContextKey" -Name "ContextValue" -Value 2
        }

        It "Finds the everything that was setup so far" {
            $itKey = New-Item -Path "TestRegistry:\ContextKey" -Name "ItKey"
            $itValue = New-ItemProperty -Path "TestRegistry:\ContextKey\ItKey" -Name "ItValue" -Value 3

            $describeKey.PSPath | Should -Exist
            $describeValue.PSPath | Should -Exist
            $contextKey.PSPath | Should -Exist
            $contextValue.PSPath | Should -Exist
            $itKey.PSPath | Should -Exist
            $itValue.PSPath | Should -Exist
        }
    }

    It "Context key and value removed when returning to Describe" {
        $script:contextKey.PSPath | Should -Not -Exist
        $script:contextValue.PSPath | Should -Not -Exist
    }

    It "Describe key and value are still available in Describe" {
        $describeKey.PSPath | Should -Exist
        $describeValue.PSPath | Should -Exist
    }
}

Describe 'Repair missing TestRegistry' {
    BeforeAll {
        $tempValueName = 'MyValue'
        $tempValue = New-ItemProperty -Path 'TestRegistry:/' -Name $tempValueName -Value 1
    }

    Context 'Broken' {
        It 'Removes TestRegistry' {
            (Get-ItemProperty -Path 'TestRegistry:/' -Name $tempValueName).$tempValueName | Should -Be 1
            Remove-PSDrive -Name 'TestRegistry'
            { Get-PSDrive -Name 'TestRegistry' -ErrorAction Stop } | Should -Throw -ExpectedMessage 'Cannot find drive*'
        }
    }

    Context 'Fixed' {
        It 'TestRegistry exists again' {
            (Get-ItemProperty -Path 'TestRegistry:/' -Name $tempValueName).$tempValueName | Should -Be 1
        }
    }
}

Describe 'Running Pester in Invoke-Pester' {
    BeforeAll {
        $tempValueName = 'OuterValue'
        $tempValue = New-ItemProperty -Path 'TestRegistry:/' -Name $tempValueName -Value 1
    }

    It 'Value exists before' {
        (Get-ItemProperty -Path 'TestRegistry:/' -Name $tempValueName).$tempValueName | Should -Be 1
    }

    It 'Works in nested run' {
        $sb = {
            Describe 'Nested' {
                It 'Value created in outer run are available using absolute path' {
                    (Get-ItemProperty -Path $TempKeyPath -Name $TempValueName).$TempValueName | Should -Be 1
                }

                It 'TestRegistry PSDrive points to clean location' {
                    (Get-Item -Path 'TestRegistry:/').Property | Should -BeNullOrEmpty
                }
            }
        }

        $c = New-PesterContainer -ScriptBlock $sb -Data @{ TempKeyPath = $tempValue.PSPath; TempValueName = $tempValueName }
        $innerRun = Invoke-Pester -Container $c -PassThru -Output None
        $innerRun.Result | Should -Be 'Passed'
        $innerRun.PassedCount | Should -Be 2
    }

    It 'Value still exists after nested run' {
        (Get-ItemProperty -Path 'TestRegistry:/' -Name $tempValueName).$tempValueName | Should -Be 1
    }
}
