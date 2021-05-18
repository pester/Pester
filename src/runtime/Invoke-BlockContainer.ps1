function Invoke-BlockContainer {
    param (
        [Parameter(Mandatory)]
        $BlockContainer,
        [Parameter(Mandatory = $true)]
        [Management.Automation.SessionState] $SessionState
    )

    if ($null -ne $BlockContainer.Data -and 0 -lt $BlockContainer.Data.Count) {
        foreach ($d in $BlockContainer.Data) {
            switch ($BlockContainer.Type) {
                "ScriptBlock" {
                    Invoke-InNewScriptScope -ScriptBlock { & $BlockContainer.Item @d } -SessionState $SessionState
                }
                "File" { Invoke-File -Path $BlockContainer.Item.PSPath -SessionState $SessionState -Data $d }
                default { throw [System.ArgumentOutOfRangeException]"" }
            }
        }
    }
    else {
        switch ($BlockContainer.Type) {
            "ScriptBlock" {
                Invoke-InNewScriptScope -ScriptBlock { & $BlockContainer.Item } -SessionState $SessionState
            }
            "File" { Invoke-File -Path $BlockContainer.Item.PSPath -SessionState $SessionState }
            default { throw [System.ArgumentOutOfRangeException]"" }
        }
    }
}
