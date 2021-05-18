function New-BlockContainerObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ParameterSetName = "ScriptBlock")]
        [ScriptBlock] $ScriptBlock,
        [Parameter(Mandatory, ParameterSetName = "Path")]
        [String] $Path,
        [Parameter(Mandatory, ParameterSetName = "File")]
        [System.IO.FileInfo] $File,
        $Data
    )

    $type, $item = switch ($PSCmdlet.ParameterSetName) {
        "ScriptBlock" { "ScriptBlock", $ScriptBlock }
        "Path" { "File", (& $SafeCommands['Get-Item'] $Path) }
        "File" { "File", $File }
        default { throw [System.ArgumentOutOfRangeException]"" }
    }

    $c = [Pester.ContainerInfo]::Create()
    $c.Type = $type
    $c.Item = $item
    $c.Data = $Data
    $c
}
