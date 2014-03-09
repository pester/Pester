$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
#the function is exported by the Pester module, dot-sourcing would override it
#. "$here\$sut"

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
            
			#Create the same files twice
	        New-Fixture -Name $name -Path $path | Out-Null
					
			#TODO find a better way to test this
			#weird way to test this, but I can't redirect the Warning easily without breaking PowerShell v2 compatibility 
			$message = &{
				try 
				{ 
					
					$ErrorActionPreference = 'SilentlyContinue'
					$WarningPreference = 'Stop'
					New-Fixture -Name $name -Path $path | Out-Null
				} 
				catch 
				{ 
					"$_"
				}
			}
			$message | Should Match 'WarningPreference'
        }
		
    }
	#TODO add tests that validate the contents of default files
}

