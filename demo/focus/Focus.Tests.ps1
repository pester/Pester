function Get-Hello {
    "Hello"
}
Describe "Get-Hello" {
    It "Gives Hello" {
        Get-Hello | Should -Be "Hello"
    }

    It -Focus "Has no spaces around hello" {
        $hello = Get-Hello
        $hello.Trim() | Should -Be $hello
    }
}
