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

    .PARAMETER ScriptBlock
    The script to be executed in the path provided.

    .LINK
    https://github.com/pester/Pester/wiki/In
    #>
    [CmdletBinding(DefaultParameterSetName = "Default")]
    param(
        [Parameter(Mandatory, ParameterSetName = "Default", Position = 0)]
        [String] $Path,
        [Parameter(Mandatory, ParameterSetName = "TestDrive", Position = 0)]
        [Switch] $TestDrive,
        [Parameter(Mandatory, Position = 1)]
        [Alias("Execute")]
        [ScriptBlock] $ScriptBlock
    )

    # test drive is not available during discovery, ideally no code should
    # depend on location during discovery, but I cannot rely on that, so unless
    # the path is TestDrive the path is changed in discovery as well as during
    # the run phase
    $doNothing = $false
    if ($TestDrive) {
        if (Is-Discovery) {
            $doNothing = $true
        }
        else {
            $Path = (& $SafeCommands['Get-PSDrive'] 'TestDrive').Root
        }
    }

    $originalPath = $pwd
    if (-not $doNothing) {
        & $SafeCommands['Set-Location'] $Path
        $pwd = $Path
    }
    try {
        & $ScriptBlock
    }
    finally {
        if (-not $doNothing) {
            & $SafeCommands['Set-Location'] $originalPath
            $pwd = $originalPath
        }
    }
}
