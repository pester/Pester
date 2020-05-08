function In {
    <#
    .SYNOPSIS
    A convenience function that executes a script from a specified path.

    .DESCRIPTION
    Before the script block passed to the execute parameter is invoked,
    the current location is set to the path specified. Once the script
    block has been executed, the location will be reset to the location
    the script was in prior to calling In.

    .PARAMETER Path
    The path that the execute block will be executed in.

    .PARAMETER Execute
    The script to be executed in the path provided.

    #>
    [CmdletBinding()]
    param(
        $Path,
        [ScriptBlock] $Execute
    )
    Assert-DescribeInProgress -CommandName In

    $old_pwd = $pwd
    & $SafeCommands['Push-Location'] $Path
    $pwd = $Path
    try {
        Write-ScriptBlockInvocationHint -Hint "In" -ScriptBlock $Execute
        & $Execute
    }
    finally {
        & $SafeCommands['Pop-Location']
        $pwd = $old_pwd
    }
}
