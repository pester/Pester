function f () { "real" }
Describe "d" {

    BeforeAll {
        Mock f { "mock" }
    }

    It "i" {
        f
        Should -Invoke f -Exactly 1
    }

    It "j" {
        f
        Should -Invoke f -Exactly 1
    }

    It "k" {
        Should -Invoke f -Exactly 2 -Scope Describe
    }
}
