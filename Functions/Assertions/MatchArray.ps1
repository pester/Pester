function PesterMatchArrayUnordered($ActualValue, $ExpectedValue, [switch] $Negate) {
    $message = FindMismatchedValueUnordered $ActualValue $ExpectedValue
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
function FindMismatchedValueUnordered($ActualValue, $ExpectedValue) {
    $ActualValue = @($ActualValue)
    for ($i = 0; $i -lt $ExpectedValue.Length; $i++) {
        if (-not($ActualValue -contains $ExpectedValue[$i])) {
            return "Expected: {$ExpectedValue}. Actual: {$ActualValue}. Actual is missing item: $($ExpectedValue[$i])"
        }
    }
    for ($i = 0; $i -lt $ActualValue.Length; $i++) {
        if (-not($ExpectedValue -contains $ActualValue[$i])) {
            return "Expected: {$ExpectedValue}. Actual: {$ActualValue}. Actual contains extra item: $($ActualValue[$i])"
        }
    }
    if ($ActualValue.Length -ne $ExpectedValue.Length) {
        return "Lengths differ. Expected length $($ExpectedValue.Length). Actual length $($ActualValue.Length) ";
    }
    return $null;
}

Add-AssertionOperator -Name  MatchArrayUnordered `
    -Test  $function:PesterMatchArrayUnordered

###################################################################################################
function PesterMatchArrayOrdered($ActualValue, $ExpectedValue, [switch] $Negate) {

    $message = FindMismatchedValueOrdered $ActualValue $ExpectedValue
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

function FindMismatchedValueOrdered($ActualValue, $ExpectedValue) {
    $ActualValue = @($ActualValue)
    for ($i = 0; $i -lt $ExpectedValue.Length -and $i -lt $ActualValue.Length; $i++) {
        if (-not($ActualValue[$i] -eq $ExpectedValue[$i])) {
            return "Differs at index $i. Expected: {$ExpectedValue}. Actual: {$ActualValue}."
        }
    }
    if ($ActualValue.Length -ne $ExpectedValue.Length) {
        return "Lengths differ - Expected length $($ExpectedValue.Length), actual length $($ActualValue.Length)";
    }
    return $null;
}

Add-AssertionOperator -Name  MatchArrayOrdered `
    -Test  $function:PesterMatchArrayOrdered
