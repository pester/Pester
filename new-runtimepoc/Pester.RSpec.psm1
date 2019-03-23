function Find-RSpecTestFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String[]] $Path,
        [String[]] $ExcludePath
    )


    Get-ChildItem -Path $Path -Filter *.Tests.ps1 -Recurse |
        Foreach-Object {
            $path = $_.FullName
            $excluded = $false
            foreach ($exclusion in $ExcludePath) {
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
