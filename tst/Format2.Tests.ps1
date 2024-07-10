Set-StrictMode -Version Latest

InPesterModuleScope {

    BeforeDiscovery {
        Add-Type -TypeDefinition '
        namespace Assertions.TestType {
            public class Person {
                // powershell v2 mandates fully implemented properties
                string _name;
                int _age;
                public string Name { get { return _name; } set { _name = value; } }
                public int Age { get { return _age; } set { _age = value; } }
            }
        }'
    }


    Describe "Format-Collection2" {
        It "Formats empty collection to @()" {
            Format-Collection2 -Value @() | Verify-Equal "@()"
        }

        It "Formats collection of values '<value>' to '<expected>' using the default separator" -TestCases @(
            @{ Value = (1, 2, 3); Expected = "@(1, 2, 3)" }
        ) {
            Format-Collection2 -Value $Value | Verify-Equal $Expected
        }

        It "Formats collection of values '<value>' to '<expected>' using the default separator" -TestCases @(
            @{ Value = (1, 2, 3); Expected = "@(1, 2, 3)" }
        ) {
            Format-Collection2 -Value $Value | Verify-Equal $Expected
        }

        It "Formats collection on single line when it is shorter than 50 characters" -TestCases @(
            @{ Value = (1, 2, 3); Expected = "@(1, 2, 3)" }
            @{ Value = @([string]::new("*", 44)); Expected = "@('$([string]::new("*", 44))')" }
        ) {
            Format-Collection2 -Value $Value -Pretty | Verify-Equal $Expected
        }

        It "Formats collection on multiple lines when it is longer than 50 characters" -TestCases @(
            @{ Value = ([string]::new("*", 25), [string]::new("-", 25)); Expected = "@(`n    '$([string]::new("*", 25))',`n    '$([string]::new("-", 25))'`n)" }
            @{ Value = @([string]::new("*", 60)); Expected = "@(`n    '$([string]::new("*", 60))'`n)" }
        ) {
            Format-Collection2 -Value $Value -Pretty | Verify-Equal $Expected
        }
    }

    Describe "Format-Number" {
        It "Formats number to use . separator (tests anything only on non-english systems --todo)" -TestCases @(
            @{ Value = 1.1; },
            @{ Value = [double] 1.1; },
            @{ Value = [float] 1.1; },
            @{ Value = [single] 1.1; },
            @{ Value = [decimal] 1.1; }
        ) {
            param ($Value)
            Format-Number -Value $Value | Verify-Equal "1.1"
        }
    }

    Describe "Format-Object2" {
        It "Formats object '<value>' to '<expected>'" -TestCases @(
            @{ Value = ([PSCustomObject]@{Name = 'Jakub'; Age = 28 }); Expected = "PSObject{Age=28; Name='Jakub'}" },
            @{ Value = (New-Object -Type Assertions.TestType.Person -Property @{Name = 'Jakub'; Age = 28 }); Expected = "Assertions.TestType.Person{Age=28; Name='Jakub'}" }
        ) {
            param ($Value, $Expected)
            Format-Object2 -Value $Value | Verify-Equal $Expected
        }

        It "Formats object '<value>' with selected properties '<selectedProperties>' to '<expected>'" -TestCases @(
            @{ Value = ([PSCustomObject]@{Name = 'Jakub'; Age = 28 }); SelectedProperties = "Age"; Expected = "PSObject{Age=28}" },
            @{
                Value              = (New-Object -Type Assertions.TestType.Person -Property @{Name = 'Jakub'; Age = 28 })
                SelectedProperties = 'Name'
                Expected           = "Assertions.TestType.Person{Name='Jakub'}"
            }
        ) {
            param ($Value, $SelectedProperties, $Expected)
            Format-Object2 -Value $Value -Property $SelectedProperties | Verify-Equal $Expected
        }

        It "Formats current process with selected properties Name and Id correctly" {
            # this used to be a normal unit test but Idle process does not exist
            # cross platform so we use the current process, which can also have
            # different names among powershell versions
            $process = Get-Process -PID $PID
            $name = $process.Name
            $id = $process.Id
            $SelectedProperties = "Name", "Id"
            $expected = "Diagnostics.Process{Id=$id; Name='$name'}"

            Format-Object2 -Value $process -Property $selectedProperties | Verify-Equal $Expected
        }
    }

    Describe "Format-Boolean2" {
        It "Formats boolean '<value>' to '<expected>'" -TestCases @(
            @{ Value = $true; Expected = '$true' },
            @{ Value = $false; Expected = '$false' }
        ) {
            param($Value, $Expected)
            Format-Boolean2 -Value $Value | Verify-Equal $Expected
        }
    }

    Describe "Format-Null2" {
        It "Formats null to '`$null'" {
            Format-Null2 | Verify-Equal '$null'
        }
    }

    Describe "Format-ScriptBlock2" {
        It "Formats scriptblock as string with curly braces" {
            Format-ScriptBlock2 -Value { abc } | Verify-Equal '{ abc }'
        }
    }

    Describe "Format-Hashtable2" {
        It "Formats empty hashtable as @{}" {
            Format-Hashtable2 @{} | Verify-Equal '@{}'
        }

        It "Formats hashtable as '<expected>'" -TestCases @(
            @{ Value = @{Age = 28; Name = 'Jakub' }; Expected = "@{Age=28; Name='Jakub'}" }
            @{ Value = @{Z = 1; H = 1; A = 1 }; Expected = '@{A=1; H=1; Z=1}' }
            @{ Value = @{Hash = @{Hash = 'Value' } }; Expected = "@{Hash=@{Hash='Value'}}" }
        ) {
            param ($Value, $Expected)
            Format-Hashtable2 $Value | Verify-Equal $Expected
        }
    }

    Describe "Format-Dictionary2" {
        It "Formats empty dictionary as @{}" {
            Format-Dictionary2 (New-Dictionary @{}) | Verify-Equal 'Dictionary{}'
        }

        It "Formats dictionary as '<expected>'" -TestCases @(
            @{ Value = New-Dictionary @{Age = 28; Name = 'Jakub' }; Expected = "Dictionary{Age=28; Name='Jakub'}" }
            @{ Value = New-Dictionary @{Z = 1; H = 1; A = 1 }; Expected = 'Dictionary{A=1; H=1; Z=1}' }
            @{ Value = New-Dictionary @{Dict = ( New-Dictionary @{Dict = 'Value' }) }; Expected = "Dictionary{Dict=Dictionary{Dict='Value'}}" }
        ) {
            param ($Value, $Expected)
            Format-Dictionary2 $Value | Verify-Equal $Expected
        }
    }

    Describe "Format-Nicely2" {
        It "Formats value '<value>' correctly to '<expected>'" -TestCases @(
            @{ Value = $null; Expected = '$null' }
            @{ Value = $true; Expected = '$true' }
            @{ Value = $false; Expected = '$false' }
            @{ Value = 'a' ; Expected = "'a'" },
            @{ Value = 1; Expected = '1' },
            @{ Value = (1, 2, 3); Expected = '@(1, 2, 3)' },
            @{ Value = 1.1; Expected = '1.1' },
            @{ Value = [int]; Expected = '[int]' }
            @{ Value = [PSCustomObject]@{ Name = "Jakub" }; Expected = "PSObject{Name='Jakub'}" },
            @{ Value = (New-Object -Type Assertions.TestType.Person -Property @{Name = 'Jakub'; Age = 28 }); Expected = "Assertions.TestType.Person{Age=28; Name='Jakub'}" }
            @{ Value = @{Name = 'Jakub'; Age = 28 }; Expected = "@{Age=28; Name='Jakub'}" }
            @{ Value = New-Dictionary @{Age = 28; Name = 'Jakub' }; Expected = "Dictionary{Age=28; Name='Jakub'}" }
        ) {
            Format-Nicely2 -Value $Value | Verify-Equal $Expected
        }
    }

    Describe "Get-DisplayProperty2" {
        It "Returns '<expected>' for '<type>'" -TestCases @(
            @{ Type = "Diagnostics.Process"; Expected = ("Id", "Name") }
        ) {
            param ($Type, $Expected)
            $Actual = Get-DisplayProperty2 -Type $Type
            "$Actual" | Verify-Equal "$Expected"
        }
    }

    Describe "Format-Type2" {
        It "Given '<value>' it returns the correct shortened type name '<expected>'" -TestCases @(
            @{ Value = [int]; Expected = '[int]' },
            @{ Value = [double]; Expected = '[double]' },
            @{ Value = [string]; Expected = '[string]' },
            @{ Value = $null; Expected = '[null]' },
            @{ Value = [Management.Automation.PSObject]; Expected = '[PSObject]' }
        ) {
            param($Value, $Expected)
            Format-Type2 -Value $Value | Verify-Equal $Expected
        }
    }


    Describe "Get-ShortType2" {
        It "Given '<value>' it returns the correct shortened type name '<expected>'" -TestCases @(
            @{ Value = 1; Expected = '[int]' },
            @{ Value = 1.1; Expected = '[double]' },
            @{ Value = 'a' ; Expected = '[string]' },
            @{ Value = $null ; Expected = '[null]' },
            @{ Value = [PSCustomObject]@{Name = 'Jakub' } ; Expected = '[PSObject]' }
        ) {
            param($Value, $Expected)
            Get-ShortType2 -Value $Value | Verify-Equal $Expected
        }
    }

    Describe "Format-String2" {
        It "Formats empty string to ``<empty``> (no quotes)" {
            Format-String2 -Value "" | Verify-Equal '<empty>'
        }

        It "Formats string to be sorrounded by quotes" {
            Format-String2 -Value "abc" | Verify-Equal "'abc'"
        }
    }
}
