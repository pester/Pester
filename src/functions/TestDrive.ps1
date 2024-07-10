function Get-TestDrivePlugin {
    $p = @{
        Name = 'TestDrive'
    }

    $p.Start = {
        param($Context)

        if (& $script:SafeCommands['Test-Path'] TestDrive:\) {
            $existingDrive = & $SafeCommands['Get-PSDrive'] TestDrive -ErrorAction Stop
            $existingDriveRoot = "$($existingDrive.Provider)::$($existingDrive.Root)"

            if ($runningPesterInPester) {
                # If nested run, store location and only remove PSDrive so we can re-attach it during End-step
                $Context.GlobalPluginData.TestDrive = @{
                    ExistingTestDrivePath = $existingDriveRoot
                }
            }
            else {
                & $SafeCommands['Remove-Item'] $existingDriveRoot -Force -Recurse -Confirm:$false
            }
            & $SafeCommands['Remove-PSDrive'] TestDrive
        }
    }

    $p.EachBlockSetupStart = {
        param($Context)

        if ($Context.Block.IsRoot) {
            # this is top-level block setup test drive
            $path = New-TestDrive
            $Context.Block.PluginData.Add('TestDrive', @{
                    TestDriveAdded   = $true
                    TestDriveContent = $null
                    TestDrivePath    = $path
                })
        }
        else {
            $testDrivePath = $Context.Block.Parent.PluginData.TestDrive.TestDrivePath
            $Context.Block.PluginData.Add('TestDrive', @{
                    TestDriveAdded   = $false
                    TestDriveContent = Get-TestDriveChildItem -TestDrivePath $testDrivePath
                    TestDrivePath    = $testDrivePath
                })
        }
    }

    $p.EachBlockTearDownEnd = {
        param($Context)

        # Remap drive and variable if missing/wrong? Ex. if nested run was cancelled and didn't re-attach this drive
        if (-not (& $script:SafeCommands['Test-Path'] TestDrive:\)) {
            New-TestDrive -Path $Context.Block.PluginData.TestDrive.TestDrivePath
        }

        if ($Context.Block.IsRoot) {
            # this is top-level block remove test drive
            Remove-TestDrive -TestDrivePath $Context.Block.PluginData.TestDrive.TestDrivePath
        }
        else {
            Clear-TestDrive -TestDrivePath $Context.Block.PluginData.TestDrive.TestDrivePath -Exclude ($Context.Block.PluginData.TestDrive.TestDriveContent)
        }
    }

    $p.End = {
        param($Context)

        if ($Context.GlobalPluginData.TestDrive.ExistingTestDrivePath) {
            # If nested run, reattach previous TestDrive PSDrive and variable
            New-TestDrive -Path $Context.GlobalPluginData.TestDrive.ExistingTestDrivePath
        }
    }

    New-PluginObject @p
}

function New-TestDrive {
    param(
        [string] $Path
    )

    if ($Path -notmatch '\S') {
        $directory = New-RandomTempDirectory
    }
    else {
        # We have a path, so probably a remap after losing the PSDrive (ex. cancelled nested Pester run)
        if (-not (& $SafeCommands['Test-Path'] -Path $Path)) {
            # If this runs, something deleted the container-specific folder, so we create a new folder
            $null = & $SafeCommands['New-Item'] -Path $Path -ItemType Directory -ErrorAction Stop
        }

        $directory = & $SafeCommands['Get-Item'] $Path
    }

    $DriveName = 'TestDrive'
    $null = & $SafeCommands['New-PSDrive'] -Name $DriveName -PSProvider FileSystem -Root $directory -Scope Global -Description 'Pester test drive'

    # publish the global TestDrive variable used in few places within the module.
    # using Set-Variable to support new variable + override existing (remap)
    & $SafeCommands['Set-Variable'] -Name $DriveName -Scope Global -Value $directory

    $directory
}


function Clear-TestDrive {
    param(
        [String[]] $Exclude,
        [string] $TestDrivePath
    )
    if ([IO.Directory]::Exists($TestDrivePath)) {

        Remove-TestDriveSymbolicLinks -Path $TestDrivePath

        foreach ($i in [IO.Directory]::GetFileSystemEntries($TestDrivePath, '*.*', [System.IO.SearchOption]::AllDirectories)) {
            if ($Exclude -contains $i) {
                continue
            }

            & $SafeCommands['Remove-Item'] -Force -Recurse $i -ErrorAction Ignore
        }
    }
}

function New-RandomTempDirectory {
    do {
        $tempPath = Get-TempDirectory
        $dirName = 'Pester_' + [IO.Path]::GetRandomFileName().Substring(0, 4)
        $Path = [IO.Path]::Combine($tempPath, $dirName)
    } until (-not [IO.Directory]::Exists($Path))

    [IO.Directory]::CreateDirectory($Path).FullName
}

function Get-TestDriveChildItem ($TestDrivePath) {
    if ([IO.Directory]::Exists($TestDrivePath)) {
        [IO.Directory]::GetFileSystemEntries($TestDrivePath, '*.*', [System.IO.SearchOption]::AllDirectories)
    }
}

function Remove-TestDriveSymbolicLinks ([String] $Path) {

    # remove symbolic links to work around problem with Remove-Item.
    # see https://github.com/PowerShell/PowerShell/issues/621
    #     https://github.com/pester/Pester/issues/1100

    # powershell 5 and higher
    # & $SafeCommands["Get-ChildItem"] -Recurse -Path $Path -Attributes "ReparsePoint" |
    #    % { $_.Delete() }

    # issue 621 was fixed before PowerShell 6.1
    # now there is an issue with calling the Delete method in recent (6.1) builds of PowerShell
    if ((GetPesterPSVersion) -ge 6) {
        return
    }

    # powershell 2-compatible
    $reparsePoint = [System.IO.FileAttributes]::ReparsePoint
    & $SafeCommands['Get-ChildItem'] -Recurse -Path $Path |
        & $SafeCommands['Where-Object'] { ($_.Attributes -band $reparsePoint) -eq $reparsePoint } |
        & $SafeCommands['Foreach-Object'] { $_.Delete() }
}

function Remove-TestDrive ($TestDrivePath) {
    $DriveName = 'TestDrive'
    $Drive = & $SafeCommands['Get-PSDrive'] -Name $DriveName -ErrorAction Ignore
    $Path = ($Drive).Root

    if ($pwd -like "$DriveName*") {
        #will staying in the test drive cause issues?
        #TODO: review this
        & $SafeCommands['Write-Warning'] -Message "Your current path is set to ${pwd}:. You should leave ${DriveName}:\ before leaving Describe."
    }

    if ($Drive) {
        $Drive | & $SafeCommands['Remove-PSDrive'] -Force #This should fail explicitly as it impacts future pester runs
    }

    if (($null -ne $Path) -and ([IO.Directory]::Exists($Path))) {
        Remove-TestDriveSymbolicLinks -Path $Path
        [IO.Directory]::Delete($path, $true)
    }

    if (& $SafeCommands['Get-Variable'] -Name $DriveName -Scope Global -ErrorAction Ignore) {
        & $SafeCommands['Remove-Variable'] -Scope Global -Name $DriveName -Force
    }
}
