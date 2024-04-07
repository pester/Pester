function Assert-Throw {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    param (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [ScriptBlock]$ScriptBlock,
        [Type]$ExceptionType,
        [String]$ExceptionMessage,
        [String]$FullyQualifiedErrorId,
        [Switch]$AllowNonTerminatingError,
        [String]$CustomMessage
    )

    $collectedInput = Collect-Input -ParameterInput $ScriptBlock -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput
    $ScriptBlock = $collectedInput.Actual

    $errorThrown = $false
    $err = $null
    try {
        $p = 'stop'
        if ($AllowNonTerminatingError) {
            $p = 'continue'
        }

        $eap = [PSVariable]::new("erroractionpreference", $p)
        $null = $ScriptBlock.InvokeWithContext($null, $eap, $null) 2>&1
    }
    catch {
        $errorThrown = $true
        $err = Get-Error $_
    }

    $buts = @()
    $filters = @()

    $filterOnExceptionType = $null -ne $ExceptionType
    if ($filterOnExceptionType) {
        $exceptionFilterTypeFormatted = Format-Type2 $ExceptionType

        $filters += "of type $exceptionFilterTypeFormatted"

        $exceptionTypeFilterMatches = $err.Exception -is $ExceptionType
        if (-not $exceptionTypeFilterMatches) {
            $exceptionTypeFormatted = Get-ShortType2 $err.Exception
            $buts += "the exception type was '$exceptionTypeFormatted'"
        }
    }

    $filterOnMessage = -not ([string]::IsNullOrWhiteSpace($ExceptionMessage))
    if ($filterOnMessage) {
        $filters += "with message '$ExceptionMessage'"
        if ($err.ExceptionMessage -notlike $ExceptionMessage) {
            $buts += "the message was '$($err.ExceptionMessage)'"
        }
    }

    $filterOnId = -not ([string]::IsNullOrWhiteSpace($FullyQualifiedErrorId))
    if ($filterOnId) {
        $filters += "with FullyQualifiedErrorId '$FullyQualifiedErrorId'"
        if ($err.FullyQualifiedErrorId -notlike $FullyQualifiedErrorId) {
            $buts += "the FullyQualifiedErrorId was '$($err.FullyQualifiedErrorId)'"
        }
    }

    if (-not $errorThrown) {
        $buts += "no exception was thrown"
    }

    if ($buts.Count -ne 0) {
        $filter = Add-SpaceToNonEmptyString ( Join-And $filters -Threshold 3 )
        $but = Join-And $buts
        $defaultMessage = "Expected an exception,$filter to be thrown, but $but."

        $Message = Get-AssertionMessage -Expected $Expected -Actual $ScriptBlock -CustomMessage $CustomMessage `
            -DefaultMessage $defaultMessage
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }

    $err.ErrorRecord
}

function Get-Error ($ErrorRecord) {

    if ($ErrorRecord.Exception -like '*"InvokeWithContext"*') {
        $e = $ErrorRecord.Exception.InnerException.ErrorRecord
    }
    else {
        $e = $ErrorRecord
    }
    [PSCustomObject] @{
        ErrorRecord           = $e
        ExceptionMessage      = $e.Exception.Message
        Exception             = $e.Exception
        ExceptionType         = $e.Exception.GetType()
        FullyQualifiedErrorId = $e.FullyQualifiedErrorId
    }
}

function Join-And ($Items, $Threshold = 2) {

    if ($null -eq $items -or $items.count -lt $Threshold) {
        $items -join ', '
    }
    else {
        $c = $items.count
        ($items[0..($c - 2)] -join ', ') + ' and ' + $items[-1]
    }
}

function Add-SpaceToNonEmptyString ([string]$Value) {
    if ($Value) {
        " $Value"
    }
}
