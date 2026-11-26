Set-StrictMode -Version Latest

InPesterModuleScope {
    Describe "Get-AssertionGotcha" {
        # Get-AssertionGotcha is the single home for the "you piped the wrong shape into me" hints.
        # It is only ever called from an assertion's failure branch and never changes pass/fail. These
        # tests drive it through the *same* input-collection machinery the real assertions use: two
        # fake assertions, one that unrolls the pipeline (single-value / type assertions such as
        # Should-Be and Should-HaveType) and one that does not (collection assertions such as
        # Should-BeCollection and Should-All). Driving it this way means the pipeline-recovery trick
        # sees realistic invocation info -- in particular whether the caller unrolled its input.
        BeforeAll {
            function Invoke-SingleValueAssertion {
                # Mirrors how Should-Be / Should-HaveType collect input: the pipeline is unrolled, so a
                # piped collection reaches the assertion already unwrapped to a scalar or [Object[]].
                [CmdletBinding()]
                param(
                    [Parameter(ValueFromPipeline)] $Actual,
                    [Parameter(Mandatory)][ValidateSet('Scalar', 'ExactType')][string] $Expecting
                )
                $collected = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput -UnrollInput
                Get-AssertionGotcha -Cmdlet $PSCmdlet -Buffer $local:Input -CollectedActual $collected.Actual -IsPipelineInput $collected.IsPipelineInput -Expecting $Expecting
            }

            function Invoke-CollectionAssertion {
                # Mirrors how Should-BeCollection / Should-All collect input: the pipeline is kept as a
                # collection, so only a non-collection left-hand side is a surprise.
                [CmdletBinding()]
                param(
                    [Parameter(ValueFromPipeline)] $Actual,
                    [Parameter(Mandatory)][ValidateSet('Collection', 'CollectionItems')][string] $Expecting
                )
                $collected = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput
                Get-AssertionGotcha -Cmdlet $PSCmdlet -Buffer $local:Input -CollectedActual $collected.Actual -IsPipelineInput $collected.IsPipelineInput -Expecting $Expecting
            }

            # The closing advice is constant per family; kept here so the wording lives in one place.
            $scalarAdvice = 'To assert on a collection use Should-BeCollection or Should-BeEquivalent; to assert on a single value pass it as the -Actual argument instead of piping it, e.g. -Actual $value.'
            $typeAdvice = 'To assert the type of a collection, pass it as the -Actual argument instead of piping it, e.g. -Actual $value.'
        }

        Context "Expecting Scalar - a single-value assertion (e.g. Should-Be) inspects the unwrapped value" {
            # The Scalar hint is about a collection being *collapsed and inspected as one value*. It
            # does not care whether the type changed, so even an [Object[]] that stays an [Object[]] is
            # worth pointing out -- contrast with ExactType below.
            It "hints that a single-item <Piped> was unwrapped to its one <Seen> element" -ForEach @(
                @{ Value = @(1); Piped = '[Object[]]'; Seen = '[int]' }
                @{ Value = [int[]]@(1); Piped = '[int[]]'; Seen = '[int]' }
                @{ Value = @($null); Piped = '[Object[]]'; Seen = '[null]' }
            ) {
                $hint = $Value | Invoke-SingleValueAssertion -Expecting Scalar
                $hint | Verify-Equal "You piped a $Piped into a single-value assertion, but the pipeline unwraps a single-item collection to its one element, so the assertion inspected that single $Seen instead of the collection. $scalarAdvice"
            }

            It "hints that a multi-item <Piped> was re-collected into a single <Seen>" -ForEach @(
                @{ Value = @(1, 2); Piped = '[Object[]]'; Seen = '[Object[]]' }
                @{ Value = [int[]]@(1, 2); Piped = '[int[]]'; Seen = '[Object[]]' }
                @{ Value = @($null, $null); Piped = '[Object[]]'; Seen = '[Object[]]' }
            ) {
                $hint = $Value | Invoke-SingleValueAssertion -Expecting Scalar
                $hint | Verify-Equal "You piped a $Piped into a single-value assertion, but the pipeline streams a multi-item collection and re-collects it into a single $Seen, so the whole collection was inspected as one value. $scalarAdvice"
            }

            It "stays quiet for <Description>, which the pipeline does not collapse into a different value" -ForEach @(
                @{ Description = 'a genuine scalar'; Value = 5 }
                @{ Description = 'a piped $null'; Value = $null }
                @{ Description = 'a single dictionary'; Value = @{ a = 1 } }
                @{ Description = 'an empty array'; Value = @() }
                @{ Description = 'an empty typed array'; Value = [string[]]@() }
            ) {
                $hint = $Value | Invoke-SingleValueAssertion -Expecting Scalar
                $hint | Verify-Null
            }

            It "stays quiet for a lazily streamed range, which has no nameable container" {
                $hint = 1..3 | Invoke-SingleValueAssertion -Expecting Scalar
                $hint | Verify-Null
            }

            It "stays quiet for <Description> passed by -Actual instead of piped" -ForEach @(
                @{ Description = 'a collection'; Value = @(1, 2) }
                @{ Description = 'a scalar'; Value = 5 }
            ) {
                $hint = Invoke-SingleValueAssertion -Actual $Value -Expecting Scalar
                $hint | Verify-Null
            }
        }

        Context "Expecting ExactType - a type assertion (e.g. Should-HaveType) checks the unwrapped value's type" {
            # The ExactType hint is about the *type being lost* to unwrapping. So unlike Scalar it has a
            # "the observable type did not change" guard: a piped [Object[]] re-collected straight back
            # into an [Object[]] is a genuine type comparison, not a gotcha.
            It "hints that a single-item <Piped> was unwrapped to a single <Seen>" -ForEach @(
                @{ Value = @(1); Piped = '[Object[]]'; Seen = '[int]' }
                @{ Value = [int[]]@(1); Piped = '[int[]]'; Seen = '[int]' }
                @{ Value = @($null); Piped = '[Object[]]'; Seen = '[null]' }
            ) {
                $hint = $Value | Invoke-SingleValueAssertion -Expecting ExactType
                $hint | Verify-Equal "You piped a $Piped into a type assertion, but the pipeline unwraps a single-item collection to its one element, so the assertion saw a single $Seen, not the $Piped you piped. $typeAdvice"
            }

            It "hints that a multi-item <Piped> was re-collected as <Seen> when that changes the type" -ForEach @(
                @{ Value = [int[]]@(1, 2); Piped = '[int[]]'; Seen = '[Object[]]' }
                @{ Value = [string[]]('a', 'b'); Piped = '[string[]]'; Seen = '[Object[]]' }
            ) {
                $hint = $Value | Invoke-SingleValueAssertion -Expecting ExactType
                $hint | Verify-Equal "You piped a $Piped into a type assertion, but the pipeline streams a multi-item collection and re-collects it as $Seen, so the assertion saw $Seen, not the $Piped you piped. $typeAdvice"
            }

            It "stays quiet for <Description>, where unwrapping did not change the observable type" -ForEach @(
                # A multi-item [Object[]] streams and re-collects straight back into an [Object[]], so
                # the type the assertion sees is the very type that was piped -- nothing was lost.
                @{ Description = 'a multi-item [Object[]] of values'; Value = @(1, 2) }
                @{ Description = 'a multi-item [Object[]] of $null'; Value = @($null, $null) }
            ) {
                $hint = $Value | Invoke-SingleValueAssertion -Expecting ExactType
                $hint | Verify-Null
            }

            It "stays quiet for <Description>, where no collection was unwrapped" -ForEach @(
                @{ Description = 'a genuine scalar'; Value = 5 }
                @{ Description = 'a piped $null'; Value = $null }
                @{ Description = 'a single dictionary'; Value = @{ a = 1 } }
                @{ Description = 'an empty array'; Value = @() }
                @{ Description = 'an empty typed array'; Value = [string[]]@() }
            ) {
                $hint = $Value | Invoke-SingleValueAssertion -Expecting ExactType
                $hint | Verify-Null
            }

            It "stays quiet when a collection keeps its real type by being passed by -Actual" {
                $hint = Invoke-SingleValueAssertion -Actual ([int[]]@(1, 2)) -Expecting ExactType
                $hint | Verify-Null
            }
        }

        Context "Expecting Collection - a whole-collection assertion (e.g. Should-BeCollection) compares the input as one collection" {
            # Here a lone scalar, a $null, or a dictionary is the wrong container, so each is worth a
            # hint; a genuine collection is exactly what the assertion wants and stays quiet.
            It "hints a piped <Description>, which is treated as a single item" -ForEach @(
                @{ Description = 'scalar'; Value = 5; Hint = 'You piped a single [int] into a collection assertion. It is treated as a single item. To assert on a one-item collection wrap it as ,$actual, or use Should-Be for a scalar value.' }
                @{ Description = '$null'; Value = $null; Hint = 'You piped $null into a collection assertion. It is treated as a single $null item, not an empty collection. Use @() to represent an empty collection.' }
                @{ Description = 'dictionary'; Value = @{ a = 1 }; Hint = 'You piped a single [hashtable] into a collection assertion. PowerShell treats a dictionary as a single object, not a collection. To assert on it as a hashtable use Should-BeHashtable, or compare its contents with Should-BeEquivalent.' }
            ) {
                $hint = $Value | Invoke-CollectionAssertion -Expecting Collection
                $hint | Verify-Equal $Hint
            }

            It "hints a <Description> passed by -Actual, which is not a collection" -ForEach @(
                @{ Description = 'scalar'; Value = 5; Hint = '-Actual is a single [int], which is not a collection. It is treated as a single item. To assert on a one-item collection wrap it as ,$actual, or use Should-Be for a scalar value.' }
                @{ Description = '$null'; Value = $null; Hint = '-Actual is $null, which is not a collection. It is treated as a single $null item, not an empty collection. Use @() to represent an empty collection.' }
                @{ Description = 'dictionary'; Value = @{ a = 1 }; Hint = '-Actual is a single [hashtable], which is not a collection. PowerShell treats a dictionary as a single object, not a collection. To assert on it as a hashtable use Should-BeHashtable, or compare its contents with Should-BeEquivalent.' }
            ) {
                $hint = Invoke-CollectionAssertion -Actual $Value -Expecting Collection
                $hint | Verify-Equal $Hint
            }

            It "stays quiet for a genuine collection, <Description>" -ForEach @(
                @{ Description = 'piped'; Piped = $true }
                @{ Description = 'by -Actual'; Piped = $false }
            ) {
                $hint = if ($Piped) { @(1, 2) | Invoke-CollectionAssertion -Expecting Collection } else { Invoke-CollectionAssertion -Actual @(1, 2) -Expecting Collection }
                $hint | Verify-Null
            }

            It "stays quiet for a lazily streamed range" {
                $hint = 1..3 | Invoke-CollectionAssertion -Expecting Collection
                $hint | Verify-Null
            }
        }

        Context "Expecting CollectionItems - an item-wise assertion (e.g. Should-All) iterates the input" {
            # A lone scalar or $null is a perfectly valid one-item collection to iterate, so only a
            # dictionary -- which PowerShell silently passes through as a single, non-iterated object --
            # is a genuine gotcha here.
            It "hints a piped dictionary, which PowerShell passes through as a single un-iterated item" {
                $hint = @{ a = 1 } | Invoke-CollectionAssertion -Expecting CollectionItems
                $hint | Verify-Equal 'You piped a single [hashtable] into a collection assertion. PowerShell treats a dictionary as a single object, so it is passed through as one item instead of being iterated. Enumerate it first, e.g. with $actual.GetEnumerator(), or its .Keys or .Values, or assert on it directly with Should-BeHashtable.'
            }

            It "hints a dictionary passed by -Actual" {
                $hint = Invoke-CollectionAssertion -Actual @{ a = 1 } -Expecting CollectionItems
                $hint | Verify-Equal '-Actual is a single [hashtable], which is not a collection. PowerShell treats a dictionary as a single object, so it is passed through as one item instead of being iterated. Enumerate it first, e.g. with $actual.GetEnumerator(), or its .Keys or .Values, or assert on it directly with Should-BeHashtable.'
            }

            It "stays quiet for <Description>, a valid item or collection to iterate" -ForEach @(
                @{ Description = 'a piped scalar'; Value = 5 }
                @{ Description = 'a piped $null'; Value = $null }
                @{ Description = 'a piped collection'; Value = @(1, 2) }
            ) {
                $hint = $Value | Invoke-CollectionAssertion -Expecting CollectionItems
                $hint | Verify-Null
            }

            It "stays quiet for <Description> passed by -Actual" -ForEach @(
                @{ Description = 'a scalar'; Value = 5 }
                @{ Description = 'a collection'; Value = @(1, 2) }
                @{ Description = '$null'; Value = $null }
            ) {
                $hint = Invoke-CollectionAssertion -Actual $Value -Expecting CollectionItems
                $hint | Verify-Null
            }
        }
    }
}

