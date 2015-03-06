Set-StrictMode -Version Latest

Describe "New-Fixture" {
    It "Name parameter is mandatory:" {
        (get-command New-Fixture ).Parameters.Name.ParameterSets.__AllParameterSets.IsMandatory | Should Be $true
    }

    Context "Only Name parameter is specified:" {
        It "Creates fixture in current directory:" {
            $name = "Test-Fixture"
            $path = "TestDrive:\"

            pushd  $path
            New-Fixture -Name $name | Out-Null
            popd

            Join-Path -Path $path -ChildPath "$name.ps1" | Should Exist
            Join-Path -Path $path -ChildPath "$name.Tests.ps1" | Should Exist
        }
    }

    Context "Name and Path parameter is specified:" {
        #use different fixture names to avoid interference among the test cases
        #claning up would be also possible, but difficult if the assertion fails
        It "Creates fixture in full Path:" {
            $name = "Test-Fixture"
            $path = "TestDrive:\full"

            New-Fixture -Name $name -Path $path | Out-Null

            Join-Path -Path $path -ChildPath "$name.ps1" | Should Exist
            Join-Path -Path $path -ChildPath "$name.Tests.ps1" | Should Exist

            #cleanup
            Join-Path -Path "$path" -ChildPath "$name.ps1" | Remove-Item -Force
            Join-Path -Path "$path" -ChildPath "$name.Tests.ps1" | Remove-Item -Force
        }

        It "Creates fixture in relative Path:" {
            $name = "Relative1-Fixture"
            $path = "TestDrive:\"

            pushd  $path
            New-Fixture -Name $name -Path relative | Out-Null
            popd

            Join-Path -Path "$path\relative" -ChildPath "$name.ps1" | Should Exist
            Join-Path -Path "$path\relative" -ChildPath "$name.Tests.ps1" | Should Exist
        }
        It "Creates fixture if Path is set to '.':" {
            $name = "Relative2-Fixture"
            $path = "TestDrive:\"

            pushd  $path
            New-Fixture -Name $name -Path . | Out-Null
            popd

            Join-Path -Path "$path" -ChildPath "$name.ps1" | Should Exist
            Join-Path -Path "$path" -ChildPath "$name.Tests.ps1" | Should Exist
        }
        It "Creates fixture if Path is set to '(pwd)':" {
            $name = "Relative3-Fixture"
            $path = "TestDrive:\"

            pushd  $path
            New-Fixture -Name $name -Path (pwd) | Out-Null
            popd

            Join-Path -Path "$path" -ChildPath "$name.ps1" | Should Exist
            Join-Path -Path "$path" -ChildPath "$name.Tests.ps1" | Should Exist
        }
        It "Writes warning if file exists" {
            $name = "Warning-Fixture"
            $path = "TestDrive:\"

            Mock -Verifiable -ModuleName Pester Write-Warning { }

            #Create the same files twice
            New-Fixture -Name $name -Path $path | Out-Null
            New-Fixture -Name $name -Path $path -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null

            Assert-VerifiableMocks
        }

    }

    Context "Custom fixture templates are not found so default values are used" {
        It "Creates the default function template" {
            Mock -ModuleName Pester Test-Path -ParameterFilter { $path -eq (Join-Path $env:USERPROFILE "WindowsPowerShell\Pester\NewFixtureTestTemplate.ps1") } -MockWith { $false }

            $path = "TestDrive:\"
            $name = "DefaultFunctionTemplate-Fixture"

            New-Fixture -Name $name -Path $path | Out-Null
            $functionFilePath = Join-Path -Path $path -ChildPath "$name.ps1"

            $functionFilePath | Should Exist

            [System.IO.File]::ReadAllText( (Get-Item $functionFilePath).FullName ) | Should Be ("function #name# {`r`n`r`n}`r`n" -replace "#name#",$name)
        }

        It "Creates the default test template" {
            Mock -ModuleName Pester Test-Path -ParameterFilter { $path -eq (Join-Path $env:USERPROFILE "WindowsPowerShell\Pester\NewFixtureTestTemplate.ps1") } -MockWith { $false }

            $path = "TestDrive:\"
            $name = "DefaultTestTemplate-Fixture"

            New-Fixture -Name $name -Path $path | Out-Null
            $testFilePath = Join-Path -Path $path -ChildPath "$name.Tests.ps1"

            $testFilePath | Should Exist

            $expectedTestFileContent = '$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

Describe "#name#" {
    It "does something useful" {
        $true | Should Be $false
    }
}'
            $expectedTestFileContent = $expectedTestFileContent -replace "#name#",$name
			Set-Content -Path TestDrive:\ExpectedContent.txt -Value $expectedTestFileContent -Encoding UTF8

            [System.IO.File]::ReadAllText( (Get-Item $testFilePath).FullName ) | Should Be ([System.IO.File]::ReadAllText( (Get-Item "TestDrive:\ExpectedContent.txt").FullName))
        }
    }

    Context "Custom fixture templates are in Env:\USERPROFILE\Documents\WindowsPowerShell\Pester" {
        It "Copies the content of NewFixtureTestTemplate.ps1 to the test file" {
            $PesterTemplatePath = Join-Path -Path (Get-Item -Path "TestDrive:\").Fullname -ChildPath "Documents\WindowsPowerShell\Pester"
            $TestTemplatePath = Join-Path -Path $PesterTemplatePath -ChildPath "NewFixtureTestTemplate.ps1"
            New-Item -Path $PesterTemplatePath -ItemType Directory -Force | Out-Null
            [System.IO.File]::WriteAllText($TestTemplatePath, "TEST TEMPLATE CONTENT")

            Mock -ModuleName Pester Join-Path -ParameterFilter { $path -eq $env:USERPROFILE -and $childPath -eq "Documents\WindowsPowerShell\Pester\NewFixtureTestTemplate.ps1" } -MockWith { Join-Path -Path "TestDrive:\" -ChildPath $ChildPath  }

            $path = "TestDrive:\"
            $name = "TestTemplate-Fixture"

            New-Fixture -Name $name -Path $path | Out-Null
            $testFilePath = Join-Path -Path $path -ChildPath "$name.Tests.ps1"
            $testFilePath | Should Exist
            [System.IO.File]::ReadAllText( (Get-Item $testFilePath).FullName ) | Should Be "TEST TEMPLATE CONTENT`r`n"
        }

        It "Copies the content of NewFixtureFunctionTemplate.ps1 to the function file" {
            $PesterTemplatePath = Join-Path -Path (Get-Item -Path "TestDrive:\").Fullname -ChildPath "Documents\WindowsPowerShell\Pester"
            $FunctionTemplatePath = Join-Path -Path $PesterTemplatePath -ChildPath "NewFixtureFunctionTemplate.ps1"
            New-Item -Path $PesterTemplatePath -ItemType Directory -Force | Out-Null
            [System.IO.File]::WriteAllText($FunctionTemplatePath, "FUNCTION TEMPLATE CONTENT")

            Mock -ModuleName Pester Join-Path -ParameterFilter { $path -eq $env:USERPROFILE -and $childPath -eq "Documents\WindowsPowerShell\Pester\NewFixtureFunctionTemplate.ps1" } -MockWith { Join-Path -Path "TestDrive:\" -ChildPath $ChildPath }

            $path = "TestDrive:\"
            $name = "FunctionTemplate-Fixture"

            New-Fixture -Name $name -Path $path | Out-Null
            $testFilePath = Join-Path -Path $path -ChildPath "$name.ps1"
            $testFilePath | Should Exist
            [System.IO.File]::ReadAllText( (Get-Item $testFilePath).FullName ) | Should Be "FUNCTION TEMPLATE CONTENT`r`n"
        }
    }

}

