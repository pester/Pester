function PesterContainExactly($ActualValue, $ExpectedContent, [switch] $Negate) {
    $succeeded = (@(Get-Content $ActualValue) -cmatch $ExpectedContent).Count -gt 0

    if ($Negate) { $succeeded = -not $succeeded }

    $failureMessage = ''

    if (-not $succeeded)
    {
        if ($Negate)
        {
            $failureMessage = NotPesterContainExactlyFailureMessage -ActualValue $ActualValue -ExpectedContent $ExpectedContent
        }
        else
        {
            $failureMessage = PesterContainExactlyFailureMessage -ActualValue $ActualValue -ExpectedContent $ExpectedContent
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

function PesterContainExactlyFailureMessage($ActualValue, $ExpectedContent) {
    return "Expected: file {$ActualValue} to contain exactly {$ExpectedContent}"
}

function NotPesterContainExactlyFailureMessage($ActualValue, $ExpectedContent) {
    return "Expected: file {$ActualValue} to not contain exactly {$ExpectedContent} but it did"
}

Add-AssertionOperator -Name ContainExactly `
                      -Test $function:PesterContainExactly
