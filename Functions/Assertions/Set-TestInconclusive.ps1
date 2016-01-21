function New-InconclusiveErrorRecord ([string] $Message, [string] $File, [string] $Line, [string] $LineText) {
    $exception = New-Object Exception $Message
    $errorID = 'PesterTestInconclusive'
    $errorCategory = [Management.Automation.ErrorCategory]::InvalidResult
    # we use ErrorRecord.TargetObject to pass structured information about the error to a reporting system.
    $targetObject = @{Message = $Message; File = $File; Line = $Line; LineText = $LineText}
    $errorRecord = New-Object Management.Automation.ErrorRecord $exception, $errorID, $errorCategory, $targetObject
    return $errorRecord
}

function Set-TestInconclusive {
    param (
        [string] $Message
    )

    Assert-DescribeInProgress -CommandName Set-TestInconclusive
    $lineText = $MyInvocation.Line.TrimEnd("`n")
    $line = $MyInvocation.ScriptLineNumber
    $file = $MyInvocation.ScriptName

    throw ( New-InconclusiveErrorRecord -Message $Message -File $file -Line $line -LineText $lineText)
}
