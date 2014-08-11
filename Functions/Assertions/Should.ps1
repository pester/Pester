function Parse-ShouldArgs([object[]] $shouldArgs) {
    if ($null -eq $shouldArgs) { $shouldArgs = @() }

    $parsedArgs = @{
        PositiveAssertion = $true
        ExpectedValue = $null
    }

    $assertionMethodIndex = 0
    $expectedValueIndex   = 1

    if ($shouldArgs.Count -gt 0 -and $shouldArgs[0] -eq "not") {
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
    $command = Get-Command $assertionMethod -ErrorAction SilentlyContinue

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

function Test-OperatorAcceptsArrayValue($shouldArgs)
{
    $acceptsArrayMethodName = "$($shouldArgs.AssertionMethod)AcceptsArrayInput"
    $acceptsArrayCommand = Get-Command -Name $acceptsArrayMethodName -ErrorAction SilentlyContinue

    return $null -ne $acceptsArrayCommand -and (& $acceptsArrayCommand)
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

    end
    {
        if (Test-OperatorAcceptsArrayValue $parsedArgs)
        {
            $valueToTest = foreach ($object in $input) { $object }
            Invoke-Assertion $parsedArgs $valueToTest $MyInvocation.ScriptLineNumber
        }
        else
        {
            while ($input.MoveNext())
            {
                Invoke-Assertion $parsedArgs $input.Current $MyInvocation.ScriptLineNumber
            }
        }
    }
}

function Invoke-Assertion($shouldArgs, $valueToTest, $lineNumber)
{
    $testFailed = Get-TestResult $shouldArgs $valueToTest
    if ($testFailed)
    {
        $failureMessage = Get-FailureMessage $shouldArgs $valueToTest
        throw ( New-ShouldException -Message $failureMessage -Line $lineNumber )
    }
}