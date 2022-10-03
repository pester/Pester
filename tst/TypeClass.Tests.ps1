Set-StrictMode -Version Latest

# BeforeDiscovery
function New-Dictionary ([hashtable]$Hashtable) {
    $d = new-object "Collections.Generic.Dictionary[string,object]"

    $Hashtable.GetEnumerator() | foreach { $d.Add($_.Key, $_.Value) }

    $d
}

BeforeAll {
    . "$PSScriptRoot\../src/TypeClass.ps1"
}

Describe "Is-Value" {
    It "Given '<value>', which is a value, string, enum, scriptblock or array with a single item of those types it returns `$true" -TestCases @(
        @{ Value = 1 },
        @{ Value = 2 },
        @{ Value = 1.2 },
        @{ Value = 1.3 },
        @{ Value = "abc" },
        @{ Value = [System.DayOfWeek]::Monday },
        @{ Value = @("abc") },
        @{ Value = @(1) },
        @{ Value = { abc } }
    ) {
        Is-Value -Value $Value | Verify-True
    }

    It "Given `$null it returns `$false" {
        Is-Value -Value $null | Verify-False
    }

    It "Given reference type (not string) '<value>' it returns `$false" -TestCases @(
        @{ Value = @() },
        @{ Value = @(1, 2) },
        @{ Value = @{} },
        @{ Value = [type] },
        @{ Value = (New-Object -TypeName Diagnostics.Process) }
    ) {
        Is-Value -Value $Value | Verify-False
    }
}

#number

Describe "Is-DecimalNumber" {
    It "Given a number it returns `$true" -TestCases @(
        @{ Value = 1.1; },
        @{ Value = [double] 1.1; },
        @{ Value = [float] 1.1; },
        @{ Value = [single] 1.1; },
        @{ Value = [decimal] 1.1; }
    ) {
        Is-DecimalNumber -Value $Value | Verify-True
    }

    It "Given a string it returns `$false" {
        Is-DecimalNumber -Value "abc" | Verify-False
    }
}

Describe "Is-ScriptBlock" {
    It "Given a scriptblock '{<value>}' it returns `$true" -TestCases @(
        @{ Value = {} },
        @{ Value = { abc } },
        @{ Value = { Get-Process } }
    ) {
        Is-ScriptBlock -Value $Value | Verify-True
    }

    It "Given a value '<value>' that is not a scriptblock it returns `$false" -TestCases @(
        @{ Value = $null },
        @{ Value = 1 },
        @{ Value = 'abc' },
        @{ Value = [Type] }
    ) {
        Is-ScriptBlock -Value $Value | Verify-False
    }
}

# -- KeyValue collections
Describe "Is-Hashtable" {
    It "Given hashtable '<value>' it returns `$true" -TestCases @(
        @{Value = @{} }
        @{Value = @{Name = "Jakub" } }
    ) {
        Is-Hashtable -Value $Value | Verify-True
    }

    It "Given a value '<value>' which is not a hashtable it returns `$false" -TestCases @(
        @{ Value = "Jakub" }
        @{ Value = 1..4 }
    ) {
        Is-Hashtable -Value $Value | Verify-False
    }
}

Describe "Is-Dictionary" {
    It "Given dictionary '<value>' it returns `$true" -TestCases @(
        @{ Value = New-Object "Collections.Generic.Dictionary[string,object]" }
        @{ Value = New-Dictionary @{Name = "Jakub" } }
    ) {
        Is-Dictionary -Value $Value | Verify-True
    }

    It "Given a value '<value>' which is not a dictionary it returns `$false" -TestCases @(
        @{ Value = "Jakub" }
        @{ Value = 1..4 }
    ) {
        Is-Dictionary -Value $Value | Verify-False
    }
}


# -- collection
Describe "Is-Collection" {
    It "Given a collection '<value>' of type '<value.GetType()>' it returns `$true" -TestCases @(
        @{ Value = @() }
        @{ Value = 1, 2, 3 }
        # the extra casts are for powershell v2 compatibility
        @{ Value = [System.Collections.Generic.List[int]]([int[]] 1) }
        @{ Value = [System.Collections.Generic.List[decimal]]([decimal[]] 2D) }
        @{ Value = [Collections.Generic.List[Int]]([int[]](1, 2, 3)) }
        # @{ Value = (Get-Process) } <- fails in docker because there is just one process
    ) {
        Is-Collection -Value $Value | Verify-True
    }

    It "Given `$null it returns `$false" {
        Is-Collection -Value $null | Verify-False
    }

    It "Given an object '<value>' of type '<value.GetType()>' that is not a collection it returns `$false" -TestCases @(
        @{ Value = [char] 'a' }
        @{ Value = "a" }

        @{ Value = 1 }
        @{ Value = 1D }
        @{ Value = 1.1 }

        @{ Value = 101 }
        @{ Value = 101L }
        @{ Value = 101D }
        @{ Value = 101.1 }

        @{ Value = 1MB }
        @{ Value = 1DMB }
        @{ Value = 1.1MB }

        @{ Value = {} }

        @{ Value = @{} }
        @{ Value = @{ Name = 'Jakub' } }

        @{ Value = (Get-Process -Id $PID) }
        @{ Value = New-Object -TypeName Diagnostics.Process }
    ) {
        Verify-NotNull $Value
        Is-Collection -Value $Value | Verify-False
    }
}
