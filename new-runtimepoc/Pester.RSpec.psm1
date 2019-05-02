function Find-RSpecTestFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String[]] $Path,
        [String[]] $ExcludePath
    )


    $files =
        foreach ($p in $Path) {
            if ([String]::IsNullOrWhiteSpace($p))
            {
                continue
            }

            if ((Test-Path $p)) {
                $item = Get-Item $p

                if ($item.PSIsContainer) {
                    # this is an existing directory search it for tests file
                    Get-ChildItem -Recurse -Path $p -Filter *.Tests.ps1 -File
                    continue
                }

                if ("FileSystem" -ne $item.PSProvider.Name) {
                    # item is not a directory and exists but is not a file so we are not interested
                    continue
                }

                if (".ps1" -ne $item.Extension) {
                    Write-Error "Script path '$p' is not a ps1 file." -ErrorAction Stop
                }

                # this is some file, we don't care if it is just a .ps1 file or .Tests.ps1 file
                Add-Member -Name UnresolvedPath -Type NoteProperty -Value $p -InputObject $item
                $item
                continue
            }

            # this is a path that does not exist so let's hope it is
            # a wildcarded path that will resolve to some files
            Get-ChildItem -Recurse -Path $p -Filter *.Tests.ps1 -File
        }

    Filter-Excluded -Files $files -ExludePath $ExcludePath
}

function Filter-Excluded ($Files, $ExludePath) {

    if ($null -eq $ExcludePath -or @($ExcludePath).Length -eq 0) {
        return @($Files)
    }

    foreach ($file in @($Files)) {
        # normalize backslashes for cross-platform ease of use
        $p = $file.FullName -replace "/","\"
        $excluded = $false

        foreach ($exclusion in (@($ExcludePath) -replace "/","\")) {
            if ($excluded) {
                continue
            }

            if ($p -like $exclusion) {
                $excluded = $true
            }
        }

        if (-not $excluded) {
            $file
        }
    }
}

Export-ModuleMember -Function @(
    "Find-RSpecTestFile"
)
