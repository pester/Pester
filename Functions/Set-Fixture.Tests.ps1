$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Set-StrictMode -Version Latest

Describe "Set-Fixture" {
    It "Name parameter is mandatory:" {
        (get-command Set-Fixture).Parameters.Name.ParameterSets.__AllParameterSets.IsMandatory | Should Be $true
    }

    Context "Only Name parameter is specified:" {
        It "Creates fixture in current directory:" {
            $name = "Test-Fixture"
            $path = "TestDrive:\"       
            
            pushd  $path
            New-Item -path "$path$name"
            Set-Fixture -Name $name | Out-Null
            popd

            Join-Path -Path $path -ChildPath "$name.ps1" | Should Exist
            Join-Path -Path $path -ChildPath "$name.Tests.ps1" | Should Exist
            Remove-Item -path "$path$name"
            
        }

    }

}

