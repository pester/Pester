#Be
function PesterBe($ActualValue, $ExpectedValue, [switch] $Negate) {
    [bool] $succeeded = ArraysAreEqual $ActualValue $ExpectedValue

    if ($Negate) { $succeeded = -not $succeeded }

    $failureMessage = ''

    if (-not $succeeded)
    {
        if ($Negate)
        {
            $failureMessage = NotPesterBeFailureMessage -ActualValue $ActualValue -Expected $ExpectedValue
        }
        else
        {
            $failureMessage = PesterBeFailureMessage -ActualValue $ActualValue -Expected $ExpectedValue
        }
    }

    return & $SafeCommands['New-Object'] psobject -Property @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

function PesterBeFailureMessage($ActualValue, $ExpectedValue) {
    # This looks odd; it's to unroll single-element arrays so the "-is [string]" expression works properly.
    $ActualValue = $($ActualValue)
    $ExpectedValue = $($ExpectedValue)

    if (-not (($ExpectedValue -is [string]) -and ($ActualValue -is [string])))
    {
        return "Expected: {$ExpectedValue}`nBut was:  {$ActualValue}"
    }
    <#joining the output strings to a single string here, otherwise I get
       Cannot find an overload for "Exception" and the argument count: "4".
       at line: 63 in C:\Users\nohwnd\github\pester\Functions\Assertions\Should.ps1

    This is a quickwin solution, doing the join in the Should directly might be better
    way of doing this. But I don't want to mix two problems.
    #>
    ( Get-CompareStringMessage -Expected $ExpectedValue -Actual $ActualValue ) -join "`n"
}

function NotPesterBeFailureMessage($ActualValue, $ExpectedValue) {
    return "Expected: value was {$ActualValue}, but should not have been the same"
}

Add-AssertionOperator -Name               Be `
                      -Test               $function:PesterBe `
                      -Alias              'EQ' `
                      -SupportsArrayInput

#BeExactly
function PesterBeExactly($ActualValue, $ExpectedValue) {
    [bool] $succeeded = ArraysAreEqual $ActualValue $ExpectedValue -CaseSensitive

    if ($Negate) { $succeeded = -not $succeeded }

    $failureMessage = ''

    if (-not $succeeded)
    {
        if ($Negate)
        {
            $failureMessage = NotPesterBeExactlyFailureMessage -ActualValue $ActualValue -ExpectedValue $ExpectedValue
        }
        else
        {
            $failureMessage = PesterBeExactlyFailureMessage -ActualValue $ActualValue -ExpectedValue $ExpectedValue
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

function PesterBeExactlyFailureMessage($ActualValue, $ExpectedValue) {
    # This looks odd; it's to unroll single-element arrays so the "-is [string]" expression works properly.
    $ActualValue = $($ActualValue)
    $ExpectedValue = $($ExpectedValue)

    if (-not (($ExpectedValue -is [string]) -and ($ActualValue -is [string])))
    {
        return "Expected exactly: {$ExpectedValue}`nBut was: {$ActualValue}"
    }
    <#joining the output strings to a single string here, otherwise I get
       Cannot find an overload for "Exception" and the argument count: "4".
       at line: 63 in C:\Users\nohwnd\github\pester\Functions\Assertions\Should.ps1

    This is a quickwin solution, doing the join in the Should directly might be better
    way of doing this. But I don't want to mix two problems.
    #>
    ( Get-CompareStringMessage -Expected $ExpectedValue -Actual $ActualValue -CaseSensitive ) -join "`n"
}

function NotPesterBeExactlyFailureMessage($ActualValue, $ExpectedValue) {
    return "Expected: value was {$ActualValue}, but should not have been exactly the same"
}

