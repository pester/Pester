
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
    $parsedArgs.AssertionMethod = "Pester$($shouldArgs[$assertionMethodIndex])"

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
    $failureMessageFunction = "$($shouldArgs.AssertionMethod)FailureMessage"
    if (-not $shouldArgs.PositiveAssertion) {
        $failureMessageFunction = "Not$failureMessageFunction"
    }

    return (& $failureMessageFunction $value $shouldArgs.ExpectedValue)
}

function Should {
    process {
        $value = $_

        $parsedArgs = Parse-ShouldArgs $args
        $testFailed = Get-TestResult   $parsedArgs $value

        if ($testFailed) {
            $pester.ShouldExceptionLine = $MyInvocation.ScriptLineNumber
            throw (Get-FailureMessage $parsedArgs $value)
        }
    }
}

