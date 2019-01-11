$global:ValidatorRoot = Split-Path $MyInvocation.MyCommand.Path

BeforeEachFeature {
    if ($GherkinOrderTests) {
        Add-Content -Path $global:GherkinOrderTests -Value "BeforeEachFeature"
    }
    New-Module -Name ValidatorTest {
        . $global:ValidatorRoot\Validator.ps1 -Verbose
    } | Import-Module -Global
}

AfterEachFeature {
    if ($GherkinOrderTests) {
        Add-Content -Path $global:GherkinOrderTests -Value "AfterEachFeature"
    }
    Remove-Module ValidatorTest
}

BeforeEachScenario {
    if ($GherkinOrderTests) {
        Add-Content -Path $global:GherkinOrderTests -Value "BeforeEachScenario"
    }
}

AfterEachScenario {
    if ($GherkinOrderTests) {
        Add-Content -Path $global:GherkinOrderTests -Value "AfterEachScenario"
    }
}

Given 'MyValidator is mocked to return True' {
    Mock MyValidator -Module ValidatorTest -MockWith { return $true }
}

When 'Someone calls something that uses MyValidator' {
    if ($GherkinOrderTests) {
        Add-Content -Path $global:GherkinOrderTests -Value "Scenario One"
    }
    Invoke-SomethingThatUsesMyValidator "false"
}

Then 'MyValidator gets called once' {
    Assert-MockCalled -Module ValidatorTest MyValidator 1
}

When 'MyValidator is called with (?<word>\w+)' {
    param($word)
    if ($GherkinOrderTests) {
        Add-Content -Path $global:GherkinOrderTests -Value "Scenario Two"
    }
    $Validation = MyValidator $word
}

Then 'MyValidator should return (?<expected>\w+)' {
    param($expected)
    $expected = $expected -eq "true"
    $Validation | Should -Be $expected
}
