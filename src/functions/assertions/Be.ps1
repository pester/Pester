#Be
function Should-BeAssertion ($ActualValue, $ExpectedValue, [switch] $Negate, [string] $Because) {
    <#
    .SYNOPSIS
    Compares one object with another for equality
    and throws if the two objects are not the same.

    .EXAMPLE
    $actual = "Actual value"
    $actual | Should -Be "actual value"

    This test will pass. -Be is not case sensitive.
    For a case sensitive assertion, see -BeExactly.

    .EXAMPLE
    $actual = "Actual value"
    $actual | Should -Be "not actual value"

    This test will fail, as the two strings are not identical.
    #>
    [bool] $succeeded = ArraysAreEqual $ActualValue $ExpectedValue

    if ($Negate) {
        $succeeded = -not $succeeded
    }

    $failureMessage = ''

    if ($true -eq $succeeded) { return [Pester.ShouldResult]@{Succeeded = $succeeded } }

    if ($Negate) {
        $failureMessage = NotShouldBeFailureMessage -ActualValue $ActualValue -Expected $ExpectedValue -Because $Because
    }
    else {
        $failureMessage = ShouldBeFailureMessage -ActualValue $ActualValue -Expected $ExpectedValue -Because $Because
    }

    return [Pester.ShouldResult] @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
        ExpectResult   = @{
            Actual   = Format-Nicely $ActualValue
            Expected = Format-Nicely $ExpectedValue
            Because  = $Because
        }
    }
}

function ShouldBeFailureMessage($ActualValue, $ExpectedValue, $Because) {
    # This looks odd; it's to unroll single-element arrays so the "-is [string]" expression works properly.
    $ActualValue = $($ActualValue)
    $ExpectedValue = $($ExpectedValue)

    if (-not (($ExpectedValue -is [string]) -and ($ActualValue -is [string]))) {
        return "Expected $(Format-Nicely $ExpectedValue),$(if ($null -ne $Because) { Format-Because $Because }) but got $(Format-Nicely $ActualValue)."
    }
    <#joining the output strings to a single string here, otherwise I get
       Cannot find an overload for "Exception" and the argument count: "4".
       at line: 63 in C:\Users\nohwnd\github\pester\functions\Assertions\Should.ps1

    This is a quickwin solution, doing the join in the Should directly might be better
    way of doing this. But I don't want to mix two problems.
    #>
    (Get-CompareStringMessage -Expected $ExpectedValue -Actual $ActualValue -Because $Because) -join "`n"
}

function NotShouldBeFailureMessage($ActualValue, $ExpectedValue, $Because) {
    return "Expected $(Format-Nicely $ExpectedValue) to be different from the actual value,$(if ($null -ne $Because) { Format-Because $Because }) but got the same value."
}

& $script:SafeCommands['Add-ShouldOperator'] -Name Be `
    -InternalName       Should-BeAssertion `
    -Test               ${function:Should-BeAssertion} `
    -Alias              'EQ' `
    -SupportsArrayInput

