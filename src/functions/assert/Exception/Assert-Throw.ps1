function Assert-Throw {
    param (
        [Parameter(ValueFromPipeline=$true, Mandatory = $true)]
        [ScriptBlock]$ScriptBlock,
        [Type]$ExceptionType,
        [String]$ExceptionMessage,
        [String]$FullyQualifiedErrorId,
        [Switch]$AllowNonTerminatingError,
        [String]$CustomMessage
    )

    $ScriptBlock = Collect-Input -ParameterInput $ScriptBlock -PipelineInput $local:Input

    $errorThrown = $false
    $err = $null
    try {
        $p = 'stop'
        if ($AllowNonTerminatingError)
        {
            $p = 'continue'
        }
        # compatibility fix for powershell v2
        # $eap = New-Object -TypeName psvariable "erroractionpreference", $p
        # $null = $ScriptBlock.InvokeWithContext($null, $eap, $null) 2>&1

        $null = (Invoke-WithContext -ScriptBlock $ScriptBlock -Variables @{ ErrorActionPreference = $p }) 2>&1
    }
    catch
    {
        $errorThrown = $true
        $err = Get-Error $_
    }

    $buts = @()
    $filters = @()

    $filterOnExceptionType = $null -ne $ExceptionType
    if ($filterOnExceptionType) {
        $exceptionFilterTypeFormatted = Format-Type $ExceptionType

        $filters += "of type $exceptionFilterTypeFormatted"

        $exceptionTypeFilterMatches = $err.Exception -is $ExceptionType
        if (-not $exceptionTypeFilterMatches) {
            $exceptionTypeFormatted = Get-ShortType $err.Exception
            $buts += "the exception type was '$exceptionTypeFormatted'"
        }
    }

    $filterOnMessage = -not (Test-NullOrWhiteSpace $ExceptionMessage)
    if ($filterOnMessage) {
        $filters += "with message '$ExceptionMessage'"
        if ($err.ExceptionMessage -notlike $ExceptionMessage) {
            $buts += "the message was '$($err.ExceptionMessage)'"
        }
    }

    $filterOnId = -not (Test-NullOrWhiteSpace $FullyQualifiedErrorId)
    if ($filterOnId) {
        $filters += "with FullyQualifiedErrorId '$FullyQualifiedErrorId'"
        if ($err.FullyQualifiedErrorId -notlike $FullyQualifiedErrorId) {
            $buts += "the FullyQualifiedErrorId was '$($err.FullyQualifiedErrorId)'"
        }
    }

    if (-not $errorThrown)
    {
        $buts += "no exception was thrown"
    }

    if ($buts.Count -ne 0) {
        $filter = Add-SpaceToNonEmptyString ( Join-And $filters -Threshold 3 )
        $but = Join-And $buts
        $defaultMessage = "Expected an exception,$filter to be thrown, but $but."

        $Message = Get-AssertionMessage -Expected $Expected -Actual $ScriptBlock -CustomMessage $CustomMessage `
        -DefaultMessage $defaultMessage
        throw [Assertions.AssertionException]$Message
    }

    $err.ErrorRecord
}

function Get-Error ($ErrorRecord) {

    if ($ErrorRecord.Exception -like '*"InvokeWithContext"*')
    {
        $e = $ErrorRecord.Exception.InnerException.ErrorRecord
    }
    else
    {
        $e = $ErrorRecord
    }
    New-Object -TypeName PSObject -Property @{
        ErrorRecord = $e
        ExceptionMessage = $e.Exception.Message
        Exception = $e.Exception
        ExceptionType = $e.Exception.GetType()
        FullyQualifiedErrorId = $e.FullyQualifiedErrorId
    }
}

function Join-And ($Items, $Threshold=2) {

    if ($null -eq $items -or $items.count -lt $Threshold)
    {
        $items -join ', '
    }
    else
    {
        $c = $items.count
        ($items[0..($c-2)] -join ', ') + ' and ' + $items[-1]
    }
}

function Add-SpaceToNonEmptyString ([string]$Value) {
    if ($Value)
    {
        " $Value"
    }
}