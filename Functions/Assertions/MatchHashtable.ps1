function PesterMatchHashtable($ActualValue, $ExpectedValue, [switch] $Negate) {
   $message = FindMismatchedHashtableValue $ActualValue $ExpectedValue
    $success = $message -eq $null;

    if ($success) {
        if ($Negate) {
            #expecting failure
            $success = $false
            $message = "Expected: ${ActualValue} to not match the expression ${ExpectedValue}"
        }
        # else - we can just return success
    }
    else {
        if ($Negate) {
            # expecting failure
            $success = $true
            $message = ""
        }
        # else - we can just return failure
    }
    return New-Object psobject -Property @{
        Succeeded      = $success
        FailureMessage = $message
    }
}

function FindMismatchedHashtableValue($ActualValue, $ExpectedValue) {
    foreach($expectedKey in $ExpectedValue.Keys) {
        if (-not($ActualValue.Keys -contains $expectedKey)){
            return "Expected key: {$expectedKey}, but missing in actual"
        }
        $expectedItem = $ExpectedValue[$expectedKey]
        $actualItem = $ActualValue[$expectedKey]
        if (-not ($actualItem -eq $expectedItem)) {
            return "Value differs for key {$expectedKey}. Expected value: {$expectedItem}, actual value: {$actualItem}"
        }
    }

    foreach($actualKey in $ActualValue.Keys) {
        if (-not($ExpectedValue.Keys -contains $actualKey)){
            return "Actual key: {$actualKey}, but missing in expected"
        }
        $expectedItem = $ExpectedValue[$actualKey]
        $actualItem = $ActualValue[$actualKey]
        if (-not ($actualItem -eq $expectedItem)) {
            return "Value differs for key {$actualKey}. Expected value: {$expectedItem}, actual value: {$actualItem}"
        }
    }
}

function NotPesterMatchHashtableFailureMessage($ActualValue, $ExpectedValue) {
    return "Expected: ${ActualValue} to not match the expression ${ExpectedValue}"
}

Add-AssertionOperator -Name  MatchHashtable `
    -Test  $function:PesterMatchHashtable
