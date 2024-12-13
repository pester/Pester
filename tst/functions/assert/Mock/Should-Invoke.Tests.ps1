Set-StrictMode -Version Latest

Describe "Should-Invoke" {
    It "Passes when Mock was invoked once" {
        function f () { }
        Mock f

        f

        Should-Invoke f -Times 1 -Exactly
    }
}

Describe "Should-Invoke -Verifiable" {
    It "Passes when all verifiable mocks were invoked" {
        function f () { }
        Mock f -Verifiable

        f

        Should-Invoke -Verifiable
    }
}
