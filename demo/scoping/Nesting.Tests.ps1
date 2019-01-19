cls
Describe "d" { 
    Describe "d.d" { 
        It "i.i" { $true }
    }

    BeforeAll { 
        Write-Host "before all" 
        $a = "parent before all"
    }

    It "i" { Write-Host "first it" }

    Describe "d.d" { 
        It "i.i" { $true }
    }

    It "i" { Write-Host "last it" }

    Describe "d.d" { 
        It "i.i" { Write-Host "in nested it a is: $a" }
    }

    AfterAll { 
        Write-Host "after all"
        $a = "parent after all"
    }
}