
function PesterBe($value, $expected) {
    return CompareArrays @($value) @($expected)
}

function PesterBeFailureMessage($value, $expected) {
    return "Expected: {$expected}`nBut was:  {$value}"
}

function NotPesterBeFailureMessage($value, $expected) {
    return "Expected: value was {$value}, but should not have been the same"
}

function PesterBeExactly($value, $expected) {
    return CompareArrays @($value) @($expected) -CaseSensitive
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
        [object[]] $First,
        [object[]] $Second,
        [switch] $CaseSensitive
    )

    $params = @{ SyncWindow = 0 }
    if ($CaseSensitive)
    {
        $params['CaseSensitive'] = $true
    }

    $placeholderForNull = New-Object object

    $First = @(ReplaceValueInArray -Array $First -Value $null -NewValue $placeholderForNull)
    $Second = @(ReplaceValueInArray -Array $Second -Value $null -NewValue $placeholderForNull)

    $arraysAreEqual = ($null -eq (Compare-Object $First $Second @params))

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
