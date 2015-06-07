function PesterContain($ActualValue, $ExpectedContent, [switch] $Negate) {
    $succeeded = (@(Get-Content $ActualValue) -match $ExpectedContent).Count -gt 0

    if ($Negate) { $succeeded = -not $succeeded }

    $failureMessage = ''

    if (-not $succeeded)
    {
        if ($Negate)
        {
            $failureMessage = NotPesterContainFailureMessage -ActualValue $ActualValue -ExpectedContent $ExpectedContent
        }
        else
        {
            $failureMessage = PesterContainFailureMessage -ActualValue $ActualValue -ExpectedContent $ExpectedContent
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

function PesterContainFailureMessage($ActualValue, $ExpectedContent) {
    return "Expected: file {$ActualValue} to contain {$ExpectedContent}"
}

function NotPesterContainFailureMessage($ActualValue, $ExpectedContent) {
    return "Expected: file {$ActualValue} to not contain {$ExpectedContent} but it did"
}

Add-AssertionOperator -Name Contain `
                      -Test $function:PesterContain