Describe "Assertions surface the pipeline-unwrap hint" {
    # The block above proves Get-AssertionGotcha produces the right wording for every input shape.
    # This block proves the real, public assertions actually wire it up: each one is made to fail by
    # piping a collection into it, and we check that the failure message carries the matching hint.
    # That is the "make sure we use them in the right places, with the correct invocation info" half
    # of the contract -- if an assertion forgot to call Get-AssertionGotcha, or called it without the
    # pipeline info, these would go quiet. We only match a fragment here on purpose; the exact wording
    # is asserted once, centrally, in the Get-AssertionGotcha tests above.

    It "<Assertion> appends the multi-item hint when a multi-item collection is piped" -ForEach @(
        @{ Assertion = 'Should-Be'; Fail = { @(1, 2) | Should-Be 1 } }
        @{ Assertion = 'Should-BeGreaterThan'; Fail = { @(1, 2) | Should-BeGreaterThan 1 } }
        @{ Assertion = 'Should-BeGreaterThanOrEqual'; Fail = { @(1, 2) | Should-BeGreaterThanOrEqual 1 } }
        @{ Assertion = 'Should-BeLessThan'; Fail = { @(1, 2) | Should-BeLessThan 1 } }
        @{ Assertion = 'Should-BeLessThanOrEqual'; Fail = { @(1, 2) | Should-BeLessThanOrEqual 1 } }
        @{ Assertion = 'Should-BeSame'; Fail = { @(1, 2) | Should-BeSame ([PSCustomObject]@{}) } }
        @{ Assertion = 'Should-BeNull'; Fail = { @(1, 2) | Should-BeNull } }
        @{ Assertion = 'Should-BeString'; Fail = { @(1, 2) | Should-BeString 'x' } }
        @{ Assertion = 'Should-BeEmptyString'; Fail = { @(1, 2) | Should-BeEmptyString } }
        @{ Assertion = 'Should-BeHashtable'; Fail = { @(1, 2) | Should-BeHashtable } }
        @{ Assertion = 'Should-NotHaveType'; Fail = { [int[]](1, 2) | Should-NotHaveType ([object[]]) } }
    ) {
        $err = $Fail | Verify-AssertionFailed
        $err.Exception.Message | Verify-Like '*Hint: You piped a*streams a multi-item collection and re-collects it*'
    }

    It "<Assertion> appends the single-item hint when a single-item collection is piped" -ForEach @(
        @{ Assertion = 'Should-NotBe'; Fail = { @(1) | Should-NotBe 1 } }
        @{ Assertion = 'Should-NotBeNull'; Fail = { @($null) | Should-NotBeNull } }
        @{ Assertion = 'Should-NotBeSame'; Fail = { $o = [PSCustomObject]@{}; @($o) | Should-NotBeSame $o } }
        @{ Assertion = 'Should-BeTrue'; Fail = { @($false) | Should-BeTrue } }
        @{ Assertion = 'Should-BeFalse'; Fail = { @($true) | Should-BeFalse } }
        @{ Assertion = 'Should-BeTruthy'; Fail = { @(0) | Should-BeTruthy } }
        @{ Assertion = 'Should-BeFalsy'; Fail = { @(1) | Should-BeFalsy } }
        @{ Assertion = 'Should-NotBeEmptyString'; Fail = { @('') | Should-NotBeEmptyString } }
        @{ Assertion = 'Should-NotBeWhiteSpaceString'; Fail = { @('  ') | Should-NotBeWhiteSpaceString } }
    ) {
        $err = $Fail | Verify-AssertionFailed
        $err.Exception.Message | Verify-Like '*Hint: You piped a*unwraps a single-item collection to its one element*'
    }
}
