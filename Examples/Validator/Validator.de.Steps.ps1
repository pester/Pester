$global:ValidatorRoot = Split-Path $MyInvocation.MyCommand.Path

BeforeEachFeature {
    New-Module -Name ValidatorTestDe {
        . $global:ValidatorRoot\ValidatorDe.ps1 -Verbose
    } | Import-Module -Global
}

AfterEachFeature {
    Remove-Module ValidatorTestDe
}

Given 'MeinValidator gibt vor, True zurückzugeben' {
    Mock MeinValidator -Module ValidatorTestDe -MockWith { return $true }
}

When 'jemand etwas aufruft, das MeinValidator benutzt' {
    Invoke-SomethingThatUsesMeinValidator "false"
}

Then 'wurde MeinValidator einmal aufgerufen' {
    Assert-MockCalled -Module ValidatorTestDe MeinValidator 1
}

When 'MeinValidator mit (?<word>\w+) aufgerufen wird' {
    param($word)
    $Validation = MeinValidator $word
}

Then 'sollte MeinValidator (?<expected>\w+) zurückgeben' {
    param($expected)
    $expected = $expected -eq "true"
    $Validation | Should -Be $expected
}
