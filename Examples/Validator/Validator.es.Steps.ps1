$global:ValidatorRoot = Split-Path $MyInvocation.MyCommand.Path

BeforeEachFeature {
    New-Module -Name ValidatorTestEs {
        . $global:ValidatorRoot\ValidatorEs.ps1 -Verbose
    } | Import-Module -Global
}

AfterEachFeature {
    Remove-Module ValidatorTestEs
}

Given 'MiValidator finge devolver True' {
    Mock MiValidator -Module ValidatorTestEs -MockWith { return $true }
}

When 'alguien llama algo que usa MiValidator' {
    Invoke-SomethingThatUsesMiValidator "false"
}

Then 'MiValidator fue llamado una vez' {
    Assert-MockCalled -Module ValidatorTestEs MiValidator 1
}

When 'MiValidator se llama con (?<word>\w+)' {
    param($word)
    $Validation = MiValidator $word
}

Then 'MiValidator debería devolver a (?<expected>\w+)' {
    param($expected)
    $expected = $expected -eq "true"
    $Validation | Should -Be $expected
}
