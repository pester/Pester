Set-StrictMode -Version Latest

InPesterModuleScope {
    BeforeDiscovery {
        Add-Type -TypeDefinition 'namespace Assertions.TestType {
            public class Person2 {
                // powershell v2 mandates fully implemented properties
                string _name;
                int _age;
                public string Name { get { return _name; } set { _name = value; } }
                public int Age { get { return _age; } set { _age = value; } }
            }
        }'
    }

    BeforeAll {
        function Get-TestCase ($Value) {
            #let's see if this is useful, it's nice for values, but sucks for
            #types that serialize to just the type name (most of them)
            if ($null -ne $Value) {
                @{
                    Value = $Value
                    Type  = $Value.GetType()
                }
            }
            else {
                @{
                    Value = $null
                    Type  = '<none>'
                }
            }
        }

        # Using this to avoid warning when not providing -Options in Compare-Equivalent tests. Cleared in AfterAll
        $defaultOptions = Get-EquivalencyOption
        $PSDefaultParameterValues['Compare-Equivalent:Options'] = $defaultOptions
    }

    AfterAll {
        # Remove default set in BeforeAll
        $PSDefaultParameterValues.Remove('Compare-Equivalent:Options')
    }

    Describe "Test-Same" {
        It "Given the same instance of a reference type it returns `$true" -TestCases @(
            @{ Value = $null },
            @{ Value = @() },
            @{ Value = [Type] },
            @{ Value = ([System.Diagnostics.Process]::new()) }
        ) {
            param($Value)
            Test-Same -Expected $Value -Actual $Value | Verify-True
        }

        It "Given different instances of a reference type it returns `$false" -TestCases @(
            @{ Actual = @(); Expected = @() },
            @{ Actual = ([System.Diagnostics.Process]::new()) ; Expected = ([System.Diagnostics.Process]::new()) }
        ) {
            param($Expected, $Actual)
            Test-Same -Expected $Expected -Actual $Actual | Verify-False
        }
    }

    Describe "Get-TestCase" {
        It "Given a value it returns the value and its type in a hashtable" {
            $expected = @{
                Value = 1
                Type  = [Int]
            }

            $actual = Get-TestCase -Value $expected.Value

            $actual.GetType().Name | Verify-Equal 'hashtable'
            $actual.Value | Verify-Equal $expected.Value
            $actual.Type | Verify-Equal $expected.Type
        }

        It "Given `$null it returns <none> as the name of the type" {
            $expected = @{
                Value = $null
                Type  = 'none'
            }

            $actual = Get-TestCase -Value $expected.Value

            $actual.GetType().Name | Verify-Equal 'hashtable'
            $actual.Value | Verify-Null
            $actual.Type | Verify-Equal '<none>'
        }
    }

    Describe "Get-ValueNotEquivalentMessage" {
        It "Returns correct message when comparing value to an object" {
            $e = 'abc'
            $a = [PSCustomObject]@{ Name = 'Jakub'; Age = 28 }
            Get-ValueNotEquivalentMessage -Actual $a -Expected $e |
                Verify-Equal "Expected 'abc' to be equivalent to the actual value, but got PSObject{Age=28; Name='Jakub'}."
        }

        It "Returns correct message when comparing object to a value" {
            $e = [PSCustomObject]@{ Name = 'Jakub'; Age = 28 }
            $a = 'abc'
            Get-ValueNotEquivalentMessage -Actual $a -Expected $e |
                Verify-Equal "Expected PSObject{Age=28; Name='Jakub'} to be equivalent to the actual value, but got 'abc'."
        }

        It "Returns correct message when comparing value to an array" {
            $e = 'abc'
            $a = 1, 2, 3
            Get-ValueNotEquivalentMessage -Actual $a -Expected $e |
                Verify-Equal "Expected 'abc' to be equivalent to the actual value, but got @(1, 2, 3)."
        }

        It "Returns correct message when comparing value to null" {
            $e = 'abc'
            $a = $null
            Get-ValueNotEquivalentMessage -Actual $a -Expected $e |
                Verify-Equal "Expected 'abc' to be equivalent to the actual value, but got `$null."
        }

        It "Returns correct message for given property" {
            $e = 1
            $a = 2
            Get-ValueNotEquivalentMessage -Actual 1 -Expected 2 -Property ".Age" |
                Verify-Equal "Expected property .Age with value 2 to be equivalent to the actual value, but got 1."
        }

        It "Changes wording to 'equal' when options specify Equality comparator" {
            $e = 1
            $a = 2
            $options = Get-EquivalencyOption -Comparator Equality
            Get-ValueNotEquivalentMessage -Actual 1 -Expected 2 -Options $options |
                Verify-Equal "Expected 2 to be equal to the actual value, but got 1."
        }
    }

    Describe "Is-CollectionSize" {
        It "Given two collections '<expected>' '<actual>' of the same size it returns `$true" -TestCases @(
            @{ Actual = (1, 2, 3); Expected = (1, 2, 3) },
            @{ Actual = (1, 2, 3); Expected = (3, 2, 1) }
        ) {
            param ($Actual, $Expected)
            Is-CollectionSize -Actual $Actual -Expected $Expected | Verify-True
        }

        It "Given two collections '<expected>' '<actual>' of different sizes it returns `$false" -TestCases @(
            @{ Actual = (1, 2, 3); Expected = (1, 2, 3, 4) },
            @{ Actual = (1, 2, 3); Expected = (1, 2) }
            @{ Actual = (1, 2, 3); Expected = @() }
        ) {
            param ($Actual, $Expected)
            Is-CollectionSize -Actual $Actual -Expected $Expected | Verify-False
        }
    }

    Describe "Get-CollectionSizeNotTheSameMessage" {
        It "Given two collections of differrent sizes it returns the correct message" {
            Get-CollectionSizeNotTheSameMessage -Expected (1, 2, 3) -Actual (1, 2) | Verify-Equal "Expected collection @(1, 2, 3) with length 3 to be the same size as the actual collection, but got @(1, 2) with length 2."
        }
    }

    Describe "Compare-ValueEquivalent" {
        It "Given expected that is not a value it throws ArgumentException" {
            $err = { Compare-ValueEquivalent -Actual "dummy" -Expected (Get-Process -Id $PID) } | Verify-Throw
            $err.Exception -is [ArgumentException] | Verify-True
        }

        It "Given values '<expected>' and '<actual>' that are not equivalent it returns message '<message>'." -TestCases @(
            @{ Actual = $null; Expected = 1; Message = "Expected 1 to be equivalent to the actual value, but got `$null." },
            @{ Actual = $null; Expected = ""; Message = "Expected <empty> to be equivalent to the actual value, but got `$null." },
            @{ Actual = $true; Expected = $false; Message = "Expected `$false to be equivalent to the actual value, but got `$true." },
            @{ Actual = $true; Expected = 'False'; Message = "Expected `$false to be equivalent to the actual value, but got `$true." },
            @{ Actual = 1; Expected = -1; Message = "Expected -1 to be equivalent to the actual value, but got 1." },
            @{ Actual = "1"; Expected = 1.01; Message = "Expected 1.01 to be equivalent to the actual value, but got '1'." },
            @{ Actual = "abc"; Expected = "a b c"; Message = "Expected 'a b c' to be equivalent to the actual value, but got 'abc'." },
            @{ Actual = @("abc", "bde"); Expected = "abc"; Message = "Expected 'abc' to be equivalent to the actual value, but got @('abc', 'bde')." },
            @{ Actual = { def }; Expected = "abc"; Message = "Expected 'abc' to be equivalent to the actual value, but got { def }." },
            @{ Actual = ([PSCustomObject]@{ Name = 'Jakub' }); Expected = "abc"; Message = "Expected 'abc' to be equivalent to the actual value, but got PSObject{Name='Jakub'}." },
            @{ Actual = (1, 2, 3); Expected = "abc"; Message = "Expected 'abc' to be equivalent to the actual value, but got @(1, 2, 3)." }
        ) {
            param($Actual, $Expected, $Message)
            Compare-ValueEquivalent -Actual $Actual -Expected $Expected | Verify-Equal $Message
        }
    }

    Describe "Compare-CollectionEquivalent" {
        It "Given expected that is not a collection it throws ArgumentException" {
            $err = { Compare-CollectionEquivalent -Actual "dummy" -Expected 1 } | Verify-Throw
            $err.Exception -is [ArgumentException] | Verify-True
        }

        It "Given two collections '<expected>' '<actual>' of different sizes it returns message '<message>'" -TestCases @(
            @{ Actual = (1, 2, 3); Expected = (1, 2, 3, 4); Message = "Expected collection @(1, 2, 3, 4) with length 4 to be the same size as the actual collection, but got @(1, 2, 3) with length 3." },
            @{ Actual = (1, 2, 3); Expected = (3, 1); Message = "Expected collection @(3, 1) with length 2 to be the same size as the actual collection, but got @(1, 2, 3) with length 3." }
        ) {
            param ($Actual, $Expected, $Message)
            Compare-CollectionEquivalent -Actual $Actual -Expected $Expected | Verify-Equal $Message
        }

        It "Given collection '<expected>' on the expected side and non-collection '<actual>' on the actual side it prints the correct message '<message>'" -TestCases @(
            @{ Actual = 3; Expected = (1, 2, 3, 4); Message = "Expected collection @(1, 2, 3, 4) with length 4, but got 3." },
            @{ Actual = ([PSCustomObject]@{ Name = 'Jakub' }); Expected = (1, 2, 3, 4); Message = "Expected collection @(1, 2, 3, 4) with length 4, but got PSObject{Name='Jakub'}." }
        ) {
            param ($Actual, $Expected, $Message)
            Compare-CollectionEquivalent -Actual $Actual -Expected $Expected | Verify-Equal $Message
        }

        It "Given two collections '<expected>' '<actual>' it compares each value with each value and returns `$null if all of them are equivalent" -TestCases @(
            @{ Actual = (1, 2, 3); Expected = (1, 2, 3) }
            @{ Actual = (1, 2, 3); Expected = (3, 2, 1) }

            # issue https://github.com/nohwnd/Assert/issues/31
            @{ Actual = ($null, $null); Expected = ($null, $null) }
            @{ Actual = ($null, $null, $null); Expected = ($null, $null, $null) }
            @{ Actual = (1, 1, 1, 1); Expected = (1, 1, 1, 1) }
            @{ Actual = (1, 2, 2, 1); Expected = (2, 1, 2, 1) }
            ##

        ) {
            param ($Actual, $Expected)
            Compare-CollectionEquivalent -Actual $Actual -Expected $Expected | Verify-Null
        }

        It "Given two collections '<expected>' '<actual>' it compares each value with each value and returns message '<message> if any of them are not equivalent" -TestCases @(
            @{ Actual = (1, 2, 3); Expected = (4, 5, 6); Message = "Expected collection @(4, 5, 6) to be equivalent to @(1, 2, 3) but some values were missing: @(4, 5, 6)." },
            @{ Actual = (1, 2, 3); Expected = (1, 2, 2); Message = "Expected collection @(1, 2, 2) to be equivalent to @(1, 2, 3) but some values were missing: 2." }
        ) {
            param ($Actual, $Expected, $Message)
            Compare-CollectionEquivalent -Actual $Actual -Expected $Expected | Verify-Equal $Message
        }
    }

    Describe "Compare-ObjectEquivalent" {
        It "Given expected '<expected>' that is not an object it throws ArgumentException" -TestCases @(
            @{ Expected = "a" },
            @{ Expected = "1" },
            @{ Expected = { abc } },
            @{ Expected = (1, 2, 3) }
        ) {
            param($Expected) {}
            $err = { Compare-ObjectEquivalent -Actual "dummy" -Expected $Expected } | Verify-Throw
            $err.Exception -is [ArgumentException] | Verify-True
        }

        It "Given values '<expected>' and '<actual>' that are not equivalent it returns message '<message>'." -TestCases @(
            @{ Actual = 'a'; Expected = ([PSCustomObject]@{ Name = 'Jakub' }); Message = "Expected object PSObject{Name='Jakub'}, but got 'a'." }
        ) {
            param ($Actual, $Expected, $Message)
            Compare-ObjectEquivalent -Expected $Expected -Actual $Actual | Verify-Equal $Message
        }
    }

    Describe "Compare-HashtableEquivalent" {
        It "Given expected '<expected>' that is not a hashtable it throws ArgumentException" -TestCases @(
            @{ Expected = "a" }
        ) {
            param($Expected) {}
            $err = { Compare-HashtableEquivalent -Actual "dummy" -Expected $Expected } | Verify-Throw
            $err.Exception -is [ArgumentException] | Verify-True
        }

        It "Given values '<expected>' and '<actual>' that are not equivalent it returns message '<message>'." -TestCases @(
            @{ Actual = 'a'; Expected = @{ Name = 'Jakub' }; Message = "Expected hashtable @{Name='Jakub'}, but got 'a'." }
            @{ Actual = @{ }; Expected = @{ Name = 'Jakub' }; Message = "Expected hashtable @{Name='Jakub'}, but got @{}.`nExpected has key 'Name' that the actual object does not have." }
            @{ Actual = @{ Name = 'Tomas' }; Expected = @{ Name = 'Jakub' }; Message = "Expected hashtable @{Name='Jakub'}, but got @{Name='Tomas'}.`nExpected property .Name with value 'Jakub' to be equivalent to the actual value, but got 'Tomas'." }
            @{ Actual = @{ Name = 'Tomas'; Value = 10 }; Expected = @{ Name = 'Jakub' }; Message = "Expected hashtable @{Name='Jakub'}, but got @{Name='Tomas'; Value=10}.`nExpected property .Name with value 'Jakub' to be equivalent to the actual value, but got 'Tomas'.`nExpected is missing key 'Value' that the actual object has." }
        ) {
            param ($Actual, $Expected, $Message)

            Compare-HashtableEquivalent -Expected $Expected -Actual $Actual | Verify-Equal $Message
        }
    }

    Describe "Compare-DictionaryEquivalent" {
        It "Given expected '<expected>' that is not a dictionary it throws ArgumentException" -TestCases @(
            @{ Expected = "a" }
        ) {
            param($Expected) {}
            $err = { Compare-DictionaryEquivalent -Actual "dummy" -Expected $Expected } | Verify-Throw
            $err.Exception -is [ArgumentException] | Verify-True
        }

        It "Given values '<expected>' and '<actual>' that are not equivalent it returns message '<message>'." -TestCases @(
            @{ Actual = 'a'; Expected = New-Dictionary @{ Name = 'Jakub' }; Message = "Expected dictionary Dictionary{Name='Jakub'}, but got 'a'." }
            @{ Actual = New-Dictionary @{ }; Expected = New-Dictionary @{ Name = 'Jakub' }; Message = "Expected dictionary Dictionary{Name='Jakub'}, but got Dictionary{}.`nExpected has key 'Name' that the actual object does not have." }
            @{ Actual = New-Dictionary @{ Name = 'Tomas' }; Expected = New-Dictionary @{ Name = 'Jakub' }; Message = "Expected dictionary Dictionary{Name='Jakub'}, but got Dictionary{Name='Tomas'}.`nExpected property .Name with value 'Jakub' to be equivalent to the actual value, but got 'Tomas'." }
            @{ Actual = New-Dictionary @{ Name = 'Tomas'; Value = 10 }; Expected = New-Dictionary @{ Name = 'Jakub' }; Message = "Expected dictionary Dictionary{Name='Jakub'}, but got Dictionary{Name='Tomas'; Value=10}.`nExpected property .Name with value 'Jakub' to be equivalent to the actual value, but got 'Tomas'.`nExpected is missing key 'Value' that the actual object has." }
        ) {
            param ($Actual, $Expected, $Message)

            Compare-DictionaryEquivalent -Expected $Expected -Actual $Actual | Verify-Equal $Message
        }
    }

    Describe "Compare-Equivalent" {
        It "Given values '<expected>' and '<actual>' that are equivalent returns report with Equivalent set to `$true" -TestCases @(
            @{ Actual = $null; Expected = $null },
            @{ Actual = ""; Expected = "" },
            @{ Actual = $true; Expected = $true },
            @{ Actual = $true; Expected = 'True' },
            @{ Actual = 'True'; Expected = $true },
            @{ Actual = $false; Expected = 'False' },
            @{ Actual = 'False'; Expected = $false },
            @{ Actual = 1; Expected = 1 },
            @{ Actual = "1"; Expected = 1 },
            @{ Actual = "abc"; Expected = "abc" },
            @{ Actual = @("abc"); Expected = "abc" },
            @{ Actual = "abc"; Expected = @("abc") },
            @{ Actual = { abc }; Expected = " abc " },
            @{ Actual = " abc "; Expected = { abc } },
            @{ Actual = { abc }; Expected = { abc } }
        ) {
            param ($Actual, $Expected)
            Compare-Equivalent -Expected $Expected -Actual $Actual | Verify-Null
        }

        It "Given values '<expected>' and '<actual>' that are not equivalent it returns message '<message>'." -TestCases @(
            @{ Actual = $null; Expected = 1; Message = "Expected 1 to be equivalent to the actual value, but got `$null." },
            @{ Actual = $null; Expected = ""; Message = "Expected <empty> to be equivalent to the actual value, but got `$null." },
            @{ Actual = $true; Expected = $false; Message = "Expected `$false to be equivalent to the actual value, but got `$true." },
            @{ Actual = $true; Expected = 'False'; Message = "Expected `$false to be equivalent to the actual value, but got `$true." },
            @{ Actual = 1; Expected = -1; Message = "Expected -1 to be equivalent to the actual value, but got 1." },
            @{ Actual = "1"; Expected = 1.01; Message = "Expected 1.01 to be equivalent to the actual value, but got '1'." },
            @{ Actual = "abc"; Expected = "a b c"; Message = "Expected 'a b c' to be equivalent to the actual value, but got 'abc'." },
            @{ Actual = @("abc", "bde"); Expected = "abc"; Message = "Expected 'abc' to be equivalent to the actual value, but got @('abc', 'bde')." },
            @{ Actual = { def }; Expected = "abc"; Message = "Expected 'abc' to be equivalent to the actual value, but got { def }." },
            @{ Actual = "def"; Expected = { abc }; Message = "Expected { abc } to be equivalent to the actual value, but got 'def'." },
            @{ Actual = { abc }; Expected = { def }; Message = "Expected { def } to be equivalent to the actual value, but got { abc }." },
            @{ Actual = (1, 2, 3); Expected = (1, 2, 3, 4); Message = "Expected collection @(1, 2, 3, 4) with length 4 to be the same size as the actual collection, but got @(1, 2, 3) with length 3." },
            @{ Actual = 3; Expected = (1, 2, 3, 4); Message = "Expected collection @(1, 2, 3, 4) with length 4, but got 3." },
            @{ Actual = ([PSCustomObject]@{ Name = 'Jakub' }); Expected = (1, 2, 3, 4); Message = "Expected collection @(1, 2, 3, 4) with length 4, but got PSObject{Name='Jakub'}." },
            @{ Actual = ([PSCustomObject]@{ Name = 'Jakub' }); Expected = "a"; Message = "Expected 'a' to be equivalent to the actual value, but got PSObject{Name='Jakub'}." },
            @{ Actual = 'a'; Expected = ([PSCustomObject]@{ Name = 'Jakub' }); Message = "Expected object PSObject{Name='Jakub'}, but got 'a'." }
            @{ Actual = 'a'; Expected = @{ Name = 'Jakub' }; Message = "Expected hashtable @{Name='Jakub'}, but got 'a'." }
            @{ Actual = 'a'; Expected = New-Dictionary @{ Name = 'Jakub' }; Message = "Expected dictionary Dictionary{Name='Jakub'}, but got 'a'." }
        ) {
            param ($Actual, $Expected, $Message)
            Compare-Equivalent -Expected $Expected -Actual $Actual | Verify-Equal $Message
        }

        It "Comparing the same instance of a psObject returns null" {
            $actual = $expected = [PSCustomObject]@{ Name = 'Jakub' }
            Verify-Same -Expected $expected -Actual $actual

            Compare-Equivalent -Expected $expected -Actual $actual | Verify-Null
        }

        It "Given PSObjects '<expected>' and '<actual> that are different instances but have the same values it returns report with Equivalent set to `$true" -TestCases @(
            @{
                Expected = [PSCustomObject]@{ Name = 'Jakub' }
                Actual   = [PSCustomObject]@{ Name = 'Jakub' }
            },
            @{
                Expected = [PSCustomObject]@{ Name = 'Jakub' }
                Actual   = [PSCustomObject]@{ Name = 'Jakub' }
            },
            @{
                Expected = [PSCustomObject]@{ Age = 28 }
                Actual   = [PSCustomObject]@{ Age = '28' }
            }
        ) {
            param ($Expected, $Actual)
            Verify-NotSame -Expected $Expected -Actual $Actual

            Compare-Equivalent -Expected $Expected -Actual $Actual | Verify-Null
        }

        It "Given PSObjects '<expected>' and '<actual> that have different values in some of the properties it returns message '<message>'" -TestCases @(
            @{
                Expected = [PSCustomObject]@{ Name = 'Jakub'; Age = 28 }
                Actual   = [PSCustomObject]@{ Name = 'Jakub'; Age = 19 }
                Message  = "Expected property .Age with value 28 to be equivalent to the actual value, but got 19."
            },
            @{
                Expected = [PSCustomObject]@{ Name = 'Jakub'; Age = 28 }
                Actual   = [PSCustomObject]@{ Name = 'Jakub' }
                Message  = "Expected has property 'Age' that the actual object does not have."
            },
            @{
                Expected = [PSCustomObject]@{ Name = 'Jakub' }
                Actual   = [PSCustomObject]@{ Name = 'Jakub'; Age = 28 }
                Message  = "Expected is missing property 'Age' that the actual object has."
            }
        ) {
            param ($Expected, $Actual, $Message)
            Verify-NotSame -Expected $Expected -Actual $Actual

            Compare-Equivalent -Expected $Expected -Actual $Actual | Verify-Equal $Message
        }

        It "Given PSObject '<expected>' and object '<actual> that have the same values it returns `$null" -TestCases @(
            @{
                Expected = [Assertions.TestType.Person2]@{ Name = 'Jakub'; Age = 28 }
                Actual   = [PSCustomObject]@{ Name = 'Jakub'; Age = 28 }
            }
        ) {
            param ($Expected, $Actual)
            Compare-Equivalent -Expected $Expected -Actual $Actual | Verify-Null
        }


        It "Given PSObjects '<expected>' and '<actual> that contain different arrays in the same property returns the correct message" -TestCases @(
            @{
                Expected = [PSCustomObject]@{ Numbers = 1, 2, 3 }
                Actual   = [PSCustomObject]@{ Numbers = 3, 4, 5 }
            }
        ) {
            param ($Expected, $Actual)

            Compare-Equivalent -Expected $Expected -Actual $Actual | Verify-Equal "Expected collection in property .Numbers which is @(1, 2, 3) to be equivalent to @(3, 4, 5) but some values were missing: @(1, 2)."
        }

        It "Comparing psObjects that have collections of objects returns `$null when the objects have the same value" -TestCases @(
            @{
                Expected = [PSCustomObject]@{ Objects = ([PSCustomObject]@{ Name = "Jan" }), ([PSCustomObject]@{ Name = "Tomas" }) }
                Actual   = [PSCustomObject]@{ Objects = ([PSCustomObject]@{ Name = "Tomas" }), ([PSCustomObject]@{ Name = "Jan" }) }
            }
        ) {
            param ($Expected, $Actual)
            Compare-Equivalent -Expected $Expected -Actual $Actual | Verify-Null
        }

        It "Comparing psObjects that have collections of objects returns the correct message when the items in the collection differ" -TestCases @(
            @{
                Expected = [PSCustomObject]@{ Objects = ([PSCustomObject]@{ Name = "Jan" }), ([PSCustomObject]@{ Name = "Petr" }) }
                Actual   = [PSCustomObject]@{ Objects = ([PSCustomObject]@{ Name = "Jan" }), ([PSCustomObject]@{ Name = "Tomas" }) }
            }
        ) {
            param ($Expected, $Actual)
            Compare-Equivalent -Expected $Expected -Actual $Actual | Verify-Equal "Expected collection in property .Objects which is @(PSObject{Name='Jan'}, PSObject{Name='Petr'}) to be equivalent to @(PSObject{Name='Jan'}, PSObject{Name='Tomas'}) but some values were missing: @(PSObject{Name='Petr'})."
        }

        It "Comparing DataTable" {
            # todo: move this to it's own describe, split the tests to smaller parts, and make them use Verify-* axioms
            $Expected = [System.Data.DataTable]::new('Test')
            $null = $Expected.Columns.Add('IDD', [System.Int32])
            $null = $Expected.Columns.Add('Name')
            $null = $Expected.Columns.Add('Junk')
            $null = $Expected.Columns.Add('IntT', [System.Int32])
            $null = $Expected.Rows.Add(1, 'A', 'AAA', 5)
            $null = $Expected.Rows.Add(3, 'C', $null, $null)

            $Actual = [System.Data.DataTable]::new('Test')
            $null = $Actual.Columns.Add('IDD', [System.Int32])
            $null = $Actual.Columns.Add('Name')
            $null = $Actual.Columns.Add('Junk')
            $null = $Actual.Columns.Add('IntT', [System.Int32])
            $null = $Actual.Rows.Add(3, 'C', $null, $null)
            $null = $Actual.Rows.Add(1, 'A', 'AAA', 5)

            Should-BeEquivalent -Actual $Actual -Expected $Expected

            function SerializeDeserialize ($InputObject) {
                # psv2 compatibility
                # $ExpectedDeserialized = [System.Management.Automation.PSSerializer]::Deserialize([System.Management.Automation.PSSerializer]::Serialize($Expected))
                # Alternatively this could be done in memory via https://github.com/Jaykul/Reflection/blob/master/CliXml.psm1, but I don't want to fiddle with more
                # relfection right now
                try {
                    $path = [IO.Path]::GetTempFileName()

                    Export-Clixml -Path $path -InputObject $InputObject -Force | Out-Null
                    Import-Clixml -Path $path
                }
                finally {
                    if ($null -ne $path -and (Test-Path $path)) {
                        Remove-Item -Path $path -Force
                    }
                }
            }


            $ExpectedDeserialized = SerializeDeserialize $Expected
            $ActualDeserialized = SerializeDeserialize $Actual
            Should-BeEquivalent -Actual $ActualDeserialized -Expected $ExpectedDeserialized
            Should-BeEquivalent -Actual $Actual -Expected $ExpectedDeserialized

            { Should-BeEquivalent -Actual $Actual -Expected $Expected -StrictOrder } | Should -Throw

            $Actual.Rows[1].Name = 'D'
            { Should-BeEquivalent -Actual $Actual -Expected $Expected } | Should -Throw

            $ExpectedDeserialized = SerializeDeserialize $Expected
            $ActualDeserialized = SerializeDeserialize $Actual
            { Should-BeEquivalent -Actual $ActualDeserialized -Expected $ExpectedDeserialized } | Should -Throw
            { Should-BeEquivalent -Actual $Actual -Expected $ExpectedDeserialized } | Should -Throw
        }

        It "Can be called with positional parameters" {
            { Should-BeEquivalent 1 2 } | Verify-AssertionFailed
        }
    }
}