Add-AssertionOperator -Name               BeExactly `
                      -Test               $function:PesterBeExactly `
                      -Alias              'CEQ' `
                      -SupportsArrayInput


#common functions
function Get-CompareStringMessage {
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [String]$ExpectedValue,
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [String]$Actual,
        [switch]$CaseSensitive
    )

    $ExpectedValueLength = $ExpectedValue.Length
    $actualLength = $actual.Length
    $maxLength = $ExpectedValueLength,$actualLength | & $SafeCommands['Sort-Object'] -Descending | & $SafeCommands['Select-Object'] -First 1

    $differenceIndex = $null
    for ($i = 0; $i -lt $maxLength -and ($null -eq $differenceIndex); ++$i){
        $differenceIndex = if ($CaseSensitive -and ($ExpectedValue[$i] -cne $actual[$i]))
        {
            $i
        }
        elseif ($ExpectedValue[$i] -ne $actual[$i])
        {
            $i
        }
    }

    [string]$output = $null
    if ($null -ne $differenceIndex)
    {
        if ($ExpectedValue.Length -ne $actual.Length) {
           "Expected string length $ExpectedValueLength but was $actualLength. Strings differ at index $differenceIndex."
        }
        else
        {
           "String lengths are both $ExpectedValueLength. Strings differ at index $differenceIndex."
        }

        "Expected: {{{0}}}" -f ( $ExpectedValue | Expand-SpecialCharacters )
        "But was:  {{{0}}}" -f ( $actual | Expand-SpecialCharacters )

        $specialCharacterOffset = $null
        if ($differenceIndex -ne 0)
        {
            #count all the special characters before the difference
            $specialCharacterOffset = ($actual[0..($differenceIndex-1)] |
                & $SafeCommands['Where-Object'] {"`n","`r","`t","`b","`0" -contains $_} |
                & $SafeCommands['Measure-Object'] |
                & $SafeCommands['Select-Object'] -ExpandProperty Count)
        }

        '-'*($differenceIndex+$specialCharacterOffset+11)+'^'
    }
}

function Expand-SpecialCharacters {
    param (
    [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
    [AllowEmptyString()]
    [string[]]$InputObject)
    process {
        $InputObject -replace "`n","\n" -replace "`r","\r" -replace "`t","\t" -replace "`0", "\0" -replace "`b","\b"
    }
}

function ArraysAreEqual
{
    param (
        [object[]] $First,
        [object[]] $Second,
        [switch] $CaseSensitive,
        [int] $RecursionDepth = 0,
        [int] $RecursionLimit = 100
    )
    $RecursionDepth++

    if ($RecursionDepth -gt $RecursionLimit)
    {
        throw "Reached the recursion depth limit of $RecursionLimit when comparing arrays $First and $Second. Is one of your arrays cyclic?"
    }

    # Do not remove the subexpression @() operators in the following two lines; doing so can cause a
    # silly error in PowerShell v3.  (Null Reference exception from the PowerShell engine in a
    # method called CheckAutomationNullInCommandArgumentArray(System.Object[]) ).
    $firstNullOrEmpty  = ArrayOrSingleElementIsNullOrEmpty -Array @($First)
    $secondNullOrEmpty = ArrayOrSingleElementIsNullOrEmpty -Array @($Second)

    if ($firstNullOrEmpty -or $secondNullOrEmpty)
    {
        return $firstNullOrEmpty -and $secondNullOrEmpty
    }

    if ($First.Count -ne $Second.Count) { return $false }

    for ($i = 0; $i -lt $First.Count; $i++)
    {
        if ((IsArray $First[$i]) -or (IsArray $Second[$i]))
        {
            if (-not (ArraysAreEqual -First $First[$i] -Second $Second[$i] -CaseSensitive:$CaseSensitive -RecursionDepth $RecursionDepth -RecursionLimit $RecursionLimit))
            {
                return $false
            }
        }
        else
        {
            if ($CaseSensitive)
            {
                $comparer = { param($Actual, $Expected) $Expected -ceq $Actual }
            }
            else
            {
                $comparer = { param($Actual, $Expected) $Expected -eq $Actual }
            }

            if (-not (& $comparer $First[$i] $Second[$i]))
            {
                return $false
            }
        }
    }

    return $true
}

function ArrayOrSingleElementIsNullOrEmpty
{
    param ([object[]] $Array)

    return $null -eq $Array -or $Array.Count -eq 0 -or ($Array.Count -eq 1 -and $null -eq $Array[0])
}

function IsArray
{
    param ([object] $InputObject)

    # Changing this could cause infinite recursion in ArraysAreEqual.
    # see https://github.com/pester/Pester/issues/785#issuecomment-322794011
    return $InputObject -is [Array]
}

function ReplaceValueInArray
{
    param (
        [object[]] $Array,
        [object] $Value,
        [object] $NewValue
    )

    foreach ($object in $Array)
    {
        if ($Value -eq $object)
        {
            $NewValue
        }
        elseif (@($object).Count -gt 1)
        {
            ReplaceValueInArray -Array @($object) -Value $Value -NewValue $NewValue
        }
        else
        {
            $object
        }
    }
}

