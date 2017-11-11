$scriptRoot = Split-Path $MyInvocation.MyCommand.Path
. $scriptRoot\Validator.ps1 -Verbose

Describe "Testing a validator" {

    It "calls MyValidator" {
        Mock MyValidator -MockWith { return $true }
        Invoke-SomethingThatUsesMyValidator "test"
        $was_called_once = 1
        Assert-MockCalled MyValidator $was_called_once
    }

}

Describe "MyValidator" {

    It "passes things that start with the letter S" {
        $result = MyValidator "summer"
        $result | Should -Be $true
    }

    It "does not pass a param that does not start with S" {
        $result = MyValidator "bummer"
        $result | Should -Be $false
    }
}

