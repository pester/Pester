function PesterContainMultiline($ActualValue, $ExpectedContent, [switch] $Negate) {
    $succeeded = [bool] ((Get-Content $ActualValue -delim ([char]0)) -match $ExpectedContent)

    if ($Negate) { $succeeded = -not $succeeded }

    $failureMessage = ''

    if (-not $succeeded)
    {
        if ($Negate)
        {
            $failureMessage = NotPesterContainMultilineFailureMessage -ActualValue $ActualValue -ExpectedContent $ExpectedContent
        }
        else
        {
            $failureMessage = PesterContainMultilineFailureMessage -ActualValue $ActualValue -ExpectedContent $ExpectedContent
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

function PesterContainMultilineFailureMessage($ActualValue, $ExpectedContent) {
    return "Expected: file {$ActualValue} to contain {$ExpectedContent}"
}

function NotPesterContainMultilineFailureMessage($ActualValue, $ExpectedContent) {
    return "Expected: file {$ActualValue} to not contain {$ExpectedContent} but it did"
}

Add-AssertionOperator -Name  ContainMultiline `
                      -Test  $function:PesterContainMultiline
