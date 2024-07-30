function Should-Throw {
    <#
    .SYNOPSIS
    Asserts that a script block throws an exception.

    .PARAMETER ScriptBlock
    The script block that should throw an exception.

    .PARAMETER ExceptionType
    The type of exception that should be thrown.

    .PARAMETER ExceptionMessage
    The message that the exception should contain. `-like` wildcards are supported.

    .PARAMETER FullyQualifiedErrorId
    The FullyQualifiedErrorId that the exception should contain. `-like` wildcards are supported.

    .PARAMETER AllowNonTerminatingError
    If set, the assertion will pass if a non-terminating error is thrown.

    .PARAMETER Because
    The reason why the input should be the expected value.

    .EXAMPLE
    ```powershell
    { throw 'error' } | Should-Throw
    { throw 'error' } | Should-Throw -ExceptionMessage 'error'
    { throw 'wildcard character []' } | Should-Throw -ExceptionMessage '*character `[`]'
    { throw 'error' } | Should-Throw -ExceptionType 'System.Management.Automation.RuntimeException'
    { throw 'error' } | Should-Throw -FullyQualifiedErrorId 'RuntimeException'
    { throw 'error' } | Should-Throw -FullyQualifiedErrorId '*Exception'
    { throw 'error' } | Should-Throw -AllowNonTerminatingError
    ```

    All of these assertions will pass.

    .EXAMPLE
    ```powershell
    $err = { throw 'error' } | Should-Throw
    $err.Exception.Message | Should-BeLike '*err*'
    ```

    The error record is returned from the assertion and can be used in further assertions.

    .LINK
    https://pester.dev/docs/commands/Should-Throw

    .LINK
    https://pester.dev/docs/assertions

    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    param (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [ScriptBlock]$ScriptBlock,
        [Parameter(Position = 0)]
        [String]$ExceptionMessage,
        [Parameter(Position = 1)]
        [String]$FullyQualifiedErrorId,
        [Parameter(Position = 2)]
        [Type]$ExceptionType,
        [Parameter(Position = 3)]
        [String]$Because,
        [Switch]$AllowNonTerminatingError
    )

    $collectedInput = Collect-Input -ParameterInput $ScriptBlock -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput -UnrollInput
    $ScriptBlock = $collectedInput.Actual

    Assert-BoundScriptBlockInput -ScriptBlock $ScriptBlock

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
        $err = Get-ErrorObject $_
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
            $buts += "the exception type was $exceptionTypeFormatted"
        }
    }

    $filterOnMessage = -not ([string]::IsNullOrWhiteSpace($ExceptionMessage))
    if ($filterOnMessage) {
        $filters += "with message like '$([System.Management.Automation.WildcardPattern]::Unescape($ExceptionMessage))'"
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

        $Message = Get-AssertionMessage -Expected $Expected -Actual $ScriptBlock -Because $Because `
            -DefaultMessage $defaultMessage
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }

    $err.ErrorRecord
}

function Get-ErrorObject ($ErrorRecord) {

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
