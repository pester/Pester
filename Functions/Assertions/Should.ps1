function Parse-ShouldArgs([array] $shouldArgs) {
    if ($null -eq $shouldArgs) { $shouldArgs = @() }

    $parsedArgs = @{
        PositiveAssertion = $true
        ExpectedValue = $null
    }

    $assertionMethodIndex = 0
    $expectedValueIndex   = 1

    if ($shouldArgs.Count -gt 0 -and $shouldArgs[0].ToLower() -eq "not") {
        $parsedArgs.PositiveAssertion = $false
        $assertionMethodIndex += 1
        $expectedValueIndex   += 1
    }

    if ($assertionMethodIndex -lt $shouldArgs.Count)
    {
        $parsedArgs.AssertionMethod = "Pester$($shouldArgs[$assertionMethodIndex])"
    }
    else
    {
        throw 'You cannot call Should without specifying an assertion method.'
    }

    if ($expectedValueIndex -lt $shouldArgs.Count)
    {
        $parsedArgs.ExpectedValue = $shouldArgs[$expectedValueIndex]
    }

    return $parsedArgs
}

function Get-TestResult($shouldArgs, $value) {
    $assertionMethod = $shouldArgs.AssertionMethod
    $command = Get-Command $assertionMethod -ErrorAction $script:IgnoreErrorPreference

    if ($null -eq $command)
    {
        $assertionMethod = $assertionMethod -replace '^Pester'
        throw "'$assertionMethod' is not a valid Should operator."
    }

    $testResult = (& $assertionMethod $value $shouldArgs.ExpectedValue)

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
        Assert-DescribeInProgress -CommandName Should
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