Set-ShouldOperatorHelpMessage -OperatorName Be `
    -HelpMessage 'Compares one object with another for equality and throws if the two objects are not the same.'

#BeExactly
function Should-BeAssertionExactly($ActualValue, $ExpectedValue, $Because) {
    <#
    .SYNOPSIS
    Compares one object with another for equality and throws if the
    two objects are not the same. This comparison is case sensitive.

    .EXAMPLE
    $actual = "Actual value"
    $actual | Should -Be "Actual value"

    This test will pass. The two strings are identical.

    .EXAMPLE
    $actual = "Actual value"
    $actual | Should -Be "actual value"

    This test will fail, as the two strings do not match case sensitivity.
    #>
    [bool] $succeeded = ArraysAreEqual $ActualValue $ExpectedValue -CaseSensitive

    if ($Negate) {
        $succeeded = -not $succeeded
    }

    $failureMessage = ''

    if ($true -eq $succeeded) { return [Pester.ShouldResult]@{Succeeded = $succeeded } }

    if ($Negate) {
        $failureMessage = NotShouldBeExactlyFailureMessage -ActualValue $ActualValue -ExpectedValue $ExpectedValue -Because $Because
    }
    else {
        $failureMessage = ShouldBeExactlyFailureMessage -ActualValue $ActualValue -ExpectedValue $ExpectedValue -Because $Because
    }

    return [Pester.ShouldResult] @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
        ExpectResult   = @{
            Actual   = Format-Nicely $ActualValue
            Expected = Format-Nicely $ExpectedValue
            Because  = $Because
        }
    }
}

function ShouldBeExactlyFailureMessage($ActualValue, $ExpectedValue, $Because) {
    # This looks odd; it's to unroll single-element arrays so the "-is [string]" expression works properly.
    $ActualValue = $($ActualValue)
    $ExpectedValue = $($ExpectedValue)

    if (-not (($ExpectedValue -is [string]) -and ($ActualValue -is [string]))) {
        return "Expected exactly $(Format-Nicely $ExpectedValue),$(if ($null -ne $Because) { Format-Because $Because }) but got $(Format-Nicely $ActualValue)."
    }
    <#joining the output strings to a single string here, otherwise I get
       Cannot find an overload for "Exception" and the argument count: "4".
       at line: 63 in C:\Users\nohwnd\github\pester\functions\Assertions\Should.ps1

    This is a quickwin solution, doing the join in the Should directly might be better
    way of doing this. But I don't want to mix two problems.
    #>
    (Get-CompareStringMessage -Expected $ExpectedValue -Actual $ActualValue -CaseSensitive -Because $Because) -join "`n"
}

function NotShouldBeExactlyFailureMessage($ActualValue, $ExpectedValue, $Because) {
    return "Expected $(Format-Nicely $ExpectedValue) to be different from the actual value,$(if ($null -ne $Because) { Format-Because $Because }) but got exactly the same value."
}

& $script:SafeCommands['Add-ShouldOperator'] -Name BeExactly `
    -InternalName       Should-BeAssertionExactly `
    -Test               ${function:Should-BeAssertionExactly} `
    -Alias              'CEQ' `
    -SupportsArrayInput

