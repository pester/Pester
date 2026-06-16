function New-ShouldExpectResult {
    param (
        $Expected,
        $Actual,
        [string]$Because,
        [switch]$Pretty
    )

    [Pester.ShouldResult]@{
        Succeeded    = $false
        ExpectResult = [Pester.ShouldExpectResult]@{
            Actual   = Format-Nicely2 -Value $Actual -Pretty:$Pretty
            Expected = Format-Nicely2 -Value $Expected -Pretty:$Pretty
            Because  = $Because
        }
    }
}

function New-ShouldErrorRecord {
    param (
        [Parameter(Mandatory)]
        [string] $Message,
        [Parameter(Mandatory)]
        [Management.Automation.InvocationInfo] $Invocation,
        [bool] $Terminating = $true,
        $Expected,
        $Actual,
        [string] $Because,
        [switch] $Pretty
    )

    $hasExplicitExpectation = $PSBoundParameters.ContainsKey('Expected') -or
        $PSBoundParameters.ContainsKey('Actual') -or
        $PSBoundParameters.ContainsKey('Because')

    $shouldResult = if ($hasExplicitExpectation) {
        New-ShouldExpectResult -Expected $Expected -Actual $Actual -Because $Because -Pretty:$Pretty
    }
    else {
        $script:AssertionShouldResult
    }

    if ($null -ne $shouldResult) {
        $shouldResult.FailureMessage = $Message
    }

    try {
        [Pester.Factory]::CreateShouldErrorRecord(
            $Message,
            $Invocation.ScriptName,
            $Invocation.ScriptLineNumber,
            $Invocation.Line.TrimEnd([System.Environment]::NewLine),
            $Terminating,
            $shouldResult)
    }
    finally {
        $script:AssertionShouldResult = $null
    }
}

function Get-AssertionMessage ($Expected, $Actual, $Because, $Option, [hashtable]$Data = @{}, $CustomMessage, $DefaultMessage, [switch]$Pretty) {
    if (-not $CustomMessage) {
        $CustomMessage = $DefaultMessage
    }

    $expectedFormatted = Format-Nicely2 -Value $Expected -Pretty:$Pretty
    $actualFormatted = Format-Nicely2 -Value $Actual -Pretty:$Pretty
    $becauseFormatted = Format-Because -Because $Because
    $script:AssertionShouldResult = New-ShouldExpectResult -Expected $Expected -Actual $Actual -Because $Because -Pretty:$Pretty

    $optionMessage = $null;
    if ($null -ne $Option -and $option.Length -gt 0) {
        if (-not $Pretty) {
            $optionMessage = "Used options: $($Option -join ", ")."
        }
        else {
            if ($Pretty) {
                $optionMessage = "Used options:$(foreach ($o in $Option) { "`n$o" })."
            }
        }
    }


    $CustomMessage = $CustomMessage.Replace('<expected>', $expectedFormatted)
    $CustomMessage = $CustomMessage.Replace('<actual>', $actualFormatted)
    $CustomMessage = $CustomMessage.Replace('<expectedType>', (Get-ShortType2 -Value $Expected))
    $CustomMessage = $CustomMessage.Replace('<actualType>', (Get-ShortType2 -Value $Actual))
    $CustomMessage = $CustomMessage.Replace('<options>', $optionMessage)
    $CustomMessage = $CustomMessage.Replace('<because>', $becauseFormatted)

    foreach ($pair in $Data.GetEnumerator()) {
        $CustomMessage = $CustomMessage.Replace("<$($pair.Key)>", (Format-Nicely2 -Value $pair.Value))
    }

    if (-not $Pretty) {
        $CustomMessage
    }
    else {
        $CustomMessage + "`n`n"
    }
}
