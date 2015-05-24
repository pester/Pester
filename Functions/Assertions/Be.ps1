#Be
function PesterBe($value, $expected) {
    return ArraysAreEqual $value $expected
}

function PesterBeFailureMessage($value, $expected) {
    # This looks odd; it's to unroll single-element arrays so the "-is [string]" expression works properly.
    $value = ($value)
    $expected = ($expected)

    if (-not (($expected -is [string]) -and ($value -is [string])))
    {
        return "Expected: {$expected}`nBut was:  {$value}"
    }
    <#joining the output strings to a single string here, otherwise I get
       Cannot find an overload for "Exception" and the argument count: "4".
       at line: 63 in C:\Users\nohwnd\github\pester\Functions\Assertions\Should.ps1

    This is a quickwin solution, doing the join in the Should directly might be better
    way of doing this. But I don't want to mix two problems.
    #>
    ( Get-CompareStringMessage -Expected $expected -Actual $value ) -join "`n"
}

function NotPesterBeFailureMessage($value, $expected) {
    return "Expected: value was {$value}, but should not have been the same"
}

Add-AssertionOperator -Name                      Be `
                      -Test                      $function:PesterBe `
                      -GetPositiveFailureMessage $function:PesterBeFailureMessage `
                      -GetNegativeFailureMessage $function:NotPesterBeFailureMessage `
                      -SupportsArrayInput

#BeExactly
function PesterBeExactly($value, $expected) {
    return ArraysAreEqual $value $expected -CaseSensitive
}

function PesterBeExactlyFailureMessage($value, $expected) {
    # This looks odd; it's to unroll single-element arrays so the "-is [string]" expression works properly.
    $value = ($value)
    $expected = ($expected)

    if (-not (($expected -is [string]) -and ($value -is [string])))
    {
        return "Expected exactly: {$expected}`nBut was: {$value}"
    }
    <#joining the output strings to a single string here, otherwise I get
       Cannot find an overload for "Exception" and the argument count: "4".
       at line: 63 in C:\Users\nohwnd\github\pester\Functions\Assertions\Should.ps1

    This is a quickwin solution, doing the join in the Should directly might be better
    way of doing this. But I don't want to mix two problems.
    #>
    ( Get-CompareStringMessage -Expected $expected -Actual $value -CaseSensitive ) -join "`n"
}

function NotPesterBeExactlyFailureMessage($value, $expected) {
    return "Expected: value was {$value}, but should not have been exactly the same"
}

Add-AssertionOperator -Name                      BeExactly `
                      -Test                      $function:PesterBeExactly `
                      -GetPositiveFailureMessage $function:PesterBeExactlyFailureMessage `
                      -GetNegativeFailureMessage $function:NotPesterBeExactlyFailureMessage `
                      -SupportsArrayInput


#common functions
function Get-CompareStringMessage {
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [String]$Expected,
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [String]$Actual,
        [switch]$CaseSensitive
    )

    $expectedLength = $expected.Length
    $actualLength = $actual.Length
    $maxLength = $expectedLength,$actualLength | Sort -Descending | select -First 1

    $differenceIndex = $null
    for ($i = 0; $i -lt $maxLength -and ($null -eq $differenceIndex); ++$i){
        $differenceIndex = if ($CaseSensitive -and ($expected[$i] -cne $actual[$i]))
        {
            $i
        }
        elseif ($expected[$i] -ne $actual[$i])
        {
            $i
        }
    }

    [string]$output = $null
    if ($null -ne $differenceIndex)
    {
        if ($expected.Length -ne $actual.Length) {
           "Expected string length $expectedLength but was $actualLength. Strings differ at index $differenceIndex."
        }
        else
        {
           "String lengths are both $expectedLength. Strings differ at index $differenceIndex."
        }


        "Expected: {{{0}}}" -f ( $expected | Expand-SpecialCharacters )
        "But was:  {{{0}}}" -f ( $actual | Expand-SpecialCharacters )

        $specialCharacterOffset = $null
        if ($differenceIndex -ne 0)
        {
            #count all the special characters before the difference
            $specialCharacterOffset = ($actual[0..($differenceIndex-1)] |
                Where {"`n","`r","`t","`b","`0" -contains $_} |
                Measure-Object |
                select -ExpandProperty Count)
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
        [switch] $CaseSensitive
    )

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
        if ((IsCollection $First[$i]) -or (IsCollection $Second[$i]))
        {
            if (-not (ArraysAreEqual -First $First[$i] -Second $Second[$i] -CaseSensitive:$CaseSensitive))
            {
                return $false
            }
        }
        else
        {
            if ($CaseSensitive)
            {
                $comparer = { $args[0] -ceq $args[1] }
            }
            else
            {
                $comparer = { $args[0] -eq $args[1] }
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

function IsCollection
{
    param ([object] $InputObject)

    return $InputObject -is [System.Collections.IEnumerable] -and
           $InputObject -isnot [string] -and
           $InputObject -isnot [System.Collections.IDictionary]
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

