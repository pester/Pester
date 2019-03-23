function Find-RSpecTestFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String[]] $Path,
        [String[]] $ExcludePath
    )


    Get-ChildItem -Path $Path -Filter *.Tests.ps1 -Recurse |
        Foreach-Object {
            # normalize backslashes for cross-platform ease of use
            $path = $_.FullName -replace "/","\"
            $excluded = $false
            foreach ($exclusion in ($ExcludePath -replace "/","\")) {
                if ($excluded) {
                    continue
                }

                if ($path -like $exclusion) {
                    $excluded = $true
                }
            }

            if (-not $excluded) {
                $_
            }
        }
}
