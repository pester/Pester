function Find-RSpecTestFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String[]] $Path
    )

    Get-ChildItem -Path $Path -Filter *.Tests.ps1 -Recurse
}