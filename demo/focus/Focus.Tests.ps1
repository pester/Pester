BeforeAll {
    function Get-Hello {
        "Hello"
    }
}

Describe "Get-Hello" {
    It "Gives Hello" {
        Get-Hello | Should -Be "Hello"
    }

    It "Has no spaces around hello" -Focus {
        $hello = Get-Hello
        $hello.Trim() | Should -Be $hello
    }
}
