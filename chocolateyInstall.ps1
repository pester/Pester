[CmdletBinding()]
param ( )

end {
    $modulePath = Join-Path -Path $env:ProgramFiles -ChildPath WindowsPowerShell\Modules
    $targetDirectory = Join-Path -Path $modulePath -ChildPath Pester
    $scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
    $sourceDirectory = Join-Path -Path $scriptRoot -ChildPath Tools

    if ($PSVersionTable.PSVersion.Major -ge 5) {
        $manifestFile = Join-Path -Path $sourceDirectory -ChildPath Pester.psd1
        $manifest = Test-ModuleManifest -Path $manifestFile -WarningAction Ignore -ErrorAction Stop
        $targetDirectory = Join-Path -Path $targetDirectory -ChildPath $manifest.Version.ToString()
    }

    Update-Directory -Source $sourceDirectory -Destination $targetDirectory

    $binPath = Join-Path -Path $targetDirectory -ChildPath bin
    Install-ChocolateyPath $binPath

    if ($PSVersionTable.PSVersion.Major -lt 4) {
        $modulePaths = [Environment]::GetEnvironmentVariable('PSModulePath', 'Machine') -split ';'
        if ($modulePaths -notcontains $modulePath) {
            Write-Verbose -Message "Adding '$modulePath' to PSModulePath."

            $modulePaths = @(
                $modulePath
                $modulePaths
            )

            $newModulePath = $modulePaths -join ';'

            [Environment]::SetEnvironmentVariable('PSModulePath', $newModulePath, 'Machine')
            $env:PSModulePath += ";$modulePath"
        }
    }
}

begin {
    function Update-Directory {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string] $Source,

            [Parameter(Mandatory = $true)]
            [string] $Destination
        )

        $Source = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($Source)
        $Destination = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($Destination)

        if (-not (Test-Path -LiteralPath $Destination)) {
            $null = New-Item -Path $Destination -ItemType Directory -ErrorAction Stop
        }

        try {
            $sourceItem = Get-Item -LiteralPath $Source -ErrorAction Stop
            $destItem = Get-Item -LiteralPath $Destination -ErrorAction Stop

            if ($sourceItem -isnot [System.IO.DirectoryInfo] -or $destItem -isnot [System.IO.DirectoryInfo]) {
                throw 'Not Directory Info'
            }
        }
        catch {
            throw 'Both Source and Destination must be directory paths.'
        }

        $sourceFiles = Get-ChildItem -Path $Source -Recurse |
            Where-Object -FilterScript { -not $_.PSIsContainer }

        foreach ($sourceFile in $sourceFiles) {
            $relativePath = Get-RelativePath $sourceFile.FullName -RelativeTo $Source
            $targetPath = Join-Path -Path $Destination -ChildPath $relativePath

            $sourceHash = Get-FileHash -Path $sourceFile.FullName
            $destHash = Get-FileHash -Path $targetPath

            if ($sourceHash -ne $destHash) {
                $targetParent = Split-Path -Path $targetPath -Parent

                if (-not (Test-Path -Path $targetParent -PathType Container)) {
                    $null = New-Item -Path $targetParent -ItemType Directory -ErrorAction Stop
                }

                Write-Verbose -Message "Updating file $relativePath to new version."
                Copy-Item -Path $sourceFile.FullName -Destination $targetPath -Force -ErrorAction Stop
            }
        }

        $targetFiles = Get-ChildItem -Path $Destination -Recurse |
            Where-Object -FilterScript { -not $_.PSIsContainer }

        foreach ($targetFile in $targetFiles) {
            $relativePath = Get-RelativePath $targetFile.FullName -RelativeTo $Destination
            $sourcePath = Join-Path -Path $Source -ChildPath $relativePath

            if (-not (Test-Path $sourcePath -PathType Leaf)) {
                Write-Verbose -Message "Removing unknown file $relativePath from module folder."
                Remove-Item -LiteralPath $targetFile.FullName -Force -ErrorAction Stop
            }
        }

    }

    function Get-RelativePath {
        param ( [string] $Path, [string] $RelativeTo )
        return $Path -replace "^$([regex]::Escape($RelativeTo))\\?"
    }

    function Get-FileHash {
        param ([string] $Path)

        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            return $null
        }

        $item = Get-Item -LiteralPath $Path
        if ($item -isnot [System.IO.FileSystemInfo]) {
            return $null
        }

        $stream = $null

        try {
            $sha = New-Object -TypeName System.Security.Cryptography.SHA256CryptoServiceProvider
            $stream = $item.OpenRead()
            $bytes = $sha.ComputeHash($stream)
            return [convert]::ToBase64String($bytes)
        }
        finally {
            if ($null -ne $stream) {
                $stream.Close()
            }
            if ($null -ne $sha) {
                $sha.Clear()
            }
        }
    }
}
