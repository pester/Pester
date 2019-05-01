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

    AfterAll {
        Should -Invoke f -Exactly 2
    }
}
