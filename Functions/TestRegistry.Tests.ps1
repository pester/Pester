Set-StrictMode -Version Latest

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

$script:drivePath = $null

Describe "TestRegistry scoping" {
    $script:drivePath = (Get-PSDrive "TestRegistry").Root -replace "HKEY_CURRENT_USER", "HKCU:"

    $describeKey = New-Item -Path "TestRegistry:\" -Name "DescribeKey"
    $describeValue = New-ItemProperty -Path "TestRegistry:\DescribeKey" -Name "DescribeValue" -Value 1

    # define the variables here so we can observe
    # then outside of the Context, but create items within
    # the context
    $script:contextKey = $null
    $script:contextValue = $null
    Context "Describe file is available in context" {

        $script:contextKey = New-Item -Path "TestRegistry:\" -Name "ContextKey"
        $script:contextValue = New-ItemProperty -Path "TestRegistry:\ContextKey" -Name "ContextValue" -Value 2

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

# the describes might be skipped and then $script:drivePath would be null
# but we cannot put it in a describe because then the describe would setup the
# test registry
$registryKeyVariableHasValue = $null -ne $script:drivePath
$registryKeyWasRemoved = $registryKeyVariableHasValue -and -not (Test-Path $script:drivePath)

$testRegistryDriveWasRemoved = -not (Test-Path "TestRegistry:\")

Describe "cleanup" {
    It "Removed the key used in the previous Describe" {
        $registryKeyWasRemoved | Should -BeTrue
    }

    It "Removed the drive" {
        $testRegistryDriveWasRemoved | Should -BeTrue
    }
}

# Describe "Cleanup when Remove-Item is mocked" {
#     Mock Remove-Item {}

#     Context "add a temp directory" {
#         Setup -Dir "foo"
#     }

#     Context "next context" {

#         It "should have removed the temp folder" {
#             "$TestRegistry\foo" | Should -Not -Exist
#         }

#     }
# }
