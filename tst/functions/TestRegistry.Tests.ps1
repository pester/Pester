﻿Set-StrictMode -Version Latest

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

