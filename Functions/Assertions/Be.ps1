#Be
function PesterBe($value, $expected) {
    return CompareArrays $value $expected
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
    return CompareArrays $value $expected -CaseSensitive
}

function PesterBeExactlyFailureMessage($value, $expected) {
<<<<<<< HEAD
    if (-not (($expected -is [string]) -and ($value -is [string])))
=======
    # This looks odd; it's to unroll single-element arrays so the "-is [string]" expression works properly.
    $value = ($value)
    $expected = ($expected)

    if (-not (($expected -is [string]) -and ($value -is [string])))
>>>>>>> b4f3124... Added array comparison support for Be / BeNullOrEmpty / BeExactly
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
        [String]$Expected,
        [Parameter(Mandatory=$true)]
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
    [string[]]$InputObject)
    process {
        $InputObject -replace "`n","\n" -replace "`r","\r" -replace "`t","\t" -replace "`0", "\0" -replace "`b","\b"
    }
}

function CompareArrays
{
    param (
        [object[]] $Actual,
        [object[]] $Expected,
        [switch] $CaseSensitive
    )

    if ($null -eq $Expected)
    {
        return $null -eq $Actual -or $Actual.Count -eq 0 -or ($Actual.Count -eq 1 -and $null -eq $Actual[0])
    }

    $params = @{ SyncWindow = 0 }
    if ($CaseSensitive)
    {
        $params['CaseSensitive'] = $true
    }

    $placeholderForNull = New-Object object

    $Actual   = @(ReplaceValueInArray -Array $Actual -Value $null -NewValue $placeholderForNull)
    $Expected = @(ReplaceValueInArray -Array $Expected -Value $null -NewValue $placeholderForNull)

    $arraysAreEqual = ($null -eq (Compare-Object $Actual $Expected @params))

    return $arraysAreEqual
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

