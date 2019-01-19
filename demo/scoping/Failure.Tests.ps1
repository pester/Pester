Describe "d" { 
    BeforeAll { throw }
    It "i" { $true }
    It "i" { $true }
}

Describe "d2" { 
    It "i2" { $true }
    It "i2" { $true }
    AfterAll { throw }
}