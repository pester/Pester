$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

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
        It "Creates fixture in full Path:" {
            $name = "Test-Fixture"
            $path = "TestDrive:\full"
                    
            New-Fixture -Name $name -Path $path | Out-Null 
            
            Join-Path -Path $path -ChildPath "$name.ps1" | Should Exist
            Join-Path -Path $path -ChildPath "$name.Tests.ps1" | Should Exist
            
        }
        
        It "Creates fixture in relative Path:" {
            $name = "Test-Fixture"
            $path = "TestDrive:\"
            
            pushd  $path 
                New-Fixture -Name $name -Path relative | Out-Null 
            popd
            
            Join-Path -Path "$path\relative" -ChildPath "$name.ps1" | Should Exist
            Join-Path -Path "$path\relative" -ChildPath "$name.Tests.ps1" | Should Exist
            
        }
        
        It "Creates fixture if Path is set to '.':" {
            $name = "Test-Fixture"
            $path = "TestDrive:\"
            
            pushd  $path 
                New-Fixture -Name $name -Path . | Out-Null 
            popd
            
            Join-Path -Path "$path" -ChildPath "$name.ps1" | Should Exist
            Join-Path -Path "$path" -ChildPath "$name.Tests.ps1" | Should Exist
            
        }
    }
}

