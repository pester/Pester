Set-StrictMode -Version Latest

InPesterModuleScope {
    Describe "Ensure-ExpectedIsNotCollection" {
        It "Given a collection it throws ArgumentException" {
            $err = { Ensure-ExpectedIsNotCollection -InputObject @() } | Verify-Throw
            $err.Exception | Verify-Type ([ArgumentException])
        }

        It "Given a collection it throws correct message" {
            $err = { Ensure-ExpectedIsNotCollection -InputObject @() } | Verify-Throw
            $err.Exception.Message | Verify-Equal 'You provided a collection to the -Expected parameter. Using a collection on the -Expected side is not allowed by this assertion, because it leads to unexpected behavior. Please use Should-Any, Should-All or some other specialized collection assertion.'
        }


        It "Given a value it passes it to output when it is not a collection" {
            Ensure-ExpectedIsNotCollection -InputObject 'a' | Verify-Equal 'a'
        }
    }
}
