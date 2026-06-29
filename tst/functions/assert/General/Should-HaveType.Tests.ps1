Set-StrictMode -Version Latest

Describe "Should-HaveType" {
    It "Given value of expected type it passes" {
        1 | Should-HaveType ([int])
    }

    It "Given an object of different type it fails" {
        { 1 | Should-HaveType ([string]) } | Verify-AssertionFailed
    }

    It "Can be called with positional parameters" {
        { Should-HaveType ([string]) 1 } | Verify-AssertionFailed
    }

    It "Given a collection passed by -Actual it checks the collection type" -ForEach @(
        @{ Value = [string[]]('a', 'b') }
        @{ Value = [string[]]('a') }
    ) {
        Should-HaveType -Actual $Value -Expected ([string[]])
    }
}

Describe "Should-HaveType input hint" {
    It "Hints that a piped collection was unwrapped, so the type was lost" -ForEach @(
        # The pipeline unwraps a multi-item collection into [object[]] and a one-item collection
        # into a scalar, so in both cases it no longer looks like the original [string[]]. See #2801.
        @{ Value = [string[]]('a', 'b') }
        @{ Value = [string[]]('a') }
    ) {
        $err = { $Value | Should-HaveType ([string[]]) } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Like '*Hint: You piped a *into a type assertion*unwrapped when it goes through the pipeline*pass it as the -Actual argument*'
    }

    It "Names the original collection type in the hint" {
        $value = [int[]](1, 2, 3)
        $err = { $value | Should-HaveType ([string[]]) } | Verify-AssertionFailed
        $err.Exception.Message.Contains('You piped a [int[]] into a type assertion') | Verify-True
    }

    It "Does not hint when a scalar of the wrong type is piped" {
        $err = { 1 | Should-HaveType ([string]) } | Verify-AssertionFailed
        ($err.Exception.Message -notlike '*Hint:*') | Verify-True
    }

    It "Does not hint when a collection is passed by -Actual" {
        $value = [string[]]('a', 'b')
        $err = { Should-HaveType -Actual $value -Expected ([int[]]) } | Verify-AssertionFailed
        ($err.Exception.Message -notlike '*Hint:*') | Verify-True
    }
}
