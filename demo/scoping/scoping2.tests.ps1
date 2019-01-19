$v = $null
Describe "d" { 
    $v = "describe"
    BeforeAll {
        Write-Host "in before all v is: $v"
        $v = "before all"
    }

    It "i" { 
        Write-Host "in it v is: $v"
        $v = "it"
    }

        It "i" { 
        Write-Host "in it v is: $v"
        $v = "it"
    }
    AfterAll { 
        Write-Host "in after all v is: $v"
        $v = "after all"
    }
    Write-Host "in describe v is: $v"
}