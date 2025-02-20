Set-StrictMode -Version Latest

Describe "Should-Invoke" {
    It "Passes when Mock was invoked once" {
        function f () { }
        Mock f

        f

        Should-Invoke f -Times 1 -Exactly
    }

    It "Fails when mock was invoked 0 times" {
        function f () { }
        Mock f

        { Should-Invoke f -Times 1 -Exactly } | Verify-Throw
    }
}

Describe "Should-Invoke -Verifiable" {
    It "Passes when all verifiable mocks were invoked" {
        function f () { }
        Mock f -Verifiable

        f

        Should-Invoke -Verifiable
    }

    It "Fails when not all verifiable mocks were invoked" {
        function f () { }
        Mock f -Verifiable

        { Should-Invoke -Verifiable } | Verify-Throw
    }
}
