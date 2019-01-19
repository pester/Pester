Describe "d" { 
    Write-Host Running Describe

    BeforeAll {
        Write-Host Running BeforeAll
    }

    It "i" { 
        Write-Host Running It
    }

    AfterAll { 
        Write-Host Running AfterAll
    }
    Write-Host Leaving Describe
}