Set-ShouldOperatorHelpMessage -OperatorName BeExactly `
    -HelpMessage 'Compares one object with another for equality and throws if the two objects are not the same. This comparison is case sensitive.'

#common functions
function Get-CompareStringMessage {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [String]$ExpectedValue,
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [String]$Actual,
        [switch]$CaseSensitive,
        $Because,
        # this is here for testing, we normally would fallback to the buffer size
        $MaximumLineLength,
        $ContextLength
    )

    if ($null -eq $MaximumLineLength) {
        # this is how long the line is, check how this is defined on headless / non-interactive client
        $MaximumLineLength = $host.UI.RawUI.BufferSize.Width
    }

    if ($null -eq $ContextLength) {
        # this is how much text we want to see after difference in the excerpt
        $ContextLength = $MaximumLineLength / 7
    }
    $ExpectedValueLength = $ExpectedValue.Length
    $actualLength = $actual.Length
    $maxLength = if ($ExpectedValueLength -gt $actualLength) { $ExpectedValueLength } else { $actualLength }

    $differenceIndex = $null
    for ($i = 0; $i -lt $maxLength -and ($null -eq $differenceIndex); ++$i) {
        $differenceIndex = if ($CaseSensitive -and ($ExpectedValue[$i] -cne $actual[$i])) {
            $i
        }
        elseif ($ExpectedValue[$i] -ne $actual[$i]) {
            $i
        }
    }

    if ($null -ne $differenceIndex) {
        "Expected strings to be the same,$(if ($null -ne $Because) { Format-Because $Because }) but they were different."

        if ($ExpectedValue.Length -ne $actual.Length) {
            "Expected length: $ExpectedValueLength"
            "Actual length:   $actualLength"
            "Strings differ at index $differenceIndex."
        }
        else {
            "String lengths are both $ExpectedValueLength."
            "Strings differ at index $differenceIndex."
        }

        # find the difference in the string with expanded characters, this is the fastest and most foolproof way of
        # getting the updated difference index. we could also inspect the new string and try to find every occurrence
        # of special character before the difference index, but '\n' is valid piece of string
        # or inspect the original string, but then we need to make sure that we look for all the special characters.
        # instead we just compare it again.

        $actualExpanded = Expand-SpecialCharacters -InputObject $actual
        $expectedExpanded = Expand-SpecialCharacters -InputObject $ExpectedValue
        $maxLength = if ($expectedExpanded.Length -gt $actualExpanded.Length) { $expectedExpanded.Length } else { $actualExpanded.Length }
        $differenceIndex = $null
        for ($i = 0; $i -lt $maxLength -and ($null -eq $differenceIndex); ++$i) {
            $differenceIndex = if ($CaseSensitive -and ($expectedExpanded[$i] -cne $actualExpanded[$i])) {
                $i
            }
            elseif ($expectedExpanded[$i] -ne $actualExpanded[$i]) {
                $i
            }
        }

        $ellipsis = "..."
        # we will sorround the output with Expected: '' and But was: '', from which the Expected: '' is longer
        # so subtract that from the maximum line length, to get how much of the line we actually have available
        $sorroundLength = "Expected: ''".Length
        # the deeper we are in the test structure the less space we have on screen because we are adding margin
        # before the output each describe level adds one space + 3 spaces for the test output margin
        $sideOffset = @((Get-CurrentTest).Path).Length + 3
        $availableLineLength = $maximumLineLength - $sorroundLength - $sideOffset

        $expectedExcerpt = Format-AsExcerpt -InputObject $expectedExpanded -DifferenceIndex $differenceIndex -LineLength $availableLineLength -ExcerptMarker $ellipsis -ContextLength $ContextLength

        $actualExcerpt = Format-AsExcerpt -InputObject $actualExpanded -DifferenceIndex $differenceIndex -LineLength $availableLineLength -ExcerptMarker $ellipsis -ContextLength $ContextLength

        "Expected: '{0}'" -f $expectedExcerpt.Line
        "But was:  '{0}'" -f $actualExcerpt.Line
        " " * ($sorroundLength - 1) + '-' * $actualExcerpt.DifferenceIndex + '^'
    }
}

function Format-AsExcerpt {
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string] $InputObject,
        [Parameter(Mandatory = $true)]
        [int] $DifferenceIndex,
        [Parameter(Mandatory = $true)]
        [int] $LineLength,
        [Parameter(Mandatory = $true)]
        [string] $ExcerptMarker,
        [Parameter(Mandatory = $true)]
        [int] $ContextLength
    )

    $markerLength = $ExcerptMarker.Length
    $inputLength = $InputObject.Length
    # e.g. <marker><precontext><diffchar><postcontext><marker> ...precontextXpostcontext...
    $minimumLineLength = $ContextLength + $markerLength + 1 + $markerLength + $ContextLength
    if ($LineLength -lt $minimumLineLength -or $inputLength -le $LineLength ) {
        # the available line length is so short that we can't reasonable work with it. Ignore formatting and just print it as is.
        # User will see output with a lot of line breaks, but they probably expect that with having super narrow window.
        # or when input is shorter than available line length,
        # there won't be any cutting
        return @{
            Line            = $InputObject
            DifferenceIndex = $DifferenceIndex
        }
    }

    # this will make the whole string shorter as diff index gets closer to the end, so it won't use the whole screen
    # but otherwise we would have to share which operations we did on one string and repeat them on the other
    # which would get very complicated. This way it just works.
    # We need to shift to left by 1 diff char, post-context and end marker length
    $shiftToLeft = $DifferenceIndex - ($LineLength - 1 - $ContextLength - $markerLength)

    if ($shiftToLeft -lt 0) {
        # diff index fits on screen
        $shiftToLeft = 0
    }

    $shiftedToLeft = $InputObject.Substring($shiftToLeft, $inputLength - $shiftToLeft)

    if ($shiftedToLeft.Length -lt $inputLength) {
        # we shortened it show cut marker
        $shiftedToLeft = $ExcerptMarker + $shiftedToLeft.Substring($markerLength, $shiftedToLeft.Length - $markerLength)
    }

    if ($shiftedToLeft.Length -gt $LineLength) {
        # we would be out of screen cut end
        $shiftedToLeft = $shiftedToLeft.Substring(0, $LineLength - $markerLength) + $ExcerptMarker
    }

    return @{
        Line            = $shiftedToLeft
        DifferenceIndex = $DifferenceIndex - $shiftToLeft
    }
}



function Expand-SpecialCharacters {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [AllowEmptyString()]
        [string[]]$InputObject)
    process {
        $InputObject -replace "`n", "\n" -replace "`r", "\r" -replace "`t", "\t" -replace "`0", "\0" -replace "`b", "\b"
    }
}

