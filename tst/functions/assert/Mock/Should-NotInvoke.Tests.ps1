Set-StrictMode -Version Latest

Describe "Should-Invoke" {
    It "Passes when Mock was not invoked" {
        function f () { }
        Mock f

        Should-Invoke f -Times 1 -Exactly
    }

    It "Fails when Mock was invoked" {
        function f () { }
        Mock f

        f

        { Should-Invoke f -Times 1 -Exactly } | Verify-Throw
    }
}

Describe "Should-NotInvoke -Verifiable" {
    It "Passes when no verifiable mocks were invoked" {
        function f () { }
        Mock f -Verifiable

        Should-NotInvoke -Verifiable
    }

    It "Fails when verifiable mocks were invoked" {
        function f () { }
        Mock f -Verifiable

        f

        { Should-NotInvoke -Verifiable } | Verify-Throw
    }
}
