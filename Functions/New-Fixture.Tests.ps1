Set-StrictMode -Version Latest

Describe "New-Fixture" {
    It "Name parameter is mandatory:" {
        (get-command New-Fixture ).Parameters.Name.ParameterSets.__AllParameterSets.IsMandatory | Should -Be $true
    }

    Context "Only Name parameter is specified:" {
        It "Creates fixture in current directory:" {
            $name = "Test-Fixture"
            $path = "TestDrive:\"

            Push-Location -Path $path
            New-Fixture -Name $name | Out-Null
            Pop-Location

            Join-Path -Path $path -ChildPath "$name.ps1" | Should -Exist
            Join-Path -Path $path -ChildPath "$name.Tests.ps1" | Should -Exist
        }
    }

    Context "Name and Path parameter is specified:" {
        #use different fixture names to avoid interference among the test cases
        #cleaning up would be also possible, but difficult if the assertion fails
        It "Creates fixture in full Path:" {
            $name = "Test-Fixture"
            $path = "TestDrive:\full"

            New-Fixture -Name $name -Path $path | Out-Null

            Join-Path -Path $path -ChildPath "$name.ps1" | Should -Exist
            Join-Path -Path $path -ChildPath "$name.Tests.ps1" | Should -Exist

            #cleanup
            Join-Path -Path "$path" -ChildPath "$name.ps1" | Remove-Item -Force
            Join-Path -Path "$path" -ChildPath "$name.Tests.ps1" | Remove-Item -Force
        }

        It "Creates fixture in relative Path:" {
            $name = "Relative1-Fixture"
            $path = "TestDrive:\"

            Push-Location -Path $path
            New-Fixture -Name $name -Path relative | Out-Null
            Pop-Location

            Join-Path -Path "$path\relative" -ChildPath "$name.ps1" | Should -Exist
            Join-Path -Path "$path\relative" -ChildPath "$name.Tests.ps1" | Should -Exist
        }
        It "Creates fixture if Path is set to '.':" {
            $name = "Relative2-Fixture"
            $path = "TestDrive:\"

            Push-Location -Path $path
            New-Fixture -Name $name -Path . | Out-Null
            Pop-Location

            Join-Path -Path "$path" -ChildPath "$name.ps1" | Should -Exist
            Join-Path -Path "$path" -ChildPath "$name.Tests.ps1" | Should -Exist
        }
        It "Creates fixture if Path is set to '(pwd)':" {
            $name = "Relative3-Fixture"
            $path = "TestDrive:\"

            Push-Location -Path $path
            New-Fixture -Name $name -Path (Get-Location) | Out-Null
            Pop-Location

            Join-Path -Path "$path" -ChildPath "$name.ps1" | Should -Exist
            Join-Path -Path "$path" -ChildPath "$name.Tests.ps1" | Should -Exist
        }
        It "Creates fixture if Path is set to '(pwd)' and Name contains the 'ps1' extension:" {
            $name = "Relative4-Fixture.ps1"
            $nameWithoutExtension = $name.Substring(0, $($name.Length) - 4)
            $path = "TestDrive:\"

            Push-Location -Path $path
            New-Fixture -Name $name -Path (Get-Location) | Out-Null
            Pop-Location

            Join-Path -Path "$path" -ChildPath "$nameWithoutExtension.ps1" | Should -Exist
            Join-Path -Path "$path" -ChildPath "$nameWithoutExtension.Tests.ps1" | Should -Exist
        }
        It "Writes warning if file exists" {
            $name = "Warning-Fixture"
            $path = "TestDrive:\"

            Mock -Verifiable -ModuleName Pester Write-Warning { }

            #Create the same files twice
            New-Fixture -Name $name -Path $path | Out-Null
            New-Fixture -Name $name -Path $path -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null

            Assert-VerifiableMock
        }

    }
    #TODO add tests that validate the contents of default files
}

