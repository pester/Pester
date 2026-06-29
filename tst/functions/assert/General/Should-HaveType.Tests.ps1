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
    It "Hints that a piped <Description> was unwrapped to <Unwrapped>, losing its [string[]] type" -ForEach @(
        # Piping unwraps the collection before the assertion sees it: a multi-item collection becomes
        # [Object[]] and a one-item collection becomes a scalar. Either way the original [string[]] is
        # gone, so the assertion fails and the hint is shown. See #2801.
        @{ Description = 'multi-item collection'; Value = [string[]]('a', 'b'); Unwrapped = '[Object[]]' }
        @{ Description = 'one-item collection';   Value = [string[]]('a');      Unwrapped = '[string]' }
    ) {
        $err = { $Value | Should-HaveType ([string[]]) } | Verify-AssertionFailed
        $message = $err.Exception.Message

        # The leading line reports the unwrapped value's type, proving the collection lost its type.
        # This is the part that differs between the two cases; the trailing value text is left
        # unasserted so the test does not break on value-formatting changes.
        $message.StartsWith("Expected value to have type [string[]], but got $Unwrapped ") | Verify-True

        # Everything after the blank line is the hint, identical for both cases because it reports the
        # *original* piped type. Asserted in full so the exact message a user sees is visible here.
        $hint = ($message -split "`n`n", 2)[-1]
        $hint | Verify-Equal 'Hint: You piped a [string[]] into a type assertion. A collection is unwrapped when it goes through the pipeline, so the assertion no longer sees it as [string[]]. To assert the type of a collection, pass it as the -Actual argument instead of piping it, e.g. -Actual $value.'
    }

    It "Names the piped collection's element type in the hint, not a hard-coded one" {
        # Same hint shape, but piping [int[]] proves the element type is taken from the real input.
        $err = { [int[]](1, 2, 3) | Should-HaveType ([string[]]) } | Verify-AssertionFailed
        $hint = ($err.Exception.Message -split "`n`n", 2)[-1]
        $hint | Verify-Equal 'Hint: You piped a [int[]] into a type assertion. A collection is unwrapped when it goes through the pipeline, so the assertion no longer sees it as [int[]]. To assert the type of a collection, pass it as the -Actual argument instead of piping it, e.g. -Actual $value.'
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
