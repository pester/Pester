function Invoke-InNewProcess ([ScriptBlock] $ScriptBlock) {
    # get the path of the currently loaded Pester to re-import it in the child process
    $pesterPath = Get-Module Pester | Select-Object -ExpandProperty Path
    $powershell = Get-Process -Id $pid | Select-Object -ExpandProperty Path
    # run any scriptblock in a separate process to be able to grab all the output
    # doesn't enforce Invoke-Pester usage so we can test other public functions directly
    $command = {
        param ($PesterPath, [ScriptBlock] $ScriptBlock)
        Import-Module $PesterPath

        . $ScriptBlock
    }.ToString()

    if ($PSVersionTable.PSVersion -ge '7.3' -and $PSNativeCommandArgumentPassing -ne 'Legacy') {
        $cmd = "& { $command } -PesterPath ""$PesterPath"" -ScriptBlock { $ScriptBlock }"
    }
    else {
        $cmd = "& { $command } -PesterPath ""$PesterPath"" -ScriptBlock { $($ScriptBlock -replace '"','\"') }"
    }

    & $powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command $cmd
}

function Verify-PathEqual {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Mandatory = $true, Position = 0)]
        $Expected
    )

    if ([string]::IsNullOrEmpty($Expected)) {
        throw 'Expected is null or empty.'
    }

    if ([string]::IsNullOrEmpty($Actual)) {
        throw 'Actual is null or empty.'
    }

    $e = ($expected -replace '\\', '/').Trim('/')
    $a = ($actual -replace '\\', '/').Trim('/')

    if ($e -ne $a) {
        throw "Expected path '$e' to be equal to '$a'."
    }
}
