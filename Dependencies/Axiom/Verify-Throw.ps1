function Verify-Throw {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ScriptBlock]$ScriptBlock
    )

    $exceptionThrown = $false
    try {
        $null = & $ScriptBlock
    }
    catch {
        $exceptionThrown = $true
        $_
    }

    if (-not $exceptionThrown) {
        throw [Exception]"An exception was expected, but no exception was thrown!"
    }
}
