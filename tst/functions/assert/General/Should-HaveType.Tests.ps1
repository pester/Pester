Set-StrictMode -Version Latest

Describe "Should-HaveType" {
    It "Given value of expected type it passes" {
        1 | Should-HaveType ([int])
    }

    It "Given an object of different type it fails" {
        { 1 | Should-HaveType ([string]) } | Verify-AssertionFailed
    }

    It "Given a value with a matching custom PSTypeName it passes" {
        $actual = [PSCustomObject]@{ PSTypeName = 'MyApp.Person'; Name = 'Jane' }
        $actual | Should-HaveType 'MyApp.Person'
    }

    It "Given a value without the expected custom PSTypeName it fails" {
        $actual = [PSCustomObject]@{ PSTypeName = 'MyApp.Person'; Name = 'Jane' }
        $err = { $actual | Should-HaveType 'MyApp.Animal' } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Like "*Expected value to have type or PSTypeName*MyApp.Animal*"
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

    # Regression test for https://github.com/pester/Pester/issues/2828
    # Formatting a self-referential actual value for the failure message used to recurse until
    # PowerShell threw "The script failed due to call depth overflow", hiding the real result.
    It "Reports a normal assertion failure for a self-referential value instead of overflowing" {
        $o = [PSCustomObject]@{ Name = 'x' }
        $o | Add-Member -NotePropertyName Self -NotePropertyValue $o

        $err = { Should-HaveType -Actual $o -Expected ([string]) } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Like '*Expected value to have type*'
    }
}

Describe "Should-HaveType input hint" {
    # Should-HaveType is where the pipeline-unwrap hint started (#2801). The exact wording for every
    # input shape is asserted centrally in Get-AssertionGotcha.Tests.ps1; here we only smoke-test that
    # the real assertion wires it up -- it asks for the ExactType hint and passes the pipeline info, so
    # a piped collection is explained while a value passed by -Actual (or a genuine scalar) stays quiet.
    It "Hints how the pipeline unwrapped a piped multi-item collection" {
        $err = { [string[]]('a', 'b') | Should-HaveType ([string[]]) } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Like '*Hint: You piped a*streams a multi-item collection and re-collects it*'
    }

    It "Hints how the pipeline unwrapped a piped single-item collection" {
        $err = { [string[]]('a') | Should-HaveType ([string[]]) } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Like '*Hint: You piped a*unwraps a single-item collection to its one element*'
    }

    It "Does not hint when the pipeline did not change the observable type of a piped collection" {
        # A multi-item [Object[]] is streamed and re-collected straight back into an [Object[]], so the
        # type the assertion sees is the very type that was piped -- nothing was lost to unwrapping.
        $err = { @(1, 2) | Should-HaveType ([hashtable]) } | Verify-AssertionFailed
        ($err.Exception.Message -notlike '*Hint:*') | Verify-True
    }

    It "Tells a genuinely piped scalar apart from an unwrapped single-item collection" {
        # Both '1 | ...' and a piped [string[]]('a') reach the assertion as a single scalar, but only
        # the collection was unwrapped, so a real scalar (it keeps its type) gets no hint. #2801.
        $err = { 1 | Should-HaveType ([string]) } | Verify-AssertionFailed
        ($err.Exception.Message -notlike '*Hint:*') | Verify-True
    }

    It "Does not hint when a collection is passed by -Actual" {
        $value = [string[]]('a', 'b')
        $err = { Should-HaveType -Actual $value -Expected ([int[]]) } | Verify-AssertionFailed
        ($err.Exception.Message -notlike '*Hint:*') | Verify-True
    }
}
