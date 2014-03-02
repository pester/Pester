
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
function New-ShouldException ($Message,$Line) {
    $exception = New-Object Exception $Message
    $errorID = 'PesterAssertionFailed'
    $errorCategory = [Management.Automation.ErrorCategory]::InvalidResult
    $errorRecord = New-Object Management.Automation.ErrorRecord $exception, $errorID, $errorCategory, $null
    $errorRecord.ErrorDetails = "$Message failed at line: $line"
    
    $errorRecord
}

function Should {
    begin {
        $parsedArgs = Parse-ShouldArgs $args
    }

    end {
        $input.MoveNext()
        do {
            $value = $input.Current

            $testFailed = Get-TestResult $parsedArgs $value

            if ($testFailed) {
                $ShouldExceptionLine = $MyInvocation.ScriptLineNumber
                $failureMessage = Get-FailureMessage $parsedArgs $value
                
                
                throw ( New-ShouldException -Message $failureMessage -Line $ShouldExceptionLine )
            }
        } until ($input.MoveNext() -eq $false)
    }
}

