New-Module -Name ValidatorTest {
    . $PSScriptRoot\Validator.ps1 -Verbose
} | Import-Module -Scope Global

Given 'MyValidator is mocked to return True' {
    Mock MyValidator -Module ValidatorTest -MockWith { return $true }
}

When 'Someone calls something that uses MyValidator' {
    Invoke-SomethingThatUsesMyValidator "false"
}

Then 'MyValidator gets called once' {
    Assert-MockCalled -Module ValidatorTest MyValidator 1
}

Given 'MyValidator' {}

When 'MyValidator is called with (?<word>\w+)' {
    param($word)
    $script:result = MyValidator $word
}

Then 'MyValidator should return (?<expected>\w+)' {
    param($expected)
    $expected = $expected -eq "true"
    $result | Should Be $expected
}
