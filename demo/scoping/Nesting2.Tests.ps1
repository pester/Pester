Describe "d" { 
    Describe "d.d" { 
        It "i.i" { $true }
    }

    BeforeEach { 
        Write-Host "before each" 
    }

    It "i" { Write-Host "first it" }

    Describe "d.d" { 
        It "i.i" { $true }
    }

    It "i" { Write-Host "last it" }

    Describe "d.d" { 
        It "i.i" { $true }
    }

    AfterAll { 
        Write-Host "after all"
        $a = "parent after all"
    }
}