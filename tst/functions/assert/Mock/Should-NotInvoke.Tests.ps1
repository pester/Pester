Set-StrictMode -Version Latest

Describe "Should-Invoke" {
    It "Passes when Mock was not invoked" {
        function f () { }
        Mock f

        Should-Invoke f -Times 1 -Exactly
    }
}

Describe "Should-Invoke -Verifiable" {
    It "Passes when no verifiable mocks were invoked" {
        function f () { }
        Mock f -Verifiable

        Should-Invoke -Verifiable
    }
}
