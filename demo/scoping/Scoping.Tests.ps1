$v = $null
Describe "d" { 
    $v = "describe"
    BeforeAll {
        Write-Host "in before all v is: $v"
        $v = "before all"
    }

    BeforeEach {
        Write-Host "in before each v is: $v"
        $v = "before each"
    }

    It "i" { 
        Write-Host "in it v is: $v"
        $v = "it"
    }

    AfterEach {
        Write-Host "in after each v is: $v"
        $v = "after each"
    }

    AfterAll { 
        Write-Host "in after all v is: $v"
        $v = "after all"
    }
    Write-Host "in describe v is: $v"
}