function ArraysAreEqual {
    param (
        [object[]] $First,
        [object[]] $Second,
        [switch] $CaseSensitive,
        [int] $RecursionDepth = 0,
        [int] $RecursionLimit = 100
    )
    $RecursionDepth++

    if ($RecursionDepth -gt $RecursionLimit) {
        throw "Reached the recursion depth limit of $RecursionLimit when comparing arrays $First and $Second. Is one of your arrays cyclic?"
    }

    # Do not remove the subexpression @() operators in the following two lines; doing so can cause a
    # silly error in PowerShell v3.  (Null Reference exception from the PowerShell engine in a
    # method called CheckAutomationNullInCommandArgumentArray(System.Object[]) ).
    $firstNullOrEmpty = ArrayOrSingleElementIsNullOrEmpty -Array @($First)
    $secondNullOrEmpty = ArrayOrSingleElementIsNullOrEmpty -Array @($Second)

    if ($firstNullOrEmpty -or $secondNullOrEmpty) {
        return $firstNullOrEmpty -and $secondNullOrEmpty
    }

    if ($First.Count -ne $Second.Count) {
        return $false
    }

    for ($i = 0; $i -lt $First.Count; $i++) {
        if ((IsArray $First[$i]) -or (IsArray $Second[$i])) {
            if (-not (ArraysAreEqual -First $First[$i] -Second $Second[$i] -CaseSensitive:$CaseSensitive -RecursionDepth $RecursionDepth -RecursionLimit $RecursionLimit)) {
                return $false
            }
        }
        else {
            if ($CaseSensitive) {
                $comparer = { param($Actual, $Expected) $Expected -ceq $Actual }
            }
            else {
                $comparer = { param($Actual, $Expected) $Expected -eq $Actual }
            }

            if (-not (& $comparer $First[$i] $Second[$i])) {
                return $false
            }
        }
    }

    return $true
}

function ArrayOrSingleElementIsNullOrEmpty {
    param ([object[]] $Array)

    return $null -eq $Array -or $Array.Count -eq 0 -or ($Array.Count -eq 1 -and $null -eq $Array[0])
}

function IsArray {
    param ([object] $InputObject)

    # Changing this could cause infinite recursion in ArraysAreEqual.
    # see https://github.com/pester/Pester/issues/785#issuecomment-322794011
    return $InputObject -is [Array]
}

function ReplaceValueInArray {
    param (
        [object[]] $Array,
        [object] $Value,
        [object] $NewValue
    )

    foreach ($object in $Array) {
        if ($Value -eq $object) {
            $NewValue
        }
        elseif (@($object).Count -gt 1) {
            ReplaceValueInArray -Array @($object) -Value $Value -NewValue $NewValue
        }
        else {
            $object
        }
    }
}
