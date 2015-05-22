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
function New-ShouldErrorRecord ([string] $Message, [string] $File, [string] $Line, [string] $LineText) {
    $exception = New-Object Exception $Message
    $errorID = 'PesterAssertionFailed'
    $errorCategory = [Management.Automation.ErrorCategory]::InvalidResult
    # we use ErrorRecord.TargetObject to pass structured information about the error to a reporting system.
    $targetObject = @{Message = $Message; File = $File; Line = $Line; LineText = $LineText}
    $errorRecord = New-Object Management.Automation.ErrorRecord $exception, $errorID, $errorCategory, $targetObject
    return $errorRecord
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
                $lineText = $MyInvocation.Line.TrimEnd("`n")
                $line = $MyInvocation.ScriptLineNumber
                $file = $MyInvocation.ScriptName

                $failureMessage = Get-FailureMessage $parsedArgs $value

                throw ( New-ShouldErrorRecord -Message $failureMessage -File $file -Line $line -LineText $lineText)
            }
        } until ($input.MoveNext() -eq $false)
    }
}
