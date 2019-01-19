function f () { "real" }
Describe "d" {

    BeforeAll () {}

    It "i" {
        Mock f { "mock" }
        f | Should -Be "mock"
    }

    It "j" {
        f | Should -Be "real"
    }
}
