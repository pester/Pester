function PesterBeAcceptsArrayInput
{
    return $true
}

function PesterBe($value, $expected) {
    return CompareArrays $value $expected
}

function PesterBeFailureMessage($value, $expected) {
    return "Expected: {$expected}`nBut was:  {$value}"
}

function NotPesterBeFailureMessage($value, $expected) {
    return "Expected: value was {$value}, but should not have been the same"
}

function PesterBeExactly($value, $expected) {
    return CompareArrays $value $expected -CaseSensitive
}

function PesterBeExactlyAcceptsArrayInput
{
    return $true
}

function PesterBeExactlyFailureMessage($value, $expected) {
    return "Expected: exactly {$expected}, But was {$value}"
}

function NotPesterBeExactlyFailureMessage($value, $expected) {
    return "Expected: value was {$value}, but should not have been exactly the same"
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
        return $null -eq $Actual -or $Actual.Count -eq 0
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
