#Be
function PesterBe($value, $expected) {
    return ($expected -eq $value)
}

function PesterBeFailureMessage($value, $expected) {
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

#BeExactly
function PesterBeExactly($value, $expected) {
    return ($expected -ceq $value)
}

function PesterBeExactlyFailureMessage($value, $expected) {
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

