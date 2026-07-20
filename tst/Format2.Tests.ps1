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

        It "Indents nested objects by depth when -Pretty is used" {
            $value = [PSCustomObject]@{ a = [PSCustomObject]@{ b = 1 } }
            $expected = "PSObject{`n    a=PSObject{`n        b=1;`n    };`n}"
            Format-Nicely2 -Value $value -Pretty | Verify-Equal $expected
        }

        It "Indents objects nested inside a collection by depth when -Pretty is used" {
            $value = @(([PSCustomObject]@{ n = 'x'; v = 1 }), ([PSCustomObject]@{ n = 'y'; v = 2 }))
            $expected = "@(`n    PSObject{`n        n='x';`n        v=1;`n    },`n    PSObject{`n        n='y';`n        v=2;`n    }`n)"
            Format-Nicely2 -Value $value -Pretty | Verify-Equal $expected
        }

        # Regression test for https://github.com/pester/Pester/issues/2474
        # DirectoryInfo has circular references (Root -> DirectoryInfo) that caused
        # infinite recursion. Verify formatting completes without hanging.
        It "Formats DirectoryInfo without infinite recursion" {
            $dir = [System.IO.DirectoryInfo]::new($TestDrive)
            $job = Start-Job -ScriptBlock {
                param($modulePath, $dirPath)
                Import-Module $modulePath
                $d = [System.IO.DirectoryInfo]::new($dirPath)
                & (Get-Module Pester) { Format-Nicely2 -Value $args[0] } $d
            } -ArgumentList (Get-Module Pester).Path, $TestDrive
            $result = $job | Wait-Job -Timeout 10 | Receive-Job
            $job | Remove-Job -Force
            $result | Should -Not -BeNullOrEmpty
        }

        # Regression test for https://github.com/pester/Pester/issues/2828
        # A self-referential object (Self points back at the same instance, like SMO stubs or
        # DirectoryInfo.Parent/Root) used to recurse until PowerShell threw a call depth overflow.
        It "Stops expanding a self-referential object instead of overflowing the call stack" {
            $o = [PSCustomObject]@{ Name = 'x' }
            $o | Add-Member -NotePropertyName Self -NotePropertyValue $o

            # Formatting completes at all (no ScriptCallDepthException) and the back-reference is
            # cut off with a type-only marker once the max depth is reached, not expanded forever.
            $formatted = Format-Nicely2 -Value $o
            $formatted.Contains('Self=[PSObject]') | Verify-True
        }

        It "Truncates values nested past the max depth to their type" {
            # Build a chain deeper than the max depth. The leaf sits below the cut-off, so it must
            # never be reached, and the deepest shown value is a type-only marker instead.
            $node = [PSCustomObject]@{ Leaf = 'bottom' }
            foreach ($i in 1..20) { $node = [PSCustomObject]@{ Child = $node } }

            $formatted = Format-Nicely2 -Value $node
            $formatted.Contains("'bottom'") | Verify-False
            $formatted.Contains('[PSObject]') | Verify-True
        }

        # Regression test for https://github.com/pester/Pester/issues/2865
        # A shallow -MaxDepth collapses arbitrary objects to their type instead of walking their
        # properties. This is what stops complex objects (e.g. CommandInfo) from fanning out into an
        # enormous, deeply nested tree that takes so long to format it looks like a hang.
        It "With -MaxDepth 1 collapses an unregistered object to its type but still renders scalars and a level of containers" {
            $object = [PSCustomObject]@{ Name = 'Jakub'; Age = 28 }
            # An unknown object needs more than one level of budget, so it collapses to its type ...
            Format-Nicely2 -Value $object -MaxDepth 1 | Verify-Equal '[PSObject]'
            # ... while scalars and a single level of arrays/hashtables still render, and objects
            # nested inside them collapse to their type instead of expanding.
            Format-Nicely2 -Value 'Jakub' -MaxDepth 1 | Verify-Equal "'Jakub'"
            Format-Nicely2 -Value @(1, 2, 3) -MaxDepth 1 | Verify-Equal '@(1, 2, 3)'
            Format-Nicely2 -Value @{ Name = 'x' } -MaxDepth 1 | Verify-Equal "@{Name='x'}"
            Format-Nicely2 -Value @{ cmd = $object } -MaxDepth 1 | Verify-Equal '@{cmd=[PSObject]}'
        }

        It "Renders a registered type as a compact representative summary even at a shallow -MaxDepth" {
            # A CommandInfo is registered (base type) to show only its Name, so it never fans out into a
            # slow, deeply nested dump and stays informative at any depth (#2865).
            $command = Get-Command -Name 'Get-Command'
            Format-Nicely2 -Value $command -MaxDepth 1 | Verify-Equal "Management.Automation.CmdletInfo{Name='Get-Command'}"
        }

        It "Formats integers as numbers so a simple array renders at a shallow depth" {
            # Integers must be treated as scalars (not ValueType objects), otherwise a plain array
            # collapses to '@([int], [int], [int])' once the budget is shallow (#2865).
            Format-Nicely2 -Value 42 -MaxDepth 1 | Verify-Equal '42'
            Format-Nicely2 -Value @(1, 2, 3) -MaxDepth 1 | Verify-Equal '@(1, 2, 3)'
        }
    }

    Describe "Format-NicelyForTemplate" {
        It "Passes a top-level string through unquoted so '<user.name>' stays clean" {
            Format-NicelyForTemplate -Value 'Jakub' | Verify-Equal 'Jakub'
        }

        It "Renders '<value>' as '<expected>'" -TestCases @(
            @{ Value = $null; Expected = '$null' }
            @{ Value = $true; Expected = '$true' }
            @{ Value = 42; Expected = '42' }
            @{ Value = @(1, 2, 3); Expected = '@(1, 2, 3)' }
            @{ Value = @{ Name = 'x'; Age = 1 }; Expected = "@{Age=1; Name='x'}" }
        ) {
            param ($Value, $Expected)
            Format-NicelyForTemplate -Value $Value | Verify-Equal $Expected
        }

        # Regression test for https://github.com/pester/Pester/issues/2865
        # Referencing a whole complex object (like CommandInfo) in a test/block name used to expand
        # into an enormous, deeply nested property dump that took so long to build it looked like a
        # hang. A CommandInfo is a registered type, so it must instead render a compact representative
        # summary (its Name) and return promptly.
        It "Renders a registered complex type like CommandInfo as a short summary instead of hanging" {
            $job = Start-Job -ScriptBlock {
                param($modulePath)
                Import-Module $modulePath
                & (Get-Module Pester) { Format-NicelyForTemplate -Value (Get-Command -Name 'Invoke-Pester') }
            } -ArgumentList (Get-Module Pester).Path
            $result = $job | Wait-Job -Timeout 30 | Receive-Job
            $job | Remove-Job -Force

            # Completes at all (no hang) and shows only the representative property, not the property tree.
            $result | Verify-Equal "Management.Automation.FunctionInfo{Name='Invoke-Pester'}"
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

        # Regression tests for https://github.com/pester/Pester/issues/2474
        # DirectoryInfo and FileInfo have circular references (Root, Directory)
        # that cause infinite recursion without an explicit property map.
        It "Returns 'Name FullName' for DirectoryInfo" {
            $Actual = Get-DisplayProperty2 -Type ([System.IO.DirectoryInfo])
            "$Actual" | Verify-Equal "Name FullName"
        }

        It "Returns 'Name FullName Length' for FileInfo" {
            $Actual = Get-DisplayProperty2 -Type ([System.IO.FileInfo])
            "$Actual" | Verify-Equal "Name FullName Length"
        }

        # Regression test for https://github.com/pester/Pester/issues/2865
        # CommandInfo is registered by base type, so all of its subtypes (FunctionInfo, CmdletInfo,
        # AliasInfo, ExternalScriptInfo, ...) are summarised by their Name from a single entry.
        It "Returns 'Name' for the CommandInfo subtype '<type>'" -TestCases @(
            @{ Type = [System.Management.Automation.FunctionInfo] }
            @{ Type = [System.Management.Automation.CmdletInfo] }
            @{ Type = [System.Management.Automation.AliasInfo] }
        ) {
            param ($Type)
            $Actual = Get-DisplayProperty2 -Type $Type
            "$Actual" | Verify-Equal "Name"
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

        # Regression tests for https://github.com/pester/Pester/issues/2561
        # Control characters must be escaped to Unicode control pictures so they are
        # visible in error messages instead of being invisible or breaking output.
        # Note: control picture chars (U+2400-U+241B) are written as literal Unicode in
        # single-quoted strings so the tests parse on PowerShell 5.1 too (`u{XXXX} is PS 6+).
        It "Escapes null character to control picture" {
            Format-String2 -Value "`0" | Verify-Equal "'␀'"
        }

        It "Escapes bell character to control picture" {
            Format-String2 -Value "`a" | Verify-Equal "'␇'"
        }

        It "Escapes backspace character to control picture" {
            Format-String2 -Value "`b" | Verify-Equal "'␈'"
        }

        It "Escapes tab character to control picture" {
            Format-String2 -Value "`t" | Verify-Equal "'␉'"
        }

        It "Escapes form feed character to control picture" {
            Format-String2 -Value "`f" | Verify-Equal "'␌'"
        }

        It "Escapes carriage return character to control picture" {
            Format-String2 -Value "`r" | Verify-Equal "'␍'"
        }

        It "Escapes newline character to control picture" {
            Format-String2 -Value "`n" | Verify-Equal "'␊'"
        }

        It "Escapes ESC character to control picture" {
            Format-String2 -Value "$([char]27)" | Verify-Equal "'␛'"
        }

        It "Escapes DEL character to its control picture" {
            # DEL (0x7F) sits just outside the C0 range; it maps to U+2421 SYMBOL FOR DELETE.
            Format-String2 -Value "$([char]0x7F)" | Verify-Equal "'␡'"
        }

        It "Escapes C1 control '<char>' to a visible \u escape '<expected>'" -TestCases @(
            # C1 controls (0x80..0x9F) have no control-picture glyph, so they are shown as \u00XX.
            # NEL (0x85) and CSI (0x9B) are single-byte ANSI controls that are otherwise invisible.
            @{ Char = [char]0x85; Expected = "'\u0085'" }
            @{ Char = [char]0x9B; Expected = "'\u009B'" }
            @{ Char = [char]0x80; Expected = "'\u0080'" }
        ) {
            param ($Char, $Expected)
            Format-String2 -Value "$Char" | Verify-Equal $Expected
        }

        It "Leaves normal strings unchanged" {
            Format-String2 -Value "hello" | Verify-Equal "'hello'"
        }

        It "Escapes ANSI sequence making escape char visible" {
            # ESC[31m is a common ANSI red color code; the ESC byte should become ␛
            $ansi = "$([char]27)[31m"
            $result = Format-String2 -Value $ansi
            $result | Verify-Equal "'␛[31m'"
        }

        It "Escapes multiple control chars in one string" {
            $value = "a`t`nb"
            $result = Format-String2 -Value $value
            $result | Verify-Equal "'a␉␊b'"
        }

        It "Escaped output contains no actual control characters" {
            # Round-trip: the escaped output should be a clean displayable string
            $value = "`0`a`b`t`f`r`n$([char]27)$([char]0x7F)$([char]0x85)$([char]0x9B)"
            $result = Format-String2 -Value $value
            # The result should not contain any of the original control characters
            # (C0 0x00-0x1F, DEL 0x7F, or C1 0x80-0x9F).
            $result | Should -Not -Match '[\x00-\x1F\x7F-\x9F]'
        }
    }
}
