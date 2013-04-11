
function MyValidator($thing_to_validate) {
    return $thing_to_validate.StartsWith("s")
}

function Invoke-SomethingThatUsesMyValidator {
    param(
        [ValidateScript({MyValidator $_})]
        $some_param
    )
}

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
        $result | Should Be $true
    }

    It "does not pass a param that does not start with S" {
        $result = MyValidator "bummer"
        $result | Should Be $false
    }
}

