function Assert-Success {
    # [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject[]] $InvocationResult,
        [String] $Message = "Invocation failed"
    )

    $rc = 0
    $anyFailed = $false
    $err = ""
    foreach ($r in $InvocationResult) {
        $ec = 0
        if ($null -ne $r.ErrorRecord -and $r.ErrorRecord.Length -gt 0) {
            $err += "Result $($rc++):"
            $anyFailed = $true
            foreach ($e in $r.ErrorRecord) {
                $err += "Error $($ec++):"
                $err += & $SafeCommands["Out-String"] -InputObject $e
                $err += & $SafeCommands["Out-String"] -InputObject $e.ScriptStackTrace
            }
        }
    }

    if ($anyFailed) {
        $Message = $Message + ":`n$err"
        & $SafeCommands["Write-Host"] -ForegroundColor Red $Message
        throw $Message
    }
}
