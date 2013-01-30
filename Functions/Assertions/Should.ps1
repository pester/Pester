
function Parse-ShouldArgs([array] $shouldArgs) {
    $parsedArgs = @{ PositiveAssertion = $true }

    $assertionMethodIndex = 0
    $expectedValueIndex   = 1

    if ($shouldArgs[0].ToLower() -eq "not") {
        $parsedArgs.PositiveAssertion = $false
        $assertionMethodIndex += 1
        $expectedValueIndex   += 1
    }
    $parsedArgs.ExpectedValue = $shouldArgs[$expectedValueIndex]
    $parsedArgs.AssertionMethod = $shouldArgs[$assertionMethodIndex]

    if ($parsedArgs.AssertionMethod.ToLower() -eq "throw") {
        $parsedArgs.AssertionMethod = "PesterThrow"
    }

    return $parsedArgs
}

function Get-TestResult($shouldArgs, $value) {
    $testResult = (& $shouldArgs.AssertionMethod $value $shouldArgs.ExpectedValue)

    if ($shouldArgs.PositiveAssertion) {
        return -not $testResult
    }

    return $testResult
}

function Get-FailureMessage($shouldArgs, $value) {
    $errorMessageFunction = "$($shouldArgs.AssertionMethod)ErrorMessage"
    if (-not $shouldArgs.PositiveAssertion) {
        $errorMessageFunction = "Not$errorMessageFunction"
    }

    return (& $errorMessageFunction $shouldArgs.ExpectedValue $value)
}

function Should {
    process {
        $value = $_

        $parsedArgs = Parse-ShouldArgs $args
        $testFailed = Get-TestResult   $parsedArgs $value

        if ($testFailed) {
            throw (Get-FailureMessage $parsedArgs $value)
        }
    }
}

