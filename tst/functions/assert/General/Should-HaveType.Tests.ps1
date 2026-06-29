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
    It "Hints how the pipeline unwrapped a piped <Description>" -ForEach @(
        # The two cases from #2801. The PipelineSource trick recovers the *original* piped [string[]]
        # (its type and item count) even though the pipeline already unwrapped it, so each hint names
        # the real type and explains exactly what happened:
        #   - a multi-item array is streamed and re-collected into [Object[]];
        #   - a single-item array is unwrapped to its one element, a scalar [string].
        @{
            Description = 'multi-item array'
            Value       = [string[]]('a', 'b')
            Unwrapped   = '[Object[]]'
            Hint        = 'Hint: You piped a [string[]] into a type assertion, but the pipeline streams a multi-item collection and re-collects it as [Object[]], so the assertion saw [Object[]], not the [string[]] you piped. To assert the type of a collection, pass it as the -Actual argument instead of piping it, e.g. -Actual $value.'
        }
        @{
            Description = 'single-item array'
            Value       = [string[]]('a')
            Unwrapped   = '[string]'
            Hint        = 'Hint: You piped a [string[]] into a type assertion, but the pipeline unwraps a single-item collection to its one element, so the assertion saw a single [string], not the [string[]] you piped. To assert the type of a collection, pass it as the -Actual argument instead of piping it, e.g. -Actual $value.'
        }
    ) {
        $err = { $Value | Should-HaveType ([string[]]) } | Verify-AssertionFailed
        $message = $err.Exception.Message

        # The failure line shows the unwrapped type the assertion actually saw ...
        $message.StartsWith("Expected value to have type [string[]], but got $Unwrapped ") | Verify-True

        # ... and the hint recovers and names the *original* piped type, then explains the unwrapping.
        ($message -split "`n`n", 2)[-1] | Verify-Equal $Hint
    }

    It "Names the piped collection's element type in the hint, not a hard-coded one" {
        # Piping [int[]] proves the recovered type is taken from the real input, not hard-coded.
        $err = { [int[]](1, 2, 3) | Should-HaveType ([string[]]) } | Verify-AssertionFailed
        ($err.Exception.Message -split "`n`n", 2)[-1] | Verify-Equal 'Hint: You piped a [int[]] into a type assertion, but the pipeline streams a multi-item collection and re-collects it as [Object[]], so the assertion saw [Object[]], not the [int[]] you piped. To assert the type of a collection, pass it as the -Actual argument instead of piping it, e.g. -Actual $value.'
    }

    It "Hints a piped single-item collection even when its one element is `$null" {
        # @($null) is a one-item [Object[]]; the pipeline still unwraps it to that single $null
        # element, so the hint names the real piped [Object[]] and the [null] the assertion saw.
        $err = { @($null) | Should-HaveType ([string]) } | Verify-AssertionFailed
        ($err.Exception.Message -split "`n`n", 2)[-1] | Verify-Equal 'Hint: You piped a [Object[]] into a type assertion, but the pipeline unwraps a single-item collection to its one element, so the assertion saw a single [null], not the [Object[]] you piped. To assert the type of a collection, pass it as the -Actual argument instead of piping it, e.g. -Actual $value.'
    }

    It "Does not hint when the pipeline did not change the observable type of a piped <Description>" -ForEach @(
        # Nothing is lost to unwrapping in these cases, so a hint would be misleading rather than
        # helpful:
        #   - an empty array sends no items through the pipeline at all;
        #   - a multi-item [Object[]] is streamed and re-collected straight back into an [Object[]],
        #     so the type the assertion sees is the very type that was piped.
        @{ Description = 'empty array'; Value = @() }
        @{ Description = 'empty typed array'; Value = [string[]]@() }
        @{ Description = 'multi-item [Object[]] of $null'; Value = @($null, $null) }
        @{ Description = 'multi-item [Object[]] of values'; Value = @(1, 2) }
    ) {
        $err = { $Value | Should-HaveType ([hashtable]) } | Verify-AssertionFailed
        ($err.Exception.Message -notlike '*Hint:*') | Verify-True
    }

    It "Tells a genuinely piped scalar apart from an unwrapped single-item collection" {
        # Both '1 | ...' and a piped [string[]]('a') reach the assertion as a single scalar, but only
        # the collection was unwrapped. The PipelineSource trick recovers the original left-hand side,
        # so a real scalar (it keeps its type) gets no hint while a single-item collection does. #2801.
        $err = { 1 | Should-HaveType ([string]) } | Verify-AssertionFailed
        ($err.Exception.Message -notlike '*Hint:*') | Verify-True
    }

    It "Does not hint when a collection is passed by -Actual" {
        $value = [string[]]('a', 'b')
        $err = { Should-HaveType -Actual $value -Expected ([int[]]) } | Verify-AssertionFailed
        ($err.Exception.Message -notlike '*Hint:*') | Verify-True
    }
}
