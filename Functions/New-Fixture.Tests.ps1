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

            (Get-Content -Path $functionFilePath -Raw) | Should Be ("function #name# {`r`n`r`n}`r`n" -replace "#name#",$name)
        }

        It "Creates the default test template" {
            Mock -ModuleName Pester Test-Path -ParameterFilter { $path -eq (Join-Path $env:USERPROFILE "WindowsPowerShell\Pester\NewFixtureTestTemplate.ps1") } -MockWith { $false }
            
            $path = "TestDrive:\"
            $name = "DefaultTestTemplate-Fixture"

            New-Fixture -Name $name -Path $path | Out-Null
            $testFilePath = Join-Path -Path $path -ChildPath "$name.Tests.ps1"

            $testFilePath | Should Exist

            $expectedTestFileContent = @'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

Describe "#name#" {
    It "does something useful" {
        $true | Should Be $false
    }
}

'@
            $expectedTestFileContent = $expectedTestFileContent -replace "#name#",$name

            (Get-Content -Path $testFilePath -Raw) | Should Be ($expectedTestFileContent)
        }
    }

    Context "Custom fixture templates are in Env:\USERPROFILE\WindowsPowerShell\Pester" {
        It "Copies the content of NewFixtureTestTemplate.ps1 to the test file" {
            
            Mock -ModuleName Pester Test-Path -ParameterFilter { $path -eq (Join-Path $env:USERPROFILE "WindowsPowerShell\Pester\NewFixtureTestTemplate.ps1") } -MockWith { $true }
            Mock -ModuleName Pester Get-Content -ParameterFilter { $path -eq (Join-Path $env:USERPROFILE "WindowsPowerShell\Pester\NewFixtureTestTemplate.ps1") } -MockWith { "TEST TEMPLATE CONTENT" } 

            $path = "TestDrive:\"
            $name = "TestTemplate-Fixture"

            New-Fixture -Name $name -Path $path | Out-Null
            $testFilePath = Join-Path -Path $path -ChildPath "$name.Tests.ps1"
            $testFilePath | Should Exist
            Get-Content $testFilePath -Raw | Should Be "TEST TEMPLATE CONTENT`r`n"
        }

        It "Copies the content of NewFixtureFunctionTemplate.ps1 to the function file" {
            
            Mock -ModuleName Pester Test-Path -ParameterFilter { $path -eq (Join-Path $env:USERPROFILE "WindowsPowerShell\Pester\NewFixtureFunctionTemplate.ps1") } -MockWith { $true }
            Mock -ModuleName Pester Get-Content -ParameterFilter { $path -eq (Join-Path $env:USERPROFILE "WindowsPowerShell\Pester\NewFixtureFunctionTemplate.ps1") } -MockWith { "TEST TEMPLATE CONTENT" }

            $path = "TestDrive:\"
            $name = "FunctionTemplate-Fixture"

            New-Fixture -Name $name -Path $path | Out-Null
            $testFilePath = Join-Path -Path $path -ChildPath "$name.ps1"
            $testFilePath | Should Exist
            Get-Content $testFilePath -Raw | Should Be "TEST TEMPLATE CONTENT`r`n"
        }

    }

